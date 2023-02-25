MidiIn min;
MidiMsg msg;
//140 bpm

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[1]);

//IDEAS: 1. drum and bass song
// 2. song where each bd hit triggers fast rhythm that changes
// 3. deerhoof cover
// 4. EVIDENCE - monk : DO THIS FIRST
// 5. morton feldman vibes
// 6. use shakers ugen to trigger random environmental sounds
//7. use voicForm to do crazy shit


0 => int bassindex;
0 => int snareindex;
0 => int tomindex;
0 => int bSection;
0 => int chordindex;
1 => int chordGo;
0 => int Achordindex;
0 => int globalChordIndex;
0 => int interDiv;

int hitTom;
now=> time tomTime; //had added + 1000::second before, why???
int hitBass;
now  => time bassTime;
int hitSnare;
now => time snareTime;
5000::ms => dur interval; //duration between bass drum hits
interval/4 => dur hitInter; //duration for each synth sound

notes2nums(["A3","A3", "D4","E4","B3","E3","A3","C3","E4","A3","A3","D4","E4","G4","A4","B4","E5"],1) @=> int snare[]; 
4 => int aChordSize;
4 => int bChordSize;
[37, 39, 41, 47, 32, 31, 30, 35, 42] @=> int rootListA[];
[35, 33, 34, 27, 29, 30, 35, 33] @=> int rootListB[];

float Achords[rootListA.size()][aChordSize]; //1st dim is num of chords total, 2nd is notes in each chord

float Bchords[rootListB.size()][bChordSize]; //1st dim is num of chords total, 2nd is notes in each chord

for(0 => int i; i<Achords.size(); i++) //convert to MIDI notes
{
    harmonicChord(rootListA[i], aChordSize, 5.0, 2.0) @=> Achords[i];
}

for(0 => int i; i<Bchords.size(); i++) //convert to MIDI notes
{
    harmonicChord(rootListB[i], bChordSize, 4.0, 3.0) @=> Bchords[i];
}



PulseOsc OSCarray[5];
ADSR E[5];
PRCRev R[5];
BiQuad F[5];

for( 0 => int i; i<5; i++)
{   OSCarray[i] => E[i] => R[i] => dac;
0.7 => OSCarray[i].gain;
E[i].set(20::ms, 10::ms, .9, 1000::ms);
0.1 => R[i].mix;
.99 => F[i].prad; 
1 => F[i].eqzs;
(6-i)*.1 => F[i].gain;
}

PulseOsc sin => ADSR e1 => BiQuad f => PRCRev reverb1 => dac;
.99 => f.prad; 
1 => f.eqzs;
.05 => f.gain;e1.set( 5::ms, 1::ms, .3, 100::ms );
//MIDI port
0 => int port;

if( !min.open(port))
{
    <<<"ERROR: midi port didn't open on port:", port>>>;
    me.exit();
}

spork ~ ddrumTrigBass();
20::ms => now;
spork ~ ddrumTrigSnare();
20::ms => now;
spork ~ ddrumTrigTom();
20::ms => now;
spork ~ voiceGate();

oscOut("/songSection",[0]); 

while(true)
{
    1::second => now;
}

fun void voiceGate()
{
    while(true)
    {
        if(hitTom==1 && (now > tomTime + 1000::ms) )
        {
            0 => hitTom;
        }
        if(hitBass==1 && (now > bassTime + 200::ms) )
        {
            0 => hitBass;
        }
        if(hitSnare==1 && (now > snareTime + 100::ms) )
        {
            0 => hitSnare;
        }
        5::ms => now;
    }
}

fun void ddrumTrigBass()
{
    while(true)
    {
        min => now;
        //<<<(msg.data2)>>>;
        
        while(min.recv(msg))
        {
            <<< msg.data1, msg.data2, msg.data3 >>>;
            if( msg.data3!=1 && msg.data2 == 36 && hitBass==0) //kick drum
            {
                for(0 => int i; i < Achords[Achordindex].size(); i++)
                {
                    E[i].keyOff();
                }
                
                //oscOut("/chords",[Achords[Achordindex][0]]);
                
                for(0 => int i; i < Achords[Achordindex].size(); i++)
                {
                    
                    Achords[Achordindex][i] => OSCarray[i].freq;
                    E[i].keyOn();
                }
                
                if(Achordindex == Achords.size()-1) globalChordIndex+1 => globalChordIndex;
                
                (Achordindex + 1) % Achords.size() => Achordindex;
                
                
                100::ms => now;
                
                
                for(0 => int i; i < Achords[Achordindex].size(); i++)
                {
                    E[i].keyOff();
                }
                
                100::ms => now;  
               
            }   
                       
        }
    }    
}

fun void ddrumTrigSnare()
{
    while(true)
    {
        min => now;
        //<<<(msg.data2)>>>;
        
        while(min.recv(msg))
        {
            if(msg.data3!=0 && msg.data2 == 37 && hitSnare==0) //snare
            {
                
                //<<<snareindex>>>;
                e1.keyOff();
                
                if(bSection == 0)
                { 
                    oscOut("/melody",[snare[snareindex]]); //OSC!
                    1 => hitSnare;
                    now => snareTime;
                    
                    //<<<hitInter>>>;
                    Math.random2(3,10) => int division;
                    
                    Math.random2f(0.05,0.3)::second => dur randTime;
                    
                    for(0 => int i; i < division; i++)
                    {
                        Std.mtof(snare[Math.random2(0,snare.size()-1)]) => sin.freq;  //set the frequency
                        e1.keyOn();
                        
                        randTime/(division/2) => now;
                        e1.keyOff();
                        randTime/(division/2) => now;
                    }
                    
                }
                
                
            }
        }
    }    
}

fun void ddrumTrigTom()
{
    while(true)
    {
        min => now;
        //<<<(msg.data2)>>>;
        
        while(min.recv(msg))
        {
       
            if(msg.data3!=0 && msg.data2 == 38 && hitTom == 0) //tom1: down a row
            {    
                
                1 => hitTom;
                
                
                
                
            }
        }
    }    
}


///UTIL FUNCTIONS///

function int[] notes2nums(string notes[], int numcopies)
{
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string A[];
    string numTOnote[127];
    int noteTOnum[127];
    
    //create array of midi notes indexed by integers 0-127
    for(0 => int i; i<127;i++)
    {
        i % 12 => int mod;
        -2 + i/12 => int counter;
        A[mod] + counter => numTOnote[i];
    }
    
    //create array indexed by midi notes (the inverse of B)
    for(0 => int i; i<127; i++)
    {
        i => noteTOnum[numTOnote[i]];
    }
    
    int numbers[notes.size()*numcopies];
    for(0 => int i; i<notes.size()*numcopies;i++)
    {
        i % notes.size() => int index;
        noteTOnum[notes[index]] => numbers[i];
    }
    return numbers;
}

function int[] changeOctave(int noteNums[], string choice, int x)
{
    int result[noteNums.size()];
    
    if(choice == "up")
    {
        for(0 => int i; i < noteNums.size(); i++)
        {
            noteNums[i] + 12*x => result[i];
        }
    }
    else if(choice == "down")
    {
        for(0 => int i; i < noteNums.size(); i++)
        {
            noteNums[i] - 12*x => result[i];
        }
    }
    else
    {
        <<<"ERROR">>>;
    }
    return result;
}

fun void oscOut(string addr, int val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}

fun float[] harmonicChord(int rootMIDI,int harmonics, float a, float b)
{
    float result[harmonics];
    Std.mtof(rootMIDI) => float rootFreq;
    
    rootFreq => result[0];
    
    
    for(0 => int i; i < harmonics-1; i++)
    {
        (rootFreq*(a*i + b)) / 2.0=> result[i+1];
    }
    
    return result;
}
MidiIn min;
MidiMsg msg;
//120 bpm;

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[2.0]);

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
0 => int Achordindex;
0 => int Bchordindex;
0 => int globalChordIndex;
0 => int a;


int hitTom;
now=> time tomTime; //had added + 1000::second before, why???
int hitBass;
now  => time bassTime;
int hitSnare;
now => time snareTime;

4 => int aChordSize;
5 => int bChordSize;
[36, 34, 37, 33, 31, 29, 38, 40, 30, 41, 39, 37, 35, 31, 27, 35, 33,  35, 33, 29, 25, 33, 31] @=> int rootListA[];
[35, 33, 34, 27, 29, 30, 35, 33] @=> int rootListB[];

float Achords[rootListA.size()][aChordSize]; //1st dim is num of chords total, 2nd is notes in each chord

float Bchords[rootListB.size()][bChordSize]; //1st dim is num of chords total, 2nd is notes in each chord

for(0 => int i; i<Achords.size(); i++) //convert to MIDI notes
{
    harmonicChord(rootListA[i], 4, 6.0, 3.0) @=> Achords[i];
}

for(0 => int i; i<Bchords.size(); i++) //convert to MIDI notes
{
    harmonicChord(rootListB[i], 4, 4.0, 3.0) @=> Bchords[i];
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


//MIDI port
0 => int port;

if( !min.open(port))
{
    <<<"ERROR: midi port didn't open on port:", port>>>;
    me.exit();
}

spork ~ ddrumTrig();
10::ms => now;
spork ~ ddrumTrig();
10::ms => now;
spork ~ ddrumTrig();
10::ms => now;
spork ~ voiceGate();
10::ms => now;
oscOut("/songSection",[0.0]);

while(true)
{
    0.2::second => now;
    if(((globalChordIndex - 2) % 3) == 0) 
    {
        oscOut("/songSection",[1.0]);
        1 => bSection;
    }
    else
    {
        oscOut("/songSection",[0.0]);
        0 => bSection;
    }
}

fun void voiceGate()
{
    while(true)
    {
        if(hitTom==1 && (now > tomTime + 300::ms) )
        {
            0 => hitTom;
        }
        if(hitBass==1 && (now > bassTime + 1000::ms) )
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

fun void ddrumTrig()
{
    while(true)
    {
        min => now;
        //<<<(msg.data2)>>>;
        
        while(min.recv(msg))
        {
            //<<< msg.data1, msg.data2, msg.data3 >>>;
            if( msg.data3!=0 && msg.data2 == 36 && hitBass==0) //kick drum
            {
                1 => hitBass; 
                
                for( 0 => int i; i<5; i++)
                { 
                    ((globalChordIndex % 3) + 1) *750 => a;
                    E[i].set(20::ms, 10::ms, .9, a::ms);
                    0.1 => R[i].mix;
                    
                }
                
                //<<<a>>>;
                //<<<globalChordIndex>>>;
                
                if(bSection == 0)
                {
                    for(0 => int i; i < Achords[Achordindex].size(); i++)
                    {
                        E[i].keyOff();
                    }
                    
                    oscOut("/chords",[Achords[Achordindex][0]]);
                    
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
                else
                {
                    for(0 => int i; i < Bchords[Bchordindex].size(); i++)
                    {
                        E[i].keyOff();
                    }
                    
                    oscOut("/chords",[Bchords[Bchordindex][0]]);
                    
                    for(0 => int i; i < Bchords[Bchordindex].size(); i++)
                    {
                        E[i].set(70::ms, 30::ms, 0.9, 4000::ms);
                        0.2 => R[i].mix;
                        Bchords[Bchordindex][i] => OSCarray[i].freq;
                        E[i].keyOn();
                    }
                    
                    if(Bchordindex == Bchords.size()-1) globalChordIndex+1 => globalChordIndex;
                    
                    (Bchordindex + 1) % Bchords.size() => Bchordindex;
                    
                    
                    100::ms => now;
                    
                    
                    for(0 => int i; i < Bchords[Bchordindex].size(); i++)
                    {
                        E[i].keyOff();
                    }
                    
                    100::ms => now;  
                    
                }
                
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

function int[] transpose(int noteNums[], string choice, int halfSteps)
{
    int result[noteNums.size()];
    
    if(choice == "up")
    {
        for(0 => int i; i < noteNums.size(); i++)
        {
            noteNums[i] + halfSteps => result[i];
        }
    }
    else if(choice == "down")
    {
        for(0 => int i; i < noteNums.size(); i++)
        {
            noteNums[i] - halfSteps => result[i];
        }
    }
    else
    {
        <<<"ERROR">>>;
    }
    return result;
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

fun void oscOut(string addr, float val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}
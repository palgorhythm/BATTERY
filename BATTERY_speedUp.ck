MidiIn min;
MidiMsg msg;

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


[29, 29, 43, 38, 29, 29, 43, 38, 29, 29, 43, 38, 32, 48, 43, 41] @=> int bass[];
[["F#1","C#3", "A#3", "D#4", "F4", "G#4"], ["A1", "E3", "A3", "C#4", "D4", "F#4"], ["D#1", "A#2", "G3", "A3", "C3", "F4"], ["G#0", "D#3", "G3", "C4", "D4", "F4"],
["G1","D#3","F3","A#3","B3","D#3"],["C2","G2","A#3","D4","D#4","F4"],["C#2","G#2","C4","D#4","F4","G4"],["B1","E2","G#3","A#3","C#4","D#4"],["C2","E2","G#3","A#3","C4","A#4"]] @=> string chordStrings[][];
int chords[chordStrings.size()][chordStrings[0].size()]; //all chords have to be same length
notes2nums(["A3","A3", "D4","E4","B3","E3","A3","C3","E4","A3","A3","D4","E4","G4","A4","B4","E5"],1) @=> int snare[];

for(0 => int i; i<chords.size(); i++) //convert to MIDI notes
{
    notes2nums(chordStrings[i],1) @=> chords[i];
}

PulseOsc sin => ADSR e1 => BiQuad f => PRCRev reverb1 => dac;
.99 => f.prad; 
1 => f.eqzs;
.05 => f.gain;
PulseOsc saw => ADSR e2 => PRCRev reverb2 => dac;
SawOsc OSCarray[6];
ADSR E[6];
PRCRev R[6];
0.7 => sin.gain;
1.0 => saw.gain;

for( 0 => int i; i<6; i++)
{   OSCarray[i] => E[i] => R[i] => dac;
1.0 => OSCarray[i].gain;
E[i].set(20::ms, 10::ms, .9, 3000::ms);
0.1 => R[i].mix;
}

e1.set( 5::ms, 1::ms, .3, 100::ms );
e2.set( 10::ms, 20::ms, .5, 1000::ms );
.01 => reverb1.mix;
.01 => reverb2.mix;

//MIDI port
0 => int port;

if( !min.open(port))
{
    <<<"ERROR: midi port didn't open on port:", port>>>;
    me.exit();
}

spork ~ ddrumTrig();
20::ms => now;
spork ~ ddrumTrig();
20::ms => now;
spork ~ ddrumTrig();
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
                //<<<bassindex>>>;
                
                e1.keyOff();
                
                //(msg.data2/80.0) => sin.gain;
                1 => hitBass;
                now-bassTime => interval; //starts at 1000ms
                
                interval/4 => hitInter;
                now => bassTime;
                //<<<chordGo>>>;
                
                if(bSection == 0) //if in A section, hit the current note 4 times
                {
                    //<<<hitInter>>>;
                    if(bassindex > bass.size() - 2)
                    {
                        6 => interDiv;
                    }
                    else
                    {
                        4 => interDiv;
                    }
                    
                    //<<<interDiv>>>;
                    oscOut("/bass",[bass[bassindex]]); //OSC
                    
                    for(0 => int i; i < interDiv; i++)
                    {
                        //Std.mtof(bass[bassindex]) => sin.freq;  //set the frequency
                        10000.0/(hitInter/1::ms) => sin.freq;  //set the frequency
                        e1.keyOn();
                        hitInter/(interDiv/2) => now;
                        e1.keyOff();
                        hitInter/(interDiv/2) => now;
                    }
                }
                else
                {
                    if(chordGo == 1)
                    {
                        //<<<globalChordIndex>>>;
                        for(0 => int i; i < chords[chordindex].size(); i++)
                        {
                            E[i].keyOff();
                        }
                        
                        
                        0 => chordGo;
                        
                        oscOut("/chords",[chords[chordindex][0]]);
                        
                        for(0 => int i; i < chords[chordindex].size(); i++)
                        {
                            
                            //Std.mtof(chords[chordindex][i]) => OSCarray[i].freq;
                            chords[chordindex][i] * hitInter/1::ms => OSCarray[i].freq;
                            E[i].keyOn();
                            
                        }
                        
                        if(chordindex == chords.size()-1) globalChordIndex+1 => globalChordIndex;
                        (chordindex + 1) % chords.size() => chordindex;
                        
                        
                        0.5::second => now;
                        
                        
                        for(0 => int i; i < chords[chordindex].size(); i++)
                        {
                            E[i].keyOff();
                        }
                        
                        0.5::second => now;    
                        
                        
                    }
                }
                
                if(bSection == 0)
                { 
                    (bassindex + 1) % bass.size() => bassindex;  
                    0 => chordindex;
                }
                else
                {
                    //(chordindex+1) % chords.size() => chordindex;
                    0 => bassindex;
                    
                }
            }   
            else if(msg.data3!=0 && msg.data2 == 37 && hitSnare==0) //snare
            {
                
                //<<<snareindex>>>;
               
                
                
            }
            else if(msg.data3!=0 && msg.data2 == 40 && hitTom == 0) //tom1: down a row
            {    
                
                1 => hitTom;
                
                if(bSection == 0)
                {
                    oscOut("/songSection",[1]);
                    e1.keyOff();
                    1 => bSection;
                    //0 => globalChordIndex;
                    1 => chordGo;
                    0 => bassindex;
                    //<<<globalChordIndex>>>;
                    
                }
                else
                {                    
                    if(globalChordIndex == 1 || globalChordIndex ==4)
                    {
                        0 => bSection;
                        oscOut("/songSection",[0]);
                        globalChordIndex + 1 => globalChordIndex;
                        for(0 => int i; i < chords[chordindex].size(); i++)
                        {
                            E[i].keyOff();
                        }
                        0 => bassindex;
                    }
                    else
                    {
                        1 => chordGo;
                    }
                    
                    
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

fun void oscOut(string addr, int val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}
MidiIn min;
MidiMsg msg;
fun void setUpMidi() {
    [0,1,2,3,4,5] @=> int ports[];
    0 => int hasOpenPort;
    0 => int openPort;
    for(0 => int i; i < ports.size(); i++){
        if(min.open(ports[i]) && min.name() == "SPD-SX") {
            ports[i] => openPort;
            1 => hasOpenPort;
            break;
        }
    }
    
    if(hasOpenPort == 0) {
        <<<"ERROR: SPD-SX MIDI port not found.">>>;
        me.exit();
    } else {
        <<<"Opened SPD on port", openPort>>>;
    }
}
setUpMidi();

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[1]);

0 => int bassindex;
0 => int snareindex;
0 => int tomindex;
0 => int bSection;
0 => int chordindex;
1 => int chordGo;
0 => int globalChordIndex;
0 => int interDiv;
now  => time bassTime;

5000::ms => dur interval; //duration between bass drum hits
interval/4 => dur hitInter; //duration for each synth sound
float currentPitch;


[29, 29, 43, 38, 29, 29, 43, 38, 29, 29, 43, 38, 32, 48, 43, 41] @=> int bass[];
[["F#1","C#3", "A#3", "D#4", "F4", "G#4"], ["A1", "E3", "A3", "C#4", "D4", "F#4"], ["D#1", "A#2", "G3", "A3", "C3", "F4"], ["G#0", "D#3", "G3", "C4", "D4", "F4"],
["G1","D#3","F3","A#3","B3","D#3"],["C2","G2","A#3","D4","D#4","F4"],["C#2","G#2","C4","D#4","F4","G4"],["B1","E2","G#3","A#3","C#4","D#4"],["C2","E2","G#3","A#3","C4","A#4"]] @=> string chordStrings[][];
int chords[chordStrings.size()][chordStrings[0].size()]; //all chords have to be same length
notes2nums(["A3","A3", "D4","E4","B3","E3","A3","C3","E4","A3","A3","D4","E4","G4","A4","B4","E5"],1) @=> int snare[];

for(0 => int i; i<chords.size(); i++) //convert to MIDI notes
{
    notes2nums(chordStrings[i],1) @=> chords[i];
}

SawOsc sin => SawOsc overdrive => ADSR e1 => PRCRev reverb1 => BiQuad f => dac;
1 => overdrive.sync;
0.5 => overdrive.gain;
.99 => f.prad; 
1 => f.eqzs;
.03 => f.gain;
0.5 => sin.gain;
0.05 => reverb1.mix;
e1.set( 10::ms, 10::ms, .5, 50::ms );

PulseOsc saw => ADSR e2 => PRCRev reverb2 => dac;
0.9 => saw.gain;
e2.set( 10::ms, 10::ms, .5, 500::ms );
0.3 => reverb2.mix;

SqrOsc osc3 => ADSR e3 => PRCRev reverb3 => dac;
0.9 => osc3.gain;
e3.set( 10::ms, 10::ms, .5, 50::ms );
0.1 => reverb3.mix;

spork ~ ddrumTrig();
spork ~ ddrumTrig();
spork ~ ddrumTrig();
spork ~ ddrumTrig();
spork ~ ddrumTrig();

oscOut("/songSection",[0]); 

while(true)
{
    1::second => now;
}

fun void ddrumTrig()
{
    while(true)
    {
        min => now;
        <<<(msg.data2)>>>;
        
        while(min.recv(msg))
        {
            <<< msg.data1, msg.data2, msg.data3 >>>;
            if( msg.data3!=0 && msg.data2 == 0) //kick drum
            {
                //<<<bassindex>>>;
                
                e1.keyOff();
            
                
                interval/4 => hitInter;
                //<<<chordGo>>>;
                Math.random2(2,6) => int interDiv;
                now - bassTime => interval; //starts at 1000ms
                now => bassTime;
                
                if(bSection == 0) //if in A section, hit the current note 4 times
                {
                    
                  
                    oscOut("/bass",[bass[bassindex]]); //OSC
                    
                    for(0 => int i; i < interDiv; i++)
                    {
                        10000.0/(hitInter/1::ms) => currentPitch;  //set the frequency
                        currentPitch => sin.freq;
                        e1.keyOn();
                        hitInter/(interDiv/2.0) => now;
                        e1.keyOff();
                        hitInter/(interDiv/2.0) => now;
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
            else if(msg.data3!=0 && msg.data2 == 1) //snare
            {
                <<<"inter", interDiv, hitInter/(interDiv/2.0)>>>;
                (currentPitch)*(3.0/2.0)*4.0 => saw.freq;
                e2.keyOn();
                10::ms => now;
                e2.keyOff();
            }
            else if(msg.data3!=0 && msg.data2 == 2) //tom1: down a row
            {    
                (currentPitch)*(7.0/4.0)*4.0 => saw.freq;
                e2.keyOn();
                10::ms => now;
                e2.keyOff();
            }
            else if(msg.data3!=0 && msg.data2 == 54)
            {
                (currentPitch)*(9.0/4.0)*4.0 => osc3.freq;
                e3.keyOn();
                10::ms => now;
                e3.keyOff();
                
            }
            else if(msg.data3!=0 && msg.data2 == 55)
            {
                (currentPitch)*(11.0/4.0)*4.0 => osc3.freq;
                e3.keyOn();
                10::ms => now;
                e3.keyOff();
                
            }
            else if(msg.data3!=0 && msg.data2 == 56)
            {
                (currentPitch)*(13.0/4.0)*4.0 => osc3.freq;
                e3.keyOn();
                10::ms => now;
                e3.keyOff();
                
            }   
            else if(msg.data3!=0 && msg.data2 == 57)
            {
                (currentPitch)*(15.0/4.0)*4.0 => osc3.freq;
                e3.keyOn();
                10::ms => now;
                e3.keyOff();
                
            }   
            else if(msg.data3!=0 && msg.data2 == 58)
            {
                (currentPitch)*(17.0/4.0)*4.0 => osc3.freq;
                e3.keyOn();
                10::ms => now;
                e3.keyOff();
                
            }   
            else if(msg.data3!=0 && msg.data2 == 59)
            {
                (currentPitch)*(19.0/4.0)*4.0 => osc3.freq;
                e3.keyOn();
                10::ms => now;
                e3.keyOff();
                
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
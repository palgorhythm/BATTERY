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

0.20 => float defaultGain;
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

6 => int chordSize;
[36, 34, 37, 33, 31, 29, 38, 40, 30, 41, 39, 37, 35, 31, 27, 35, 33,  35, 33, 29, 25, 33, 31] @=> int rootListA[];
[35, 33, 34, 27, 29, 30, 35, 33] @=> int rootListB[];

float Achords[rootListA.size()][chordSize]; //1st dim is num of chords total, 2nd is notes in each chord

float Bchords[rootListB.size()][chordSize]; //1st dim is num of chords total, 2nd is notes in each chord

for(0 => int i; i<Achords.size(); i++) //convert to MIDI notes
{
    harmonicChord(rootListA[i], chordSize, 6.0, 3.0) @=> Achords[i];
}

for(0 => int i; i<Bchords.size(); i++) //convert to MIDI notes
{
    harmonicChord(rootListB[i], chordSize, 4.0, 3.0) @=> Bchords[i];
}

Shakers shake => dac;
defaultGain * 5.0 => shake.gain;

SawOsc soloOsc;
ADSR soloADSR;
BiQuad soloFilt;
PRCRev soloRev;
soloOsc => soloADSR => soloFilt => soloRev => dac;
soloADSR.set(5::ms, 5::ms, .5, 20::ms);
defaultGain * 0.2 => soloOsc.gain;
0.01 => soloRev.mix;
.99 => soloFilt.prad; 
5 => soloFilt.eqzs;
defaultGain * 10.0 => soloFilt.gain;


PulseOsc OSCarray[chordSize];
ADSR E[chordSize];
PRCRev R[chordSize];
BiQuad F[chordSize];

for( 0 => int i; i<chordSize; i++) 
{   
    if(i<2){
        OSCarray[i] => E[i] => R[i] => dac;
    }
    else{
        OSCarray[i] => E[i] => R[i] => dac;
    }
    defaultGain * (1.0 - (i / 25.0)) => OSCarray[i].gain;
    E[i].set(10::ms, 100::ms, .9, 1200::ms);
    0.01 => R[i].mix;
    .99 => F[i].prad; 
    1 => F[i].eqzs;
    (5-i)*0.05 => F[i].gain;
}

spork ~ ddrumTrig();
10::ms => now;
spork ~ ddrumTrig();
10::ms => now;
spork ~ ddrumTrig();
10::ms => now;
spork ~ voiceGate();
10::ms => now;

while(true)
{
    0.2::second => now;
 
    if(((globalChordIndex - 2) % 3) == 0) 
    {
        1 => bSection;
    }
    else
    {
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
            if(msg.data3 != 0){
                <<<"midi note", msg.data2, "velocity", msg.data3>>>;
            }
            if( msg.data3!=0 && msg.data2 == 0 && hitBass==0) //kick drum
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
                    //<<<Achordindex>>>;
                    for(0 => int i; i < Achords[Achordindex].size(); i++)
                    {
                        E[i].keyOff();
                    }
                    
                    
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
            else if(msg.data3!=0 && 54<=msg.data2 && msg.data2<=62){
                soloADSR.keyOff();
                msg.data2 - 54 => int soloInput; //starts at 48
                <<<(Achordindex-1)%Achords.size()>>>;
                
                Math.random2( 0, 22 ) => shake.which;
                50.0 => shake.freq;
                Math.random2f( 0, 128 ) => shake.objects;
                shake.noteOn(3.0);
                
                if(bSection == 0){
                    Achords[(Achordindex+Achords.size()-1)%Achords.size()][soloInput]*2.0=> soloOsc.freq;
                    soloADSR.keyOn();
                    20::ms=>now;
                    soloADSR.keyOff();
                }
                else{
                    Bchords[(Bchordindex+Bchords.size()-1)%Bchords.size()][soloInput]*2.0=> soloOsc.freq;
                    soloADSR.keyOn();
                    20::ms=>now;
                    soloADSR.keyOff();
                    
                }
                
                //200::ms=>now;
                
                
 
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
MidiIn min;
MidiMsg msg;


0 => int bassindex;
0 => int snareindex;
0 => int tomindex;
0 => int bSection;
0 => int chordIndex;
0 => int a;
0=> int oct;
0 => int o;


int hitTom;
now=> time tomTime; 
int hitBass;
now  => time bassTime;
int hitSnare;
now => time snareTime;

[["D#0","G2", "A#2", "C3", "D3"], ["G0","A2","A#2","C3","F3"], ["C1", "G2","A#2","C#3","F#3"], 
["F1","G2","G#2","A#2","D#3"], ["D1","E2","F2","G2","C3"],["A#1","F2","G#2","A#2","E3"],
["A0","F#2","G2","B2","C#3"],["G#1","F#2","A#2","B2","F#3"], ["F#1","G#2","A#2","B2","D#3"],
["C#2","G2","A#2","B2","F3"],["C1","G2","A#2","C3","D#3"],["C2","A2","A#2","C3","D#3"], 
["F1","A#2","D#3","F3","A#3"], ["F0","A2","D#3","F#3","B3"]] @=> string chordStrings[][];
int chords[chordStrings.size()][chordStrings[0].size()]; //all chords have to be same length

for(0 => int i; i<chords.size(); i++) //convert to MIDI notes
{
  notes2nums(chordStrings[i],1) @=> chords[i];
}

SawOsc OSCarray[5];
ADSR E[5];
PRCRev R[5];
BiQuad F[5];

for( 0 => int i; i<5; i++)
{   
    if(i==0){
        OSCarray[i] => E[i] => R[i] => dac.left;
    }
    else{
        OSCarray[i] => E[i] => R[i] => dac.right;
    }
    2*(1-(i/20)) => OSCarray[i].gain;
    E[i].set(20::ms, 10::ms, .9, 500::ms);
    0.01 => R[i].mix;
    .99 => F[i].prad; 
    1 => F[i].eqzs;
    (7-i)*.07 => F[i].gain;
}

PulseOsc soloOsc;
ADSR soloADSR;
BiQuad soloFilt;
soloOsc => soloADSR => soloFilt => dac.right;
soloADSR.set(5::ms, 5::ms, .5, 20::ms);
0.9 => soloOsc.gain;
.99 => soloFilt.prad; 
5 => soloFilt.eqzs;
0.9 => soloFilt.gain;


//MIDI port
0 => int port;

if( !min.open(port))
{
    <<<"ERROR: midi port didn't open on port:", port>>>;
    me.exit();
}

while(true)
{
    1::second => now;
}




spork ~ midiEventHandler();
10::ms => now;
spork ~ midiEventHandler();
10::ms => now;
spork ~ midiEventHandler();
10::ms => now;
spork ~ voiceGate();
10::ms => now;

fun void midiEventHandler() {
    while(true) {
        min => now;
        
        while (min.recv(msg)) {
            if (msg.data3!=0 && msg.data2 == 0 && hitBass == 0) {
              1 => hitBass; 
              
              for(0 => int i; i < chords[chordIndex].size(); i++) {
                  E[i].keyOff();
              }
                  
                    
              for(0 => int i; i < chords[chordIndex].size(); i++) {
                  Std.mtof(chords[chordIndex][i]) => OSCarray[i].freq;
                  E[i].keyOn();
              }
              
              if(chordIndex == chords.size() - 1) chordIndex + 1 => chordIndex;
              
              (chordIndex + 1) % chords.size() => chordIndex;
              
              
              100::ms => now;
              
              
              for(0 => int i; i < chords[chordIndex].size(); i++) {
                  E[i].keyOff();
              }
              
              100::ms => now;    
            } else if (msg.data3!=0 && 54<=msg.data2 && msg.data2<=58) {
                soloADSR.keyOff();
                msg.data2 - 54 => int soloInput; //starts at 48
                
                if(soloInput==0) { 
                    3 => o;
                } else {
                    1 => o;
                }
                Std.mtof(chords[chordIndex%chords.size()][soloInput]+(o*12)+(oct*12))=> soloOsc.freq;
                soloADSR.keyOn();
                20::ms=>now;
                soloADSR.keyOff();
                
            } else if(msg.data3!=0 && 60<=msg.data2 && msg.data2<=61) {
                if(msg.data2 == 60) {
                    oct--;
                } else {
                    oct++;
                }
            }
        }
    }    
}


///UTIL FUNCTIONS///


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
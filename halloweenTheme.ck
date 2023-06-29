MidiIn min;
MidiMsg msg;

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[1]);

0 => int barIndex;
0 => int melIndex;
int hitTom;
now=> time tomTime; //had added + 1000::second before, why???
int hitBass;
now  => time bassTime;
int hitSnare;
now => time snareTime;

//FORM: F#x3, F, F#, F, E, D#, E, D#, Bx5 

//TOP MELODY STUFF
int melody[29][4];
["C#5","C#5","C#5","D5"] @=> string baseMelody[];
notes2nums(baseMelody, 1) @=> int fSharpMelody[];
transpose(notes2nums(baseMelody, 1),"down",1) @=> int fMelody[];
transpose(notes2nums(baseMelody, 1),"down",2) @=> int eMelody[];
transpose(notes2nums(baseMelody, 1),"down",3) @=> int dSharpMelody[];
transpose(notes2nums(baseMelody, 1),"down",7) @=> int bMelody[];

for(0 => int i; i<6; i++)
{
    fSharpMelody @=> melody[i];
}
fMelody @=> melody[6];
fMelody @=> melody[7];
fSharpMelody @=> melody[8];
fSharpMelody @=> melody[9];
fMelody @=> melody[10];
fMelody @=> melody[11];
eMelody @=> melody[12];
eMelody @=> melody[13];
dSharpMelody @=> melody[14];
dSharpMelody @=> melody[15];
eMelody @=> melody[16];
eMelody @=> melody[17];
dSharpMelody @=> melody[18];
dSharpMelody @=> melody[19];
for(20 => int i; i<29; i++)
{
    bMelody @=> melody[i];
}

//MID MELODY STUFF
int midMel[29];
["F#4","F#4","F#4","F#4","F#4","F#4","F4","F4","F#4","F#4","F4","F4","E4","E4","D#4","D#4","E4","E4","D#4","D#4","B3","B3","B3","B3","B3","B3","B3","B3","B3"] @=> string secondMelody[];
notes2nums(secondMelody,1) @=> midMel;

//BASS STUFF
int bass[29];
//C-2 gives 0 (stand-in for no bass note)
["C-2","C-2","C-2","C-2","F#1","A1","A#1","A#1","F#1","A1","A#1","A#1","E1","G1","D#1","D#1","E1","G1","D#1","D#1","B0", "D1", "E1","F#1","B0", "D1", "E1","F#1","C-2"] @=> string bassStr[];
notes2nums(bassStr,1) @=> bass;


PulseOsc bassOsc => ADSR e1 => BiQuad f1 => PRCRev reverb1 => dac.left;
.99 => f1.prad; 
1 => f1.eqzs;
.05 => f1.gain;
0 => reverb1.mix;
e1.set( 10::ms, 20::ms, .5, 2000::ms );

SawOsc midMelOsc => ADSR e2 => BiQuad f2 => PRCRev reverb2 => dac.right;
.99 => f2.prad; 
1 => f2.eqzs;
.5 => f2.gain;
0 => reverb2.mix;
e2.set( 10::ms, 20::ms, .5, 500::ms );

SawOsc melOsc => ADSR e3 => BiQuad f3 => PRCRev reverb3 => dac.right;
.99 => f3.prad; 
1 => f3.eqzs;
.9 => f3.gain;
0 => reverb3.mix;
e3.set( 10::ms, 20::ms, .5, 500::ms );

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
            if( msg.data3!=0 && msg.data2 == 0 && hitBass==0) //kick drum
            {
                oscOut("/chords",[midMel[barIndex]]); //OSC midi note number!
                0 => hitBass;
                now => bassTime;
                
                Std.mtof(midMel[barIndex]) => midMelOsc.freq;
                e2.keyOn();
                200::ms => now;
                e2.keyOff();  
            }   
            else if(msg.data3!=0 && msg.data2 == 1 && hitSnare==0) //snare
            {
                //<<<barIndex,melIndex>>>;
                oscOut("/melody",[melody[barIndex][melIndex]]); //OSC midi note number!
                1 => hitSnare;
                now => snareTime;
                
                Std.mtof(melody[barIndex][melIndex]) => melOsc.freq;
                e3.keyOn();
                if(melIndex == 0)
                {
                    if(bass[barIndex]!=0)
                    {
                        oscOut("/bass",[bass[barIndex]]);
                        Std.mtof(bass[barIndex]) => bassOsc.freq;
                        e1.keyOn();
                        200::ms => now;
                        e1.keyOff(); 
                    }
                }
                
                200::ms => now;
                e3.keyOff();  
                
                melIndex + 1 => melIndex;
                if(melIndex==4)
                {
                    0 => melIndex;
                    (barIndex + 1) % bass.size() => barIndex;
                }
               
                
                
            }
            else if(msg.data3!=0 && msg.data2 == 2 && hitTom == 0) //tom1: down a row
            {    
                
                
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

fun void oscOut(string addr, int val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}
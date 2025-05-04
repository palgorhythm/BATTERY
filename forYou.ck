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
oscOut("/song",[7]);

0 => int device;
0 => int c;
0 => int c2;
int hitTom;
now + 1000::second => time tomTime;
int hitBass;
now + 1000::second => time bassTime;
0 => float len;



notes2nums(["G3", "F3", "A3", "D3", "D#3", "A#3", "F3", "A#2", "A#2", "C#3", "D#3"], 4) @=> int melodyA[]; //length 11
notes2nums(["D#2", "C#2", "F2", "A#1", "B1", "F#2", "C#2", "F#1","F#1","A#1", "B1"], 4) @=> int bassA[]; 
notes2nums(["G3", "A3", "B3", "F#3", "E3", "F#4", "E4", "F#5", "E5"],4) @=> int melodyB[];  //length 9
notes2nums(["D#1", "F1", "G1", "D1", "C1", "D1", "C1", "D1", "C1"],4) @=> int bassB[];
notes2nums(["G3"],1) @=> int transitionMelody[];
notes2nums(["D#2"],1) @=> int transitionBass[];
notes2nums(["F#3", "E3", "F#3", "E3", "G3", "G3","G3","G3"],1) @=> int melodyC[]; //length 8
notes2nums(["D2", "C2", "D2", "C2", "E1", "D#1", "C1", "G#0"],1) @=> int bassC[];
notes2nums(["F4","G4","C4"],1) @=> int lineA1[]; //13x
notes2nums(["C#4","G#4","A#4"],1) @=> int lineA2[]; //13x
notes2nums(["G4","A4","D5"],1) @=> int lineB1[]; //7x
notes2nums(["A4","B4","E5"],1) @=> int lineB2[]; //13x

changeOctave(concatArrays([melodyA,melodyB,transitionMelody,melodyC]),"down",0) @=> int melody[];
changeOctave(concatArrays([bassA,bassB,transitionBass,bassC]),"down",0) @=> int bass[];
changeOctave(concatArrays([lineA1,lineA2,lineA1,lineA2,lineB1,lineB2,lineB1,lineB2]),"down",1) @=> int lines[];//<<<bass.size()>>>;


//A 4x, 2x with nothing else and 2x with extra line over it
//B 4x, 2x with nothing else and 2x with extra 3 line over it
//C 1x, 

SqrOsc sin => ADSR e1 => PRCRev reverb1 => dac;
SawOsc saw => ADSR e2 => PRCRev reverb2 => dac;
SqrOsc sqr => ADSR e3 => PRCRev reverb3 => dac;
e3.set( 5::ms, 15::ms, .7, 1000::ms );
.01 => reverb3.mix;
1.05 => sin.gain;
1 => saw.gain;
1 => sqr.gain;

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
        if(hitTom==1 && (now > tomTime + 200::ms) )
        {
            0 => hitTom;
        }
        if(hitBass==1 && (now > bassTime + 100::ms) )
        {
            0 => hitBass;
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
            if( msg.data3!=0 && msg.data2 == 0 && hitBass == 0) //kick drum
            {
                
                //(msg.data2/30.0) => sin.gain;
                //(msg.data2/30.0) => saw.gain;
                oscOut("/bass",[bass[c]]);
                oscOut("/melody",[melody[c]]);
                
                Std.mtof(bass[c]) => sin.freq;  //set the frequency
                Std.mtof(melody[c]) => saw.freq;
                
                if(c == 44)
                {
                    oscOut("/songSection",[1]);
                }
                else if(c == 80)
                {
                    oscOut("/songSection",[2]);
                }
                
                if(c > 43 && c < 80)
                {
                    e1.set( 10::ms, 30::ms, 1.5, 5000::ms );
                    e2.set( 10::ms, 30::ms, 1.5, 5000::ms );
                    .1 => reverb1.mix;
                    .1 => reverb2.mix;
                    (((c+11)/11)*10) => len;
                    //(c*10)*(len+1::ms) => len;
                } 
                else if( c > 79 )
                {
                    
                    e1.set( 5::ms, 30::ms, .9, 5000::ms );
                    e2.set( 5::ms, 30::ms, .9, 5000::ms );
                    .1 => reverb1.mix;
                    .1 => reverb2.mix;
                    (((c+11)/11)*10) => len;
                }
                else
                {
                    (((c+11)/11)*750) => float a;
                    //<<<a>>>;
                    e1.set( 10::ms, 30::ms, .9, a::ms );
                    e2.set( 10::ms, 30::ms, .9, a::ms );
                    0.05 => reverb1.mix;
                    0.05 => reverb2.mix;
                    (((c+11)/11)*10) => len;
                    
                   
                    //<<<a/500>>>;
                }
                1 => hitBass;
                now => bassTime; 
                
                e1.keyOn();
                e2.keyOn();
                len::ms => now;
                e1.keyOff();  
                e2.keyOff();
                c++;                
            }   
            else if(msg.data3!=0 && msg.data2 == 2 && hitTom == 0) //tom1: down a row
            {      
                //(msg.data2/50.0) => sqr.gain; 
                
                if((c % 11) > 3 && c < 44 )              
                {
                    Std.mtof(lineA2[c2 % 3]) => sqr.freq;  //set the frequency
                }
                else if((c % 11) < 4 && c < 44)
                {
                    Std.mtof(lineA1[c2 % 3]) => sqr.freq;
                }
                else if((c % 9) > 3 && c > 43 && c < 80) 
                {
                    Std.mtof(lineB2[c2 % 3]) => sqr.freq;
                }
                else
                {
                    Std.mtof(lineB1[c2 % 3]) => sqr.freq;
                }
                
                
                
                e3.keyOn();
                10::ms => now;
                e3.keyOff();  
                1 => hitTom;
                now => tomTime;
                
                c2++;
                
            }
           
        }
    }    
}

//UTIL FUNCTIONS

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

function int[] concatArrays(int X[][])
{
    int len;
    
    for(0 => int i; i<X.size(); i++)
    {
        len + X[i].size() => len;     
    }
    
    int result[len];
    0 => int counter;
    
    for(0 => int i; i<X.size(); i++)
    {
        for(0 => int j; j<X[i].size(); j++)
        {
            X[i][j] => result[counter];
            counter++;
        }
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

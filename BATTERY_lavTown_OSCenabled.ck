MidiIn min;
MidiMsg msg;

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[5]);

0 => int device;
300 => int c;
0 => int line;
0 => int midInd;
0 => int bassInd;
int hitTom;
now + 1000::second => time tomTime;
int hitBass;
now + 1000::second => time bassTime;



notes2nums(["C5","G5","B5","F#5"],1) @=> int ost[]; //length 336 (total qt notes in piece)
changeOctave(notes2nums(["B4","G4","F#4","B4","B5","G5","F#5","B5","B6","G6","F#6","B6","B7","G7","F#7","B7"],1),"up",1) @=> int ostVar[];// happens at line 5 (line=4 bars), 9, 13, 17, 21  
notes2nums(["G3","G3","E3","E3","G3","F#3","E3","B3","E3","C3","B2","E3"],1) @=> int m1[];  //length 9
notes2nums(["E3","D3","C3","C#3","C#3"],1) @=> int b1[];  //length 9
notes2nums(["G3","G3","F#3","F#3","B3","G3","F#3","B3","E3","C3","B2","E3"],1) @=> int m2[];  //length 9
notes2nums(["E3","D3","C3","C4","C4"],1) @=> int b2[];  //length 9
notes2nums(["G3","G3","F#3","F#3","B3","G3","F#3","B3","E3","G3","F#3","B3"],1) @=> int m3[];  //length 9
notes2nums(["C3","C3"],1) @=> int b3[];
notes2nums(["E3","D3","C3","E3","C3","A2","E3"],1) @=> int b9[];  //length 9
notes2nums(["G3","G3","E3","E3","G3","F#3","E3","B3","E3","G3","F#3","B3"],1) @=> int m5[];  //length 9
notes2nums(["C#3","C#3"],1) @=> int b4[];
notes2nums(["E3","D3","C3","C3","C3"],1) @=> int b5[];
notes2nums(["E3","D3","C3","E3","C3","B2","E3"],1) @=> int b6[];



changeOctave(concatArrays([m1,m2,m1,m3,m1,m2,m5,m2,m1,m3,m1,m2,m5,m2,m1,m2]),"down",0) @=> int mid[];
changeOctave(concatArrays([b1,b2,b1,b3,b9,b1,b2,b4,b5,b6,b1,b3,b1,b2,b9,b4,b2,b1,b5]),"down",0) @=> int bass[];

//<<<bass.size()>>>;


//A 4x, 2x with nothing else and 2x with extra line over it
//B 4x, 2x with nothing else and 2x with extra 3 line over it
//C 1x, 

SawOsc o1 => ADSR e1 => dac;
SqrOsc o2 => ADSR e2 => dac;
SqrOsc o3 => ADSR e3 => PRCRev reverb3 => dac;
SawOsc o4 => ADSR e4 => PRCRev reverb4 => dac;
e1.set( 5::ms, 5::ms, .5, 10::ms );
e2.set( 5::ms, 5::ms, .5, 10::ms );
e3.set( 20::ms, 20::ms, .5, 2000::ms );
e4.set( 20::ms, 20::ms, .5, 2000::ms );
.01 => reverb3.mix;
.01 => reverb4.mix;
0.8 => o1.gain;
0.8 => o2.gain;
1.0 => o3.gain;
1.0 => o4.gain;

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

while(true)
{
    oscOut("/chords",[ost[c % ost.size()]]);
    Std.mtof(ost[c % ost.size()]) => o1.freq; //mod to stay within 0-3.
    
    if(line==4 || line==8 || line==12 || line==16 || line==20)
    {
        oscOut("/chords",[ostVar[c % ostVar.size()]]);
        Std.mtof(ostVar[c % ostVar.size()]) => o2.freq; //mod to stay w/in 0-15.
        e2.keyOn();
    }
    e1.keyOn();
    
    0.5::second => now;
    c++; //global qtr note number
    c/16 => line; 
    e1.keyOff();
    e2.keyOff();
    500.0 => float songLength;
    (songLength-c)*2/songLength => e1.gain;
    (songLength-c)*2/songLength => e2.gain;
    if( c > songLength)
    {
        0.0 => e1.gain;
        0.0 => e2.gain;
    }
    
}

fun void voiceGate()
{
    while(true)
    {
        if(hitTom==1 && (now > tomTime + 200::ms) )
        {
            0 => hitTom;
        }
        if(hitBass==1 && (now > bassTime + 200::ms) )
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
        
        while(min.recv(msg))
        {            
            <<< msg.data1, msg.data2, msg.data3 >>>;
            if(msg.data3!=0 && msg.data2 == 38 && hitTom==0) //tom1
            {   
                //(msg.data2/50.0) => o3.gain;   
                1 => hitTom;
                now => tomTime;   
                
                oscOut("/melody",[mid[midInd % mid.size()]]);
                Std.mtof(mid[midInd % mid.size()]) => o3.freq;  //set the frequency
                e3.keyOn();
                10::ms => now;
                e3.keyOff();  
                
                
                midInd++;
                
            }
            else if( msg.data3!=0 && msg.data2 == 36 && hitBass==0) //kick drum
            {
                1 => hitBass;
                now => bassTime;
                //<<<100>>>;
                //(msg.data2/50.0) => o4.gain;  
                
                oscOut("/bass",[bass[bassInd % bass.size()]]);
                Std.mtof(bass[bassInd % bass.size()]) => o4.freq;  //set the frequency
                e4.keyOn();
                10::ms => now;
                e4.keyOff();  
                
                
                bassInd++;        
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
 MidiIn min;
MidiMsg msg;

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[4]);
//150 bpm?

0 => int device;

0 => int bassindex;
0 => int snareindex;
0 => int tomindex;
int hitTom;
now + 1000::second => time tomTime;
int hitBass;
now + 1000::second => time bassTime;
int hitSnare;
now + 1000::second => time snareTime;

[30, 30, 30, 26, 26, 26, 24, 24, 24, 36, 36, 36, 34, 34, 34, 31, 31, 31, 29, 29, 34, 34, 41, 41, 33, 31] @=> int aSection[];
//[30, 30, 30, 30, 26, 26, 26, 26, 24, 24, 24, 24, 36, 36, 36, 36, 34, 34, 34, 34, 31, 31, 31, 31, 29, 29, 34, 34, 41, 41, 33, 31] @=> int aSection[];
[36,36,36,36,36,36,36,36,37,37,37,37,37,37,37,37,39,39,39,39,39,39,39,39,32,32,32,32,32,32,32,32,33,33,33,33,33,33,33,33,31,31,31,31,31,31,31,31,39,39,39,39,39,39,39,39,40,35,40,35,40,35,33,31] @=> int bSection[];
//[36,37,39,32,33,31,39,40,35,40,35,40,35,33,31] @=> int bSection[];
(3*aSection.size())+bSection.size()+aSection.size() => int songLength;
int bass[songLength];
//<<<aSection.size()>>>;
//<<<bSection.size()>>>;
//p<<<songLength>>>;

0 => int aCounter;
0 => int bCounter;

for(0 => int i; i<songLength;i++)
{
    
    if(i<(aSection.size()*3) || i > (aSection.size()*3)+bSection.size()-1)
    {
        aSection[aCounter%aSection.size()] => bass[i];
        (aCounter + 1)%aSection.size() => aCounter;
        
    }
    else
    {
        bSection[bCounter%bSection.size()] => bass[i];
        bCounter + 1 => bCounter;
    }
}

    
[0, 4, 7, 11] @=> int tom[]; //make minor chord
[0, 4, 7, 11] @=> int snare[]; //make major chord
//[63] @=> int snare[];


BeeThree string0 => ADSR e0 => dac.left;
BeeThree string1 => ADSR e1 => dac.left;
BeeThree string2 => ADSR e2 => dac.right;
BeeThree string3 => ADSR e3 => dac.right;


e0.set( 10::ms, 5::ms, .5, (bassindex)*10::ms );
e1.set( 10::ms, 5::ms, .5, (bassindex)*10::ms );
e2.set( 5::ms, 5::ms, .1, 100::ms );
e3.set( 5::ms, 5::ms, .1, 100::ms );


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

while(true)
{
    1::second => now;
}

fun void voiceGate()
{
    while(true)
    {
        if(hitTom==1 && (now > tomTime + 300::ms) )
        {
            0 => hitTom;
        }
        if(hitBass==1 && (now > bassTime + 200::ms) )
        {
            0 => hitBass;
        }
        if(hitSnare==1 && (now > snareTime + 50::ms) )
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
               
                e0.set( 10::ms, 10::ms, .5, (bassindex)*20::ms );
                e1.set( 10::ms, 10::ms, .5, (bassindex)*20::ms );
                1 => hitBass;
                now => bassTime; 
                oscOut("/bass",[bass[bassindex]]);
                Std.mtof(bass[bassindex]) => string0.freq;  //set the frequency
                Std.mtof(bass[bassindex]+7) => string1.freq;  //set the frequency
                
                bass.size() $ float => float bassSizeFloat;
                //bassindex/bassSizeFloat => string0.controlTwo;
                //(bassindex+1.0)/(bassSizeFloat*15) => string0.controlOne;
                //<<<(bassindex+1.0)/bassSizeFloat>>>;
                //(bassindex+1.0)/bassSizeFloat => string0.afterTouch;

                bassindex/bassSizeFloat => string1.controlOne;
                (bassindex+1.0)/(bassSizeFloat*15) => string1.afterTouch;

                
                e0.keyOn();
                10.0 => string0.noteOn;                
                e1.keyOn();
                10.0 => string1.noteOn;
                
                100::ms => now;
                e0.keyOff();
                e1.keyOff();
                //0.0 => moog.noteOff;
                
          
                
                  
                (bassindex + 1) % bass.size() => bassindex;                
            }   
            else if(msg.data3!=0 && msg.data2 == 1 && hitSnare==0) //snare
            {
                1 => hitSnare;
                now => snareTime;
                Math.random2(0,snare.size()-1) => snareindex;
                
                e2.set( 10::ms, 10::ms, .5, (bassindex)*20::ms );
                e3.set( 10::ms, 10::ms, .5, (bassindex)*20::ms );
                
                oscOut("/melody",[snare[snareindex]]); 
                //<<<bass[bassindex],snare[snareindex]>>>;
                Math.random2(0,2) => int choice;
                int transp;
                if(choice ==0){
                    0 => transp;
                }
                else if(choice ==1){
                    12 => transp;
                }
                else if(choice ==2){
                    24 => transp;
                }
   
                
                if(bassindex == 0)
                {
                     Std.mtof(bass[bassindex] + snare[snareindex] + 12 + transp) => string2.freq;
                     Std.mtof(bass[bassindex] + snare[snareindex] + 24 + transp) => string3.freq;
                }
                else
                {
                     Std.mtof(bass[bassindex-1] + snare[snareindex] + 12 + transp) => string2.freq;
                     Std.mtof(bass[bassindex-1] + snare[snareindex] + 24+ transp) => string3.freq;
                }
                            
              //set the frequency
                e2.keyOn();
                15.0 => string2.noteOn;
                
                e3.keyOn();
                15.0 => string3.noteOn;
                200::ms => now;
                e3.keyOff();
                e2.keyOff();
                
                //<<<snareindex>>>;
                
                //(snareindex + 1) % snare.size() => snareindex;
            }
            else if(msg.data3!=0 && msg.data2 == 2) //tom1: down a row
            {    
                //1 => hitTom;
                //now => tomTime;
                    
                Math.random2(0,tom.size()-1) => tomindex; 
                oscOut("/chords",[tom[tomindex]]);              
                
                Std.mtof(bass[bassindex] + tom[tomindex] + 36) => string3.freq;  //set the frequency
                
                e3.keyOn();
                20.0 => string3.noteOn;
                100::ms => now;
                e3.keyOff();
                
                
                (tomindex + 1) % tom.size() => tomindex;
            
            }
        }
    }    
}

fun void oscOut(string addr, int val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}
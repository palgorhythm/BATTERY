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


0 => int device;

0 => int bassindex;
0 => int snareindex;
0 => int tomindex;
int hitTom;
now + 1000::second => time tomTime;
0 => int hitBass;
now + 1000::second => time bassTime;
0 => int hitSnare;
now + 1000::second => time snareTime;


[37, 44, 41, 36, 39, 32, 34, 39] @=> int bass[];
[53, 60, 58, 63, 61, 56, 51 ] @=> int tom[];
[63, 65, 67, 72, 65, 65, 63, 61, 58 ] @=> int snare[];


PulseOsc sin => ADSR e1 => BiQuad f => PRCRev reverb1 => dac;
.99 => f.prad; 
// set equal gain zeros
1 => f.eqzs;
// set filter gain
.04 => f.gain;
PulseOsc saw => ADSR e2 => PRCRev reverb2 => dac;
SqrOsc sqr => ADSR e3 => PRCRev reverb3 => dac;
1.0 => sin.gain;
2.0 => saw.gain;
2.0 => sqr.gain;
e1.set( 10::ms, 5::ms, .5, 1500::ms );
e2.set( 10::ms, 5::ms, .5, 1000::ms );
e3.set( 10::ms, 5::ms, .5, 1000::ms );
.01 => reverb1.mix;
.01 => reverb2.mix;
.01 => reverb3.mix;

spork ~ ddrumTrig();
20::ms => now;
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
        if(hitTom==1 && (now > tomTime + 100::ms) )
        {
            0 => hitTom;
        }
        if(hitBass==1 && (now > bassTime + 100::ms) )
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
            <<< msg.data1, msg.data2, msg.data3, hitBass >>>;
            if( msg.data3!=0 && msg.data2 == 0 && hitBass==0) //kick drum
            {
                //(msg.data2/80.0) => sin.gain;
                1 => hitBass;
                now => bassTime; 
                Std.mtof(bass[bassindex]) => sin.freq;  //set the frequency
                e1.keyOn();
                200::ms => now;
                e1.keyOff();  
                
                  
                (bassindex + 1) % bass.size() => bassindex;                
            }   
            else if(msg.data3!=0 && msg.data2 == 1 && hitSnare==0) //snare
            {
                1 => hitSnare;
                now => snareTime;
                              
                Std.mtof(snare[snareindex]) => saw.freq;  //set the frequency
                e2.keyOn();
                200::ms => now;
                e2.keyOff();
                
                //<<<snareindex>>>;
                
                (snareindex + 1) % snare.size() => snareindex;
            }
            else if(msg.data3!=0 && msg.data2 == 2 && hitTom == 0) //tom1: down a row
            {    
                1 => hitTom;
                now => tomTime;                  
                Std.mtof(tom[tomindex]) => sqr.freq;  //set the frequency
                e3.keyOn();
                200::ms => now;
                e3.keyOff();  
                
                
                (tomindex + 1) % tom.size() => tomindex;
            
            }
        }
    }    
}
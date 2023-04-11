MidiIn min;
MidiMsg msg;

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[6]);

0 => int device;

int hitTom;
now + 1000::second => time tomTime;
int hitBass;
now + 1000::second => time bassTime;
int hitSnare;
now + 1000::second => time snareTime;
int toggle;


Noise n1 => Gain g1 => BiQuad f1 => dac.left;
// set biquad pole radius
0 => g1.gain;
.99 => f1.prad;
// set biquad gain
.06 => f1.gain;
// set equal zeros 
10 => f1.eqzs;


Noise n2 => Gain g2 => BiQuad f2 => dac.right;
// set biquad pole radius
0 => g2.gain;
.99 => f2.prad;
// set biquad gain
.5 => f2.gain;
// set equal zeros 
10 => f2.eqzs;


Noise n3 => Gain g3 => BiQuad f3 => dac.right;
// set biquad pole radius
0 => g3.gain;
.99 => f3.prad;
// set biquad gain
.6 => f3.gain;
// set equal zeros 
10 => f3.eqzs;


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

Noise n => Gain g => BiQuad f => dac;
// set biquad pole radius
.99 => f.prad;
// set biquad gain
.5 => f.gain;
// set equal zeros 
1 => f.eqzs;
// our float
0.0 => float t;

// infinite time-loop
while( true )
{
    if(toggle!=1)
    {
        Std.rand2f(0.7,1.0) => g.gain;
    }
    // sweep the filter resonant frequency
    Std.rand2f(100.0,5000.0) => float temp;
    //oscOut("/chords",[ftom(temp)]);
    temp => f.pfreq;
    // advance time
    30::ms => now;
    0 => g.gain;
    60::ms => now;
    
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
            //<<< msg.data1, msg.data2, msg.data3 >>>;
            if( msg.data3!=0 && msg.data2 == 0 && hitBass==0) //kick drum
            {
                
                1 => hitBass;
                now => bassTime; 
                msg.data2/50.0 => g1.gain;
                Std.rand2f(50.0,100.0) => float a;
                Std.rand2f(100.0,300.0) => float b;
                a => f1.pfreq;
                oscOut("/bass",[ftom(a)]);
                b::ms => now;   
                0 => g1.gain;  
                0 => g2.gain;           
            }   
            else if(msg.data3!=0 && msg.data2 == 1 && hitSnare==0) //snare
            {
                1 => hitSnare;
                now => snareTime;
                msg.data2/50.0 => g1.gain;
                msg.data2/50.0 => g2.gain;
                Std.rand2f(1000.0,5000.0) => float a;
                a => f2.pfreq;
                //Std.rand2f(100.0,300.0) => f1.pfreq;
                Std.rand2f(100.0,1000.0) => float b;
                oscOut("/melody",[ftom(a)]);
                b::ms => now;   
                0 => g2.gain;
                0 => g1.gain;
                //0 => g1.gain;
            }
            else if(msg.data3!=0 && msg.data2 == 2 && hitTom == 0) //tom1: down a row
            {    
                1 => hitTom;
                now => tomTime;        
                msg.data2/50.0 => g1.gain;       
                Std.rand2f(50.0,500.0) => float a; 
                a => f1.pfreq;
                Std.rand2f(8000.0,10000.0) => f2.pfreq;
                Std.rand2f(200.0,1000.0) => float b;
                oscOut("/melody",[ftom(a)]);
                b::ms => now;   
                0 => g3.gain;
                0 => g.gain;
                1 => toggle;
                
            }
        }
    }    
}


fun int ftom(float freq)
{
    69+(12*Math.log2(freq/440)) $ int => int temp;
    return temp;
}

fun void oscOut(string addr, int val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}
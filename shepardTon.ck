MidiIn min;
MidiMsg msg;

OscOut osc;
osc.dest("10.10.10.1",6969);
oscOut("/song",[1]);

0 => int bassindex;
0 => int melodyindex;
int bassRampGo;
int melodyRampGo;
int bassOn;
int melodyOn;
Shred @ bassShred;
Shred @ melodyShred;

int hitTom;
now=> time tomTime; //had added + 1000::second before, why???
int hitBass;
now  => time bassTime;
int hitSnare;
now => time snareTime;
5000::ms => dur interval; //duration between bass drum hits


[45,38,39,40,47,50,43,36] @=> int bass[];
[60,64,67,66,76,71,64,71] @=> int melody[];

SawOsc bassOsc => SawOsc c => SawOsc overdrive => ADSR e1  => BiQuad f => dac.left;
.99 => f.prad; 
1 => f.eqzs;
0.01 => f.gain;
1 => overdrive.sync; // set sync option to Phase Mod.
100 => overdrive.gain;
200 => c.gain;
1 => c.freq;
e1.set( 10::ms, 10::ms, 0.5, 20::ms );
0.1 => bassOsc.gain;


SinOsc melodyOsc => SawOsc overdrive2 =>  ADSR e2 => PRCRev reverb2 => dac.right;
e2.set( 10::ms, 10::ms, .5, 20::ms );
1 => overdrive2.sync; 
20 => melodyOsc.gain;
20 => overdrive2.gain;
.01 => reverb2.mix;

PulseOsc bassOsc2 => ADSR e3 => BiQuad f3  => dac.right;
.99 => f3.prad; 
1 => f3.eqzs;
.2 => f3.gain;
5 => bassOsc2.gain;
e3.set( 100::ms, 10::ms, .5, 20::ms );





//MIDI port
0 => int port;

if(!min.open(port))
{
    <<<"ERROR: midi port didn't open on port:", port>>>;
    me.exit();
}

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
               
                //0 => bassRampGo;
                //50::ms => now;
                e1.keyOff();
                
                if(bassShred !=null && bassShred.id()!=0 ){
                    <<<bassShred.id()>>>;
                  Machine.remove(bassShred.id());
                }
                if(melodyShred !=null && melodyShred.id()!=0 ){
                    e2.keyOff();
                    Machine.remove(melodyShred.id());
                }
                
                spork ~ pitchRamp("down",Std.mtof(bass[bassindex]), bassOsc, e1) @=> bassShred;

                now => bassTime;
                
                oscOut("/bass",[bass[bassindex]]); //OSC
       
                    
            }   
            else if(msg.data3!=0 && msg.data2 == 1 && hitSnare==0) //snare
            {
                e2.keyOff();
                
                if(melodyShred !=null && melodyShred.id()!=0 ){
                    
                    Machine.remove(melodyShred.id());
                }
                
                spork ~ pitchRamp("up",Std.mtof(melody[melodyindex]),melodyOsc,e2) @=> melodyShred;
            
                
                oscOut("/melody",[melody[melodyindex]]); //OSC!
       
                now => snareTime;             
                
              
                
    
}
            else if(msg.data3!=0 && msg.data2 == 2 && hitTom == 0) //tom1: down a row
            {    
                e1.keyOff();
                e2.keyOff();
                
                if(melodyShred !=null){
                    
                    Machine.remove(melodyShred.id());
                }
                if(bassShred !=null){
                    
                    Machine.remove(bassShred.id());
                }
                1 => hitTom;
                
                (melodyindex + 1) % melody.size() => melodyindex;  
                (bassindex + 1) % bass.size() => bassindex;   
         
                
            }
            else if(msg.data3!=0 && 54<=msg.data2<=62) //tom1: down a row
            {    
            
                
                Math.random2(1,3) => int choice;
                int transp;
                if(choice ==0){
                    -5 => transp;
                }
                else if(choice ==1){
                    0 => transp;
                }
                else if(choice ==2){
                    7 => transp;
                }
                else if(choice ==3){
                    12 => transp;
                }
                else if(choice ==4){
                    19 => transp;
                }
                
                Std.mtof(bass[bassindex]+(msg.data2-26)+transp) => bassOsc2.freq;
                e3.keyOn();
                20::ms => now;
                e3.keyOff();
            }
           
        }
    }    
}


///UTIL FUNCTIONS///

function void pitchRamp(string downOrUp, float freq, Osc osc, ADSR adsr)
{
    if(downOrUp == "down")
    {
        if(freq <= 0){
            return;
        }
        
        freq => bassOsc.freq;
        freq => float startFreq;
        adsr.keyOn();
        300::ms => now;
        
        while(freq > 0)
        {
            50::ms => now;
            freq - 0.75 => freq;
            freq => osc.freq;
        }
        50::ms => now;
        adsr.keyOff();
    }
    else if (downOrUp == "up")
    {
        2.0 => melodyOsc.gain;
        freq => melodyOsc.freq;
        Std.mtof(bass[bassindex]) => float startFreq;
        adsr.keyOn();
        if(melodyOn){
            0.01=>bassOsc.gain;
        }
        10::ms=> now;
        while(freq<startFreq*100.0)
        {
            if(melodyOn)
            {
                (50.0)*((freq/(startFreq*100))) => c.gain;
            }
            10::ms => now;
            freq + 20.0 => freq;
            freq => osc.freq;
        }
        50::ms=>now;
        adsr.keyOff();
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

fun void oscOut(string addr, int val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}
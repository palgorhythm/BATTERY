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

0.03 => float defaultGain;

SawOsc bassOsc => SawOsc c => SawOsc overdrive => ADSR e1  => BiQuad f => PRCRev reverb1 => dac;
.99 => f.prad; 
1 => f.eqzs;
1 => overdrive.sync; // set sync option to Phase Mod.
1 => c.sync;
1000 => bassOsc.gain;
500 => c.gain;
500 => overdrive.gain;
1  => c.freq;
e1.set( 10::ms, 10::ms, .5, 20::ms );
defaultGain * 0.0000000005 => f.gain;
.03 => reverb1.mix;

PulseOsc melodyOsc => SawOsc overdrive2 => ADSR e2 => PRCRev reverb2 => dac;
e2.set( 10::ms, 10::ms, .5, 20::ms );
1 => overdrive2.sync; 
1000 => melodyOsc.gain;
defaultGain * 0.05 => overdrive2.gain;
.03 => reverb2.mix;

SawOsc bassOsc2 => ADSR e3 => BiQuad f3 => PRCRev reverb3 => dac;
.99 => f3.prad; 
1 => f3.eqzs;
defaultGain * 15.0 => bassOsc2.gain;
defaultGain * 15.0 => f3.gain;
e3.set( 100::ms, 10::ms, .5, 20::ms );
.05 => reverb3.mix;

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
            }   
            else if(msg.data3!=0 && msg.data2 == 1 && hitSnare==0) //snare
            {
                e2.keyOff();
                
                if(melodyShred !=null && melodyShred.id()!=0 ){
                    
                    Machine.remove(melodyShred.id());
                }
                
                spork ~ pitchRamp("up",Std.mtof(melody[melodyindex]), melodyOsc ,e2) @=> melodyShred;
           
       
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
            adsr.keyOff();
            return;
        }
        
        freq => osc.freq;
        freq => float startFreq;
        adsr.keyOn();
        300::ms => now;
        
        while(freq > 0)
        {
            freq - (1.5) => freq;
            freq => osc.freq;
            50::ms => now;
        }
        adsr.keyOff();
    }
    else if (downOrUp == "up")
    {
        500.0 => osc.gain;
        freq => osc.freq;
        Std.mtof(bass[bassindex]) => float startFreq;
        adsr.keyOn();
        10::ms=> now;
        while(freq < startFreq*100.0)
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
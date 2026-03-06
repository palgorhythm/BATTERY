// ============================================================
// ROLI - bass/snare/tom sequence triggered by drums
// MIDI via IAC Driver | Audio output on channels 3 & 4
// ============================================================

// Sensory Percussion MIDI map:
// Drums: kick=0, snare=1, rack tom=2, floor tom=3
// Hi-hat zones:  4 (bow), 5 (edge), 6 (bell-shoulder), 7 (bell-tip), 8 (ping)
// Crash zones:   9 (bow), 10 (edge), 11 (bell-shoulder), 12 (bell-tip), 13 (ping)
// Ride zones:    14 (bow), 15 (edge), 16 (bell-shoulder), 17 (bell-tip), 18 (ping)

MidiIn min;
MidiMsg msg;
fun void setUpMidi() {
    for (0 => int i; i < 8; i++) {
        if (min.open(i) && min.name().find("IAC") > -1) {
            <<<"Opened IAC Driver on port", i>>>;
            return;
        }
    }
    <<<"ERROR: IAC Driver MIDI port not found.">>>;
    me.exit();
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

Gain master => dac.chan(2);
master => dac.chan(3);
0.085 => float defaultGain;

PulseOsc sin => ADSR e1 => BiQuad f => PRCRev reverb1 => master;
.99 => f.prad;
// set equal gain zeros
1 => f.eqzs;
// set filter gain
.04 => f.gain;
PulseOsc saw => ADSR e2 => PRCRev reverb2 => master;
SqrOsc sqr => ADSR e3 => PRCRev reverb3 => master;
defaultGain => sin.gain;
defaultGain => saw.gain;
defaultGain => sqr.gain;
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
            else if(msg.data3!=0 && msg.data2 == 3 && hitTom == 0) //floor tom (was tom1/2)
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
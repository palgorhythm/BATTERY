// ============================================================
// SHEPARD TON - pitch ramp piece with diving bass and soaring melody
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// STRUCTURE: Kick triggers bass notes that sweep DOWN to 0Hz.
//   Snare triggers melody notes that sweep UP. Floor tom advances
//   both sequences. Crash triggers random transpositions of bass.
// KICK: Bass note with downward pitch sweep
// SNARE: Melody note with upward pitch sweep
// FLOOR TOM: Advance both sequences
// CRASH: Random transposed solo from bass pitch (+0/+7/+12/+19)
// ============================================================

// Sensory Percussion MIDI map:
// Drums: kick=0, snare=1, rack tom=2, floor tom=3
// Hi-hat zones:  4 (bow), 5 (edge), 6 (bell-shoulder), 7 (bell-tip), 8 (ping)
// Crash zones:   9 (bow), 10 (edge), 11 (bell-shoulder), 12 (bell-tip), 13 (ping)
// Ride zones:    14 (bow), 15 (edge), 16 (bell-shoulder), 17 (bell-tip), 18 (ping)
0 => int KICK_NOTE;
1 => int SNARE_NOTE;
2 => int RACK_TOM_NOTE;
3 => int FLOOR_TOM_NOTE;
9 => int CRASH_MIN; 13 => int CRASH_MAX;

// ---- MIDI setup ----
MidiIn midiIn;
MidiMsg msg;
fun void setUpMidi() {
    for (0 => int i; i < 8; i++) {
        if (midiIn.open(i) && midiIn.name().find("IAC") > -1) {
            <<<"Opened IAC Driver on port", i>>>;
            return;
        }
    }
    <<<"ERROR: IAC Driver MIDI port not found.">>>;
    me.exit();
}
setUpMidi();

// ---- Audio routing: channels 3 & 4 ----
Gain master => dac.chan(2);
master => dac.chan(3);

// ---- Note data ----
[45, 38, 39, 40, 47, 50, 43, 36] @=> int bass[];
[60, 64, 67, 66, 76, 71, 64, 71] @=> int melody[];

0 => int bassIndex;
0 => int melodyIndex;

0.005 => float defaultGain;

// ---- Bass voice: triple sync oscillator chain ----
SawOsc bassOsc => SawOsc carrier => SawOsc overdrive => ADSR bassEnv => BiQuad bassFilter => PRCRev bassRev => master;
0.99 => bassFilter.prad;
1 => bassFilter.eqzs;
1 => overdrive.sync;
1 => carrier.sync;
1000 => bassOsc.gain;
500 => carrier.gain;
500 => overdrive.gain;
1 => carrier.freq;
bassEnv.set(10::ms, 10::ms, 0.5, 20::ms);
defaultGain * 0.0000000005 => bassFilter.gain;
0.03 => bassRev.mix;

// ---- Melody voice: pulse + sync overdrive ----
PulseOsc melodyOsc => SawOsc melodyOverdrive => ADSR melodyEnv => PRCRev melodyRev => master;
melodyEnv.set(10::ms, 10::ms, 0.5, 20::ms);
1 => melodyOverdrive.sync;
1000 => melodyOsc.gain;
defaultGain * 0.05 => melodyOverdrive.gain;
0.03 => melodyRev.mix;

// ---- Crash solo voice ----
SawOsc soloOsc => ADSR soloEnv => BiQuad soloFilter => PRCRev soloRev => master;
0.99 => soloFilter.prad;
1 => soloFilter.eqzs;
defaultGain * 15.0 => soloOsc.gain;
defaultGain * 15.0 => soloFilter.gain;
soloEnv.set(100::ms, 10::ms, 0.5, 20::ms);
0.05 => soloRev.mix;

// ---- State ----
int hitKick;    now => time kickTime;
int hitSnare;   now => time snareTime;
int hitTom;     now => time tomTime;

Shred @ bassShred;
Shred @ melodyShred;

// ---- Pitch ramp (the core effect of this piece) ----
fun void pitchRamp(string dir, float freq, Osc osc, ADSR env) {
    if (dir == "down") {
        if (freq <= 0) { env.keyOff(); return; }
        freq => osc.freq;
        env.keyOn();
        300::ms => now;
        while (freq > 0) {
            freq - 1.5 => freq;
            freq => osc.freq;
            50::ms => now;
        }
        env.keyOff();
    }
    else if (dir == "up") {
        500.0 => osc.gain;
        freq => osc.freq;
        Std.mtof(bass[bassIndex]) => float startFreq;
        env.keyOn();
        10::ms => now;
        while (freq < startFreq * 100.0) {
            (50.0) * (freq / (startFreq * 100.0)) => carrier.gain;
            10::ms => now;
            freq + 20.0 => freq;
            freq => osc.freq;
        }
        50::ms => now;
        env.keyOff();
    }
}

// ---- Kill a running shred safely ----
fun void killShred(Shred @ s) {
    if (s != null && s.id() != 0)
        Machine.remove(s.id());
}

// ---- Voice gate ----
fun void voiceGate() {
    while (true) {
        if (hitKick  && now > kickTime  + 200::ms)  0 => hitKick;
        if (hitSnare && now > snareTime + 100::ms)  0 => hitSnare;
        if (hitTom   && now > tomTime   + 1000::ms) 0 => hitTom;
        5::ms => now;
    }
}

// ---- Crash solo (sporked) ----
fun void trigCrashSolo(int midiNote) {
    Math.random2(1, 3) => int choice;
    int transp;
    if (choice == 1) 0 => transp;
    else if (choice == 2) 7 => transp;
    else if (choice == 3) 12 => transp;

    Std.mtof(bass[bassIndex] + (midiNote - CRASH_MIN) + transp) => soloOsc.freq;
    soloEnv.keyOn();
    20::ms => now;
    soloEnv.keyOff();
}

// ---- MIDI listener (single — pitchRamp is sporked so listener stays free) ----
fun void midiListener() {
    while (true) {
        midiIn => now;

        while (midiIn.recv(msg)) {
            if (msg.data3 == 0) continue;
            <<<"midi note", msg.data2, "velocity", msg.data3>>>;

            // KICK -> bass with downward pitch sweep
            if (msg.data2 == KICK_NOTE && !hitKick) {
                1 => hitKick;
                bassEnv.keyOff();
                killShred(bassShred);
                killShred(melodyShred);
                spork ~ pitchRamp("down", Std.mtof(bass[bassIndex]), bassOsc, bassEnv) @=> bassShred;
                now => kickTime;
            }
            // SNARE -> melody with upward pitch sweep
            else if (msg.data2 == SNARE_NOTE && !hitSnare) {
                1 => hitSnare;
                melodyEnv.keyOff();
                killShred(melodyShred);
                spork ~ pitchRamp("up", Std.mtof(melody[melodyIndex]), melodyOsc, melodyEnv) @=> melodyShred;
                now => snareTime;
            }
            // FLOOR TOM -> advance both sequences
            else if (msg.data2 == FLOOR_TOM_NOTE && !hitTom) {
                1 => hitTom;
                bassEnv.keyOff();
                melodyEnv.keyOff();
                killShred(bassShred);
                killShred(melodyShred);
                (melodyIndex + 1) % melody.size() => melodyIndex;
                (bassIndex + 1) % bass.size() => bassIndex;
            }
            // CRASH -> random transposed solo
            else if (msg.data2 >= CRASH_MIN && msg.data2 <= CRASH_MAX) {
                spork ~ trigCrashSolo(msg.data2);
            }
        }
    }
}

// ---- Main ----
spork ~ midiListener();
spork ~ voiceGate();

while (true) {
    1::second => now;
}

// ============================================================
// SAND - pure noise sculpture, no pitched content
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// STRUCTURE: Background filtered noise texture runs continuously.
//   All drum hits produce filtered white noise bursts with
//   velocity-scaled amplitude.
// KICK: Low-freq noise burst (50-500Hz)
// SNARE: Mid-freq noise burst (500-1000Hz)
// FLOOR TOM: Noise burst + toggles background texture off
// ============================================================

// --- MIDI Setup (IAC Driver) ---
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

// --- Audio Routing: channels 3 & 4 ---
Gain master => dac.chan(2);
master => dac.chan(3);
0.085 => master.gain;

// --- State ---
0 => int toggle;

// --- Kick Noise Channel (low freq) ---
Noise kickNoise => Gain kickGain => BiQuad kickFilter => master;
0 => kickGain.gain;
.99 => kickFilter.prad;
.06 => kickFilter.gain;
10 => kickFilter.eqzs;

// --- Snare Noise Channel (mid freq) ---
Noise snareNoise => Gain snareGain => BiQuad snareFilter => master;
0 => snareGain.gain;
.99 => snareFilter.prad;
.06 => snareFilter.gain;
10 => snareFilter.eqzs;

// --- Tom Noise Channel ---
Noise tomNoise => Gain tomGain => BiQuad tomFilter => master;
0 => tomGain.gain;
.99 => tomFilter.prad;
.6 => tomFilter.gain;
10 => tomFilter.eqzs;

// --- Background Texture ---
Noise bgNoise => Gain bgGain => BiQuad bgFilter => master;
.99 => bgFilter.prad;
.5 => bgFilter.gain;
1 => bgFilter.eqzs;
0.0 => float t;

// --- Launch ---
spork ~ handleMidiEvents();
20::ms => now;
spork ~ handleMidiEvents();
20::ms => now;
spork ~ handleMidiEvents();
20::ms => now;

// --- Background Noise Loop ---
while (true) {
    if (toggle != 1) {
        Std.rand2f(0.7, 1.0) => bgGain.gain;
    }
    Std.rand2f(100.0, 5000.0) => bgFilter.pfreq;
    30::ms => now;
    0 => bgGain.gain;
    60::ms => now;
}

// --- MIDI Handler ---
fun void handleMidiEvents() {
    while (true) {
        midiIn => now;

        while (midiIn.recv(msg)) {
            if (msg.data3 != 0 && msg.data2 == KICK_NOTE) {
                0 => kickGain.gain;
                1.5 * msg.data3 / 127.0 => snareGain.gain;
                50.0 * Std.rand2f(1.0, 10.0) => float freq;
                Std.rand2f(50.0, 100.0) => float dur_ms;
                freq => snareFilter.pfreq;
                dur_ms::ms => now;
                0 => snareGain.gain;

            } else if (msg.data3 != 0 && msg.data2 == SNARE_NOTE) {
                5.0 * msg.data3 / 127.0 => snareGain.gain;
                500.0 * Std.rand2f(1.0, 2.0) => float freq;
                Std.rand2f(50.0, 200.0) => float dur_ms;
                freq => snareFilter.pfreq;
                dur_ms::ms => now;
                0 => snareGain.gain;

            } else if (msg.data3 != 0 && msg.data2 == FLOOR_TOM_NOTE) {
                5.0 * msg.data3 / 127.0 => kickGain.gain;
                Std.rand2f(50.0, 500.0) => float freq;
                freq => kickFilter.pfreq;
                Std.rand2f(5000.0, 10000.0) => snareFilter.pfreq;
                Std.rand2f(200.0, 10000.0) => float dur_ms;
                dur_ms::ms => now;
                0 => tomGain.gain;
                0 => bgGain.gain;
                1 => toggle;
            }
        }
    }
}

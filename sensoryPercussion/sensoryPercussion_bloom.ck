// ============================================================
// BLOOM - 2D matrix step sequencer for bass and melody
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// STRUCTURE: 32 rows x 16 columns. Kick steps bass, snare steps
//   melody. Floor tom advances to next row (next section).
// KICK: Steps through bass note columns
// SNARE: Steps through melody note columns
// FLOOR TOM: Advances to next row, resets columns
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
0.085 => master.gain;

// ---- Sequencer dimensions ----
16 => int SEQ_WIDTH;
32 => int SEQ_HEIGHT;

// ---- Sequencer state ----
[0, 0] @=> int bassIdx[];
[0, 0] @=> int melIdx[];

int kickActive;
now + 1000::second => time kickTime;
int snareActive;
now + 1000::second => time snareTime;
int tomActive;
now + 1000::second => time tomTime;

// ---- Bass voice ----
PulseOsc bassPulse => ADSR bassEnv => BiQuad bassFilter => PRCRev bassRev => master;
0.97 => bassFilter.prad;
2 => bassFilter.eqzs;
0.05 => bassFilter.gain;
0.7 => bassPulse.gain;
0.001 => bassRev.mix;

// ---- Melody voice ----
SawOsc melSaw => ADSR melEnv => PRCRev melRev => master;
1.2 => melSaw.gain;
0.0 => melRev.mix;

// ============================================================
// NOTE MATRICES
// ============================================================

// ---- Bass matrix (32 rows x 16 columns) ----
int bass[SEQ_HEIGHT][SEQ_WIDTH];
36 => bass[0][0];
38 => bass[1][0];
33 => bass[2][0];
31 => bass[3][0];
40 => bass[4][0];
45 => bass[5][0];
43 => bass[6][0];
37 => bass[7][0];
36 => bass[8][0];
38 => bass[9][0];
33 => bass[10][0];
31 => bass[11][0];
45 => bass[12][0];
38 => bass[13][0];
44 => bass[14][0];
37 => bass[15][0];
42 => bass[16][0];
35 => bass[17][0];
38 => bass[18][0];
36 => bass[19][0];
39 => bass[20][0];
37 => bass[21][0];
33 => bass[22][0];
31 => bass[23][0];
36 => bass[24][0];
38 => bass[25][0];
33 => bass[26][0];
31 => bass[27][0];
40 => bass[28][0];
33 => bass[29][0];
31 => bass[30][0];
37 => bass[31][0];

// Fill each row: every column gets the same root note
for (0 => int i; i < SEQ_HEIGHT; i++) {
    for (0 => int j; j < SEQ_WIDTH; j++) {
        bass[i][0] => bass[i][j];
    }
}

// ---- Melody matrix (32 rows x 16 columns) ----
[[52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],
 [54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],
 [48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],
 [50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
 [50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
 [48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],
 [54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],
 [52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],
 [52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],
 [54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],
 [48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],
 [50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
 [50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
 [59,59,48,47,52,64,59,62,66,57,55,54,66,64,64,62],
 [60,60,60,60,66,66,66,66,60,60,60,60,66,66,66,66],
 [65,65,65,65,71,71,71,71,65,65,65,65,71,71,71,71],
 [70,68,66,68,63,73,61,71,70,68,66,68,63,73,61,71],
 [70,61,63,68,66,58,63,61,59,70,70,59,65,65,63,63],
 [73,73,71,73,66,66,64,66,68,68,61,61,66,66,64,64],
 [62,62,69,69,64,64,71,71,75,71,66,64,62,64,66,76],
 [74,84,79,74,69,67,67,77,74,72,74,74,67,67,65,67],
 [65,60,60,60,70,65,65,65,75,70,70,70,80,75,75,75],
 [71,64,61,68,61,59,71,64,61,68,61,59,71,64,61,59],
 [57,64,53,59,62,53,57,64,53,59,62,53,61,59,57,50],
 [52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],
 [54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],
 [48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],
 [50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
 [50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
 [48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],
 [52,52,52,52,59,59,59,59,64,64,64,64,71,71,71,71],
 [76,76,76,76,83,83,83,83,88,88,88,88,95,95,95,95]] @=> int melody[][];

// ============================================================
// Helper functions
// ============================================================

fun float getBassFreq() {
    return Std.mtof(bass[bassIdx[0]][bassIdx[1]]);
}

fun float getMelodyFreq() {
    return Std.mtof(melody[melIdx[0]][melIdx[1]]);
}

fun void updateEnvelopes() {
    // Rows 16-23: longer attack, more reverb
    if (bassIdx[0] > 15 && bassIdx[0] < 24) {
        bassEnv.set(10::ms, 30::ms, 0.5, 2500::ms);
        melEnv.set(30::ms, 30::ms, 0.5, 2500::ms);
        0.1 => bassRev.mix;
        0.1 => melRev.mix;
    }
    // Rows 30-31: sustained, heavy reverb
    else if (bassIdx[0] >= 30) {
        bassEnv.set(50::ms, 30::ms, 0.8, 2000::ms);
        melEnv.set(50::ms, 30::ms, 0.8, 2000::ms);
        0.1 => bassRev.mix;
        0.1 => melRev.mix;
    }
    // Default: tight and dry
    else {
        bassEnv.set(15::ms, 5::ms, 0.5, 800::ms);
        melEnv.set(15::ms, 6::ms, 0.5, 800::ms);
        0.001 => bassRev.mix;
        0.001 => melRev.mix;
    }
}

fun void trigBass() {
    getBassFreq() => bassPulse.freq;
    bassEnv.keyOn();
    10::ms => now;
    bassEnv.keyOff();
    (bassIdx[1] + 1) % SEQ_WIDTH => bassIdx[1];
}

fun void trigMelody() {
    getMelodyFreq() => melSaw.freq;
    melEnv.keyOn();
    10::ms => now;
    melEnv.keyOff();
    (melIdx[1] + 1) % SEQ_WIDTH => melIdx[1];
}

fun void advanceRow() {
    0 => bassIdx[1];
    0 => melIdx[1];
    (bassIdx[0] + 1 + SEQ_HEIGHT) % SEQ_HEIGHT => bassIdx[0];
    (melIdx[0] + 1 + SEQ_HEIGHT) % SEQ_HEIGHT => melIdx[0];

    getBassFreq() => bassPulse.freq;
    getMelodyFreq() => melSaw.freq;
    bassEnv.keyOn();
    melEnv.keyOn();
    10::ms => now;
    bassEnv.keyOff();
    melEnv.keyOff();

    1 => bassIdx[1];
    1 => melIdx[1];
}

// ============================================================
// Voice gate: auto-release hit flags after cooldown
// ============================================================
fun void voiceGate() {
    while (true) {
        if (tomActive == 1 && now > tomTime + 1000::ms) {
            0 => tomActive;
        }
        if (kickActive == 1 && now > kickTime + 10::ms) {
            0 => kickActive;
        }
        if (snareActive == 1 && now > snareTime + 100::ms) {
            0 => snareActive;
        }
        5::ms => now;
    }
}

// ============================================================
// MIDI listener
// ============================================================
fun void midiListener() {
    while (true) {
        midiIn => now;

        while (midiIn.recv(msg)) {
            if (msg.data3 == 0) continue;

            updateEnvelopes();

            // KICK (note 0) -> step bass sequence
            if (msg.data2 == KICK_NOTE && kickActive == 0) {
                1 => kickActive;
                now => kickTime;
                trigBass();
            }
            // SNARE (note 1) -> step melody sequence
            else if (msg.data2 == SNARE_NOTE && snareActive == 0) {
                1 => snareActive;
                now => snareTime;
                trigMelody();
            }
            // FLOOR TOM (note 3) -> advance to next row
            else if (msg.data2 == FLOOR_TOM_NOTE && tomActive == 0) {
                1 => tomActive;
                now => tomTime;
                1 => kickActive;
                now => kickTime;
                1 => snareActive;
                now => snareTime;
                advanceRow();
            }
        }
    }
}

// ============================================================
// Main
// ============================================================
spork ~ midiListener();
10::ms => now;
spork ~ midiListener();
10::ms => now;
spork ~ midiListener();
10::ms => now;
spork ~ voiceGate();

while (true) {
    1::second => now;
}

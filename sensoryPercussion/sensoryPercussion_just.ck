// ============================================================
// JUST - harmonic chord progression triggered by Sensory Percussion
// MIDI via IAC Driver | Audio output on channels 3 & 4
// ============================================================


// ----- CONFIG -----

0.085 => float GAIN;
6 => int CHORD_SIZE;

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

// chord root lists (MIDI note numbers)
[36, 34, 37, 33, 31, 29, 38, 40, 30, 41, 39, 37, 35, 31, 27, 35, 33, 35, 33, 29, 25, 33, 31] @=> int ROOT_LIST_A[];
[35, 33, 34, 27, 29, 30, 35, 33] @=> int ROOT_LIST_B[];


// ----- MIDI SETUP -----

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


// ----- BUILD CHORD TABLES -----

float chordsA[ROOT_LIST_A.size()][CHORD_SIZE];
float chordsB[ROOT_LIST_B.size()][CHORD_SIZE];

for (0 => int i; i < chordsA.size(); i++)
    harmonicChord(ROOT_LIST_A[i], CHORD_SIZE, 6.0, 3.0) @=> chordsA[i];

for (0 => int i; i < chordsB.size(); i++)
    harmonicChord(ROOT_LIST_B[i], CHORD_SIZE, 4.0, 3.0) @=> chordsB[i];


// ----- AUDIO ROUTING (channels 3 & 4) -----

Gain master => dac.chan(2);
master => dac.chan(3);

// shaker
Shakers shake => master;
GAIN * 5.0 => shake.gain;

// solo voice
SawOsc soloOsc => ADSR soloEnv => BiQuad soloFilt => PRCRev soloRev => master;
soloEnv.set(5::ms, 5::ms, 0.5, 20::ms);
GAIN * 0.4 => soloOsc.gain;
0.01 => soloRev.mix;
0.99 => soloFilt.prad;
5 => soloFilt.eqzs;
GAIN * 15.0 => soloFilt.gain;

// chord voices
PulseOsc chordOsc[CHORD_SIZE];
ADSR chordEnv[CHORD_SIZE];
PRCRev chordRev[CHORD_SIZE];

for (0 => int i; i < CHORD_SIZE; i++) {
    chordOsc[i] => chordEnv[i] => chordRev[i] => master;
    GAIN * (1.0 - (i / 25.0)) => chordOsc[i].gain;
    chordEnv[i].set(10::ms, 100::ms, 0.9, 1200::ms);
    0.01 => chordRev[i].mix;
}


// ----- STATE -----

0 => int bSection;
0 => int chordIndexA;
0 => int chordIndexB;
0 => int globalChordIndex;

int hitKick;   now => time kickTime;
int hitSnare;  now => time snareTime;
int hitTom;    now => time tomTime;


// ----- SHRED: voice gate (auto note-off after timeout) -----

fun void voiceGate() {
    while (true) {
        if (hitTom   && now > tomTime   + 300::ms)  0 => hitTom;
        if (hitKick  && now > kickTime  + 1000::ms) 0 => hitKick;
        if (hitSnare && now > snareTime + 100::ms)  0 => hitSnare;
        5::ms => now;
    }
}


// ----- SHRED: play A-section chord and advance -----

fun void playChordA() {
    for (0 => int i; i < CHORD_SIZE; i++)
        chordEnv[i].keyOff();

    for (0 => int i; i < CHORD_SIZE; i++) {
        chordsA[chordIndexA][i] => chordOsc[i].freq;
        chordEnv[i].keyOn();
    }

    if (chordIndexA == chordsA.size() - 1)
        globalChordIndex + 1 => globalChordIndex;
    (chordIndexA + 1) % chordsA.size() => chordIndexA;

    100::ms => now;
    for (0 => int i; i < CHORD_SIZE; i++)
        chordEnv[i].keyOff();
    100::ms => now;
}


// ----- SHRED: play B-section chord and advance -----

fun void playChordB() {
    for (0 => int i; i < CHORD_SIZE; i++)
        chordEnv[i].keyOff();

    for (0 => int i; i < CHORD_SIZE; i++) {
        chordEnv[i].set(70::ms, 30::ms, 0.9, 4000::ms);
        0.2 => chordRev[i].mix;
        chordsB[chordIndexB][i] => chordOsc[i].freq;
        chordEnv[i].keyOn();
    }

    if (chordIndexB == chordsB.size() - 1)
        globalChordIndex + 1 => globalChordIndex;
    (chordIndexB + 1) % chordsB.size() => chordIndexB;

    100::ms => now;
    for (0 => int i; i < CHORD_SIZE; i++)
        chordEnv[i].keyOff();
    100::ms => now;
}


// ----- SHRED: solo voice triggered by non-drum hits -----

fun void playSolo(int midiNote) {
    soloEnv.keyOff();
    midiNote % CHORD_SIZE => int idx;

    // shaker texture
    Math.random2(0, 22) => shake.which;
    50.0 => shake.freq;
    Math.random2f(0, 128) => shake.objects;
    shake.noteOn(3.0);

    // pick freq from whichever section we're in
    if (bSection == 0)
        chordsA[(chordIndexA + chordsA.size() - 1) % chordsA.size()][idx] * 2.0 => soloOsc.freq;
    else
        chordsB[(chordIndexB + chordsB.size() - 1) % chordsB.size()][idx] * 2.0 => soloOsc.freq;

    soloEnv.keyOn();
    20::ms => now;
    soloEnv.keyOff();
}


// ----- SHRED: MIDI listener (3 shreds, each blocks during chord play) -----

fun void midiListener() {
    while (true) {
        midiIn => now;

        while (midiIn.recv(msg)) {
            if (msg.data3 == 0) continue; // ignore note-off
            <<<"midi note", msg.data2, "velocity", msg.data3>>>;

            // kick -> trigger chord progression
            if (msg.data2 == KICK_NOTE && !hitKick) {
                1 => hitKick;

                ((globalChordIndex % 3) + 1) * 750 => int decay;
                for (0 => int i; i < 5; i++) {
                    chordEnv[i].set(20::ms, 10::ms, 0.9, decay::ms);
                    0.1 => chordRev[i].mix;
                }

                if (bSection == 0) playChordA();
                else               playChordB();

                0 => hitKick;
            }
            // crash cymbal -> solo
            else if (msg.data2 >= CRASH_MIN && msg.data2 <= CRASH_MAX) {
                playSolo(msg.data2);
            }
        }
    }
}


// ----- MAIN: spork shreds and run section tracker -----

spork ~ midiListener();
10::ms => now;
spork ~ midiListener();
10::ms => now;
spork ~ midiListener();
10::ms => now;
spork ~ voiceGate();

while (true) {
    0.2::second => now;
    ((globalChordIndex - 2) % 3 == 0) => bSection;
}


// ============================================================
// UTILITY FUNCTIONS
// ============================================================

fun float[] harmonicChord(int rootMIDI, int harmonics, float a, float b) {
    float result[harmonics];
    Std.mtof(rootMIDI) => float rootFreq;
    rootFreq => result[0];
    for (0 => int i; i < harmonics - 1; i++)
        (rootFreq * (a * i + b)) / 2.0 => result[i + 1];
    return result;
}

fun int[] notes2nums(string notes[], int numcopies) {
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string noteNames[];
    string numToNote[127];
    int noteToNum[127];

    for (0 => int i; i < 127; i++) {
        i % 12 => int mod;
        -2 + i / 12 => int octave;
        noteNames[mod] + octave => numToNote[i];
    }
    for (0 => int i; i < 127; i++)
        i => noteToNum[numToNote[i]];

    int numbers[notes.size() * numcopies];
    for (0 => int i; i < numbers.size(); i++)
        noteToNum[notes[i % notes.size()]] => numbers[i];
    return numbers;
}

fun int[] changeOctave(int noteNums[], string dir, int x) {
    int result[noteNums.size()];
    if (dir == "up")
        for (0 => int i; i < noteNums.size(); i++)
            noteNums[i] + 12 * x => result[i];
    else if (dir == "down")
        for (0 => int i; i < noteNums.size(); i++)
            noteNums[i] - 12 * x => result[i];
    else
        <<<"ERROR: changeOctave expects 'up' or 'down'">>>;
    return result;
}

fun int[] transpose(int noteNums[], string dir, int halfSteps) {
    int result[noteNums.size()];
    if (dir == "up")
        for (0 => int i; i < noteNums.size(); i++)
            noteNums[i] + halfSteps => result[i];
    else if (dir == "down")
        for (0 => int i; i < noteNums.size(); i++)
            noteNums[i] - halfSteps => result[i];
    else
        <<<"ERROR: transpose expects 'up' or 'down'">>>;
    return result;
}

// ============================================================
// EVIDENCE - generative random chord piece
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// STRUCTURE: Each kick generates a random chord from quality
//   presets (Maj9, Maj69, Maj9#11, sus). Has a melody mode toggle.
// KICK: Generate and play random 5-voice chord
// SNARE: Solo - random chord tone, 1-2 octaves up
// FLOOR TOM: Play root note, 0-1 octaves up
// CRASH: Chord tone solo + shaker texture. Region 9 toggles melody mode.
// ============================================================


// ----- CONFIG -----

0.02 => float GAIN;
5 => int NUM_VOICES;

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


// ----- CHORD DEFINITIONS -----
// 56 chords total, 5 voices each
// Named note strings converted to MIDI numbers at startup.
// Sections: A (14 chords), A repeat, climax (8 chords), A repeat

[
    // --- Section A (14 chords) ---
    ["D#0","G2", "A#2", "C3", "D3"],
    ["G0","A2","A#2","C3","F3"],
    ["C1", "G2","A#2","C#3","F#3"],
    ["F1","G2","G#2","A#2","D#3"],
    ["D1","E2","F2","G2","C3"],
    ["A#1","F2","G#2","A#2","E3"],
    ["A0","F#2","G2","B2","C#3"],
    ["G#1","F#2","A#2","B2","F#3"],
    ["F#1","G#2","A#2","B2","D#3"],
    ["C#2","G2","A#2","B2","F3"],
    ["C1","G2","A#2","C3","D#3"],
    ["C2","A2","A#2","C3","D#3"],
    ["F1","A#2","D#3","F3","A#3"],
    ["F0","A2","D#3","F#3","B3"],

    // --- Section A repeat ---
    ["D#0","G2", "A#2", "C3", "D3"],
    ["G0","A2","A#2","C3","F3"],
    ["C1", "G2","A#2","C#3","F#3"],
    ["F1","G2","G#2","A#2","D#3"],
    ["D1","E2","F2","G2","C3"],
    ["A#1","F2","G#2","A#2","E3"],
    ["A0","F#2","G2","B2","C#3"],
    ["G#1","F#2","A#2","B2","F#3"],
    ["F#1","G#2","A#2","B2","D#3"],
    ["C#2","G2","A#2","B2","F3"],
    ["C1","G2","A#2","C3","D#3"],
    ["C2","A2","A#2","C3","D#3"],
    ["F1","A#2","D#3","F3","A#3"],
    ["F0","A2","D#3","F#3","B3"],

    // --- Climax section (8 chords) ---
    ["A#1","C3","C#3","D#3","G#3"],
    ["D#1", "C3","C#3","F3","A3"],
    ["G#0","C3","D3","F#3","A#3"],
    ["C#0","D#3","F3","G3","B3"],
    ["D2","E3","F3","G3","C4"],
    ["G1","F3","A3","B3","C#4"],
    ["F1","D#3","G3","A3","D4"],
    ["A#0","D3","G#3","A#3","E4"],

    // --- Section A repeat ---
    ["D#0","G2", "A#2", "C3", "D3"],
    ["G0","A2","A#2","C3","F3"],
    ["C1", "G2","A#2","C#3","F#3"],
    ["F1","G2","G#2","A#2","D#3"],
    ["D1","E2","F2","G2","C3"],
    ["A#1","F2","G#2","A#2","E3"],
    ["A0","F#2","G2","B2","C#3"],
    ["G#1","F#2","A#2","B2","F#3"],
    ["F#1","G#2","A#2","B2","D#3"],
    ["C#2","G2","A#2","B2","F3"],
    ["C1","G2","A#2","C3","D#3"],
    ["C2","A2","A#2","C3","D#3"],
    ["F1","A#2","D#3","F3","A#3"],
    ["F0","A2","D#3","F#3","B3"]
] @=> string chordStrings[][];

int chords[chordStrings.size()][NUM_VOICES];
chordSequenceToMidi(chordStrings) @=> chords;

<<<"Translated", chords.size(), "chords into MIDI numbers.">>>;


// ----- STATE -----

0 => int chordIndex;
0 => int soloOctave;
0 => int playMelody;


// ----- AUDIO ROUTING (channels 3 & 4) -----

Gain master => dac.chan(2);
master => dac.chan(3);

// shaker
Shakers shake => master;
GAIN * 5.0 => shake.gain;

// chord voices
SawOsc chordOsc[NUM_VOICES];
ADSR chordEnv[NUM_VOICES];
PRCRev chordRev[NUM_VOICES];
BiQuad chordFilt[NUM_VOICES];

for (0 => int i; i < NUM_VOICES; i++) {
    chordOsc[i] => chordEnv[i] => chordRev[i] => master;
    chordEnv[i].set(20::ms, 10::ms, 0.9, 500::ms);
    0.01 => chordRev[i].mix;
    0.99 => chordFilt[i].prad;
    1 => chordFilt[i].eqzs;
    GAIN * 12.0 * (1.0 - (i / 10.0)) => chordOsc[i].gain;
    GAIN * (7.0 - i) => chordFilt[i].gain;
}

// solo voice
PulseOsc soloOsc => ADSR soloEnv => BiQuad soloFilt => PRCRev soloRev => master;
soloEnv.set(5::ms, 5::ms, 0.9, 30::ms);
0.95 => soloFilt.prad;
1 => soloFilt.eqzs;
0.01 => soloRev.mix;
GAIN * 8.0 => soloOsc.gain;
GAIN * 8.0 => soloFilt.gain;

<<<"Audio routing complete.">>>;


// ----- FUNCTIONS -----

fun int getSustain(int idx) {
    if (idx <= 13)      return 400;
    else if (idx <= 27) return 800;
    else if (idx <= 35) return 2000;
    else                return 4000;
}

fun int previousChordIndex() {
    return ((chordIndex + chords.size()) - 1) % chords.size();
}

fun void playChord() {
    getSustain(chordIndex) => int sustain;

    for (0 => int i; i < NUM_VOICES; i++) {
        chordEnv[i].set(10::ms, 40::ms, 0.9, sustain::ms);
        chordEnv[i].keyOff();
        Std.mtof(chords[chordIndex % chords.size()][i]) => chordOsc[i].freq;
        chordEnv[i].keyOn();
    }

    10::ms => now;

    for (0 => int i; i < NUM_VOICES; i++)
        chordEnv[i].keyOff();

    (chordIndex + 1) % chords.size() => chordIndex;
}

fun void playSoloNote(int voiceIndex) {
    previousChordIndex() => int prevIdx;
    chords[prevIdx][voiceIndex % NUM_VOICES] => int note;

    // avoid super-low bass note on voice 0
    if (voiceIndex == 0)
        note + 12 => note;

    note + (soloOctave * 12) => int midiNote;
    Std.mtof(midiNote) => soloOsc.freq;
    soloEnv.keyOff();
    soloEnv.keyOn();
    10::ms => now;
    soloEnv.keyOff();
}

fun void playRootNote() {
    previousChordIndex() => int prevIdx;
    chords[prevIdx][0] => int root;
    root + (Math.random2(0, 1) * 12) => int midiNote;
    Std.mtof(midiNote) => soloOsc.freq;
    soloEnv.keyOff();
    soloEnv.keyOn();
    10::ms => now;
    soloEnv.keyOff();
}

fun void playCrashSolo(int region) {
    region - CRASH_MIN => int idx;

    // shaker texture
    Math.random2(0, 22) => shake.which;
    50.0 => shake.freq;
    Math.random2f(0, 128) => shake.objects;
    shake.noteOn(3.0);

    // chord tone solo
    previousChordIndex() => int prevIdx;
    chords[prevIdx][idx % NUM_VOICES] => int note;

    // pitch up to avoid bass
    if (idx == 0)
        note + 12 => note;

    note + (soloOctave * 12) => int midiNote;
    Std.mtof(midiNote) => soloOsc.freq;
    soloEnv.keyOff();
    soloEnv.keyOn();
    10::ms => now;
    soloEnv.keyOff();
}


// ----- MIDI EVENT HANDLER -----

fun void handleMidiEvent(int midiNote) {
    if (midiNote == KICK_NOTE) {
        playChord();
    }
    else if (midiNote == FLOOR_TOM_NOTE) {
        playRootNote();
    }
    else if (midiNote >= CRASH_MIN && midiNote <= CRASH_MAX) {
        if (midiNote == CRASH_MAX) {
            // region 9 toggles melody mode
            !playMelody => playMelody;
            <<<"Melody mode:", playMelody>>>;
        } else {
            playCrashSolo(midiNote);
        }
    }
}


// ----- MIDI LISTENER -----

fun void midiListener() {
    while (true) {
        midiIn => now;
        while (midiIn.recv(msg)) {
            if (msg.data3 < 20) continue; // filter crosstalk
            <<<"midi note", msg.data2, "velocity", msg.data3>>>;
            handleMidiEvent(msg.data2);
        }
    }
}


// ----- MAIN -----

spork ~ midiListener();
10::ms => now;
spork ~ midiListener();
10::ms => now;
spork ~ midiListener();

<<<"EVIDENCE ready.">>>;

while (true)
    1::second => now;


// ============================================================
// UTILITY FUNCTIONS
// ============================================================

fun int[][] chordSequenceToMidi(string chordSeq[][]) {
    int result[chordSeq.size()][chordSeq[0].size()];
    for (0 => int i; i < chordSeq.size(); i++)
        chordToMidi(chordSeq[i]) @=> result[i];
    return result;
}

fun int[] chordToMidi(string chord[]) {
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string noteNames[];
    string numToNote[127];
    int noteToNum[127];

    for (0 => int i; i < 127; i++) {
        i % 12 => int mod;
        -2 + (i / 12) => int octave;
        noteNames[mod] + octave => numToNote[i];
    }
    for (0 => int i; i < 127; i++)
        i => noteToNum[numToNote[i]];

    int numbers[chord.size()];
    for (0 => int i; i < chord.size(); i++)
        noteToNum[chord[i]] => numbers[i];
    return numbers;
}

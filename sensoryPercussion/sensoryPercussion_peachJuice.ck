// ============================================================
// PEACH JUICE - linear through-composed piece with parallel melodies
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// STRUCTURE: Linear, non-looping. 4 sections: A (11 notes x4),
//   B (9 notes x4), transition, C (8 notes). Counter never wraps.
// KICK: Advance bass + melody sequences simultaneously
// FLOOR TOM: Play countermelody overlay (small melodic cells)
// DYNAMICS: Short release early, long sustain + reverb later
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
0.5 => master.gain;

// --- Note Data ---
[29, 29, 43, 38, 29, 29, 43, 38, 29, 29, 43, 38, 32, 48, 43, 41] @=> int bass[];

chordSequenceMidiNotesToNumbers([
  ["F#0","C#3", "A#3", "D#4", "F4", "G#4"],
  ["A0", "E3", "A3", "C#4", "D4", "F#4"],
  ["D#0", "A#2", "G3", "A3", "C3", "F4"],
  ["G#0", "D#3", "G3", "C4", "D4", "F4"],
  ["G0","D#3","F3","A#3","B3","D#3"],
  ["C1","G2","A#3","D4","D#4","F4"],
  ["C#1","G#2","C4","D#4","F4","G4"],
  ["B1","E2","G#3","A#3","C#4","D#4"],
  ["C0","E2","G#3","C3","D#4","A#4"]
]) @=> int chords[][];

chordMidiNotesToNumbers(["A3","A3","D4","E4","B3","E3","A3","C3","E4","A3","A3","D4","E4","G4","A4","B4","E5"]) @=> int snare[];

// --- Oscillators ---
PulseOsc bassOsc => ADSR bassEnv => BiQuad bassFilter => PRCRev bassReverb => master;
bassEnv.set(10::ms, 10::ms, 0.5, 40::ms);
.99 => bassFilter.prad;
1 => bassFilter.eqzs;
.1 => bassFilter.gain;
0.15 => bassOsc.gain;
.03 => bassReverb.mix;

PulseOsc melodyOsc => ADSR melodyEnv => PRCRev melodyReverb => master;
melodyEnv.set(10::ms, 20::ms, .5, 1000::ms);
0.3 => melodyOsc.gain;
.2 => melodyReverb.mix;

SawOsc chordOsc[6];
ADSR chordEnv[6];
PRCRev chordRev[6];

for (0 => int i; i < 6; i++) {
    chordOsc[i] => chordEnv[i] => chordRev[i] => master;
    0.3 * (1.0 - (i / 25.0)) => chordOsc[i].gain;
    chordEnv[i].set(10::ms, 6000::ms, 0.5, 6000::ms);
    0.03 => chordRev[i].mix;
}

// --- State ---
0 => int bassIndex;
0 => int snareIndex;
0 => int bSection;
0 => int chordIndex;
1 => int chordGo;
0 => int songSectionIndex;
0 => int interDiv;
now => time bassTime;
10::ms => dur interval;
interval / 4 => dur hitInter;

// --- Launch ---
spork ~ handleMidiEvents();
spork ~ handleMidiEvents();
spork ~ handleMidiEvents();

while (true) {
    1::second => now;
}

// --- MIDI Handler ---
fun void handleMidiEvents() {
    while (true) {
        midiIn => now;
        while (midiIn.recv(msg)) {
            if (msg.data3 != 0) {
                <<<"midi note", msg.data2, "velocity", msg.data3>>>;
            }

            if (msg.data3 != 0 && msg.data2 == KICK_NOTE) {
                bassEnv.keyOff();
                now - bassTime => interval;
                interval / 4.0 => hitInter;
                now => bassTime;

                if (bSection == 0) {
                    if (bassIndex == bass.size() - 1) {
                        6 => interDiv;
                    } else {
                        4 => interDiv;
                    }

                    for (0 => int i; i < interDiv; i++) {
                        Std.mtof(bass[bassIndex]) => bassOsc.freq;
                        bassEnv.keyOn();
                        hitInter / (interDiv * (1.0 / 2.0)) => now;
                        bassEnv.keyOff();
                        hitInter / (interDiv * (1.0 / 2.0)) => now;
                    }
                } else if (chordGo == 1) {
                    for (0 => int i; i < chords[chordIndex].size(); i++) {
                        chordEnv[i].keyOff();
                        Std.mtof(chords[chordIndex][i]) => chordOsc[i].freq;
                        chordEnv[i].keyOn();
                    }

                    10::ms => now;

                    for (0 => int i; i < chords[chordIndex].size(); i++) {
                        chordEnv[i].keyOff();
                    }

                    if (chordIndex == chords.size() - 1) {
                        songSectionIndex + 1 => songSectionIndex;
                    }
                    (chordIndex + 1) % chords.size() => chordIndex;
                    0 => chordGo;
                }

                if (bSection == 0) {
                    (bassIndex + 1) % bass.size() => bassIndex;
                    0 => chordIndex;
                } else {
                    0 => bassIndex;
                }

            } else if (msg.data3 != 0 && msg.data2 == SNARE_NOTE && bSection == 0) {
                Std.mtof(snare[snareIndex]) => melodyOsc.freq;
                melodyEnv.keyOn();
                10::ms => now;
                melodyEnv.keyOff();
                (snareIndex + 1) % snare.size() => snareIndex;

            } else if (msg.data3 != 0 && msg.data2 == FLOOR_TOM_NOTE) {
                if (bSection == 0) {
                    bassEnv.keyOff();
                    1 => bSection;
                    1 => chordGo;
                    0 => bassIndex;
                } else if (songSectionIndex == 1 || songSectionIndex == 4) {
                    0 => bSection;
                    songSectionIndex + 1 => songSectionIndex;
                    for (0 => int i; i < chords[chordIndex].size(); i++) {
                        chordEnv[i].keyOff();
                    }
                    0 => bassIndex;
                } else {
                    1 => chordGo;
                }
            }
        }
    }
}

// --- Utility Functions ---

fun int[][] chordSequenceMidiNotesToNumbers(string chordSequence[][]) {
    int chordSequenceNumbers[chordSequence.size()][chordSequence[0].size()];
    for (0 => int i; i < chordSequence.size(); i++) {
        chordMidiNotesToNumbers(chordSequence[i]) @=> chordSequenceNumbers[i];
    }
    return chordSequenceNumbers;
}

fun int[] chordMidiNotesToNumbers(string chord[]) {
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string noteNames[];
    string numToNote[127];
    int noteToNum[127];

    for (0 => int i; i < 127; i++) {
        i % 12 => int mod;
        -2 + (i / 12) => int counter;
        noteNames[mod] + counter => numToNote[i];
    }

    for (0 => int i; i < 127; i++) {
        i => noteToNum[numToNote[i]];
    }

    int numbers[chord.size()];
    for (0 => int i; i < chord.size(); i++) {
        i % chord.size() => int index;
        noteToNum[chord[index]] => numbers[i];
    }
    return numbers;
}

// ============================================================
// FOR YOU - autonomous ostinato with drum-triggered melody/bass
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// STRUCTURE: Auto-running ostinato (C5,G5,B5,F#5) cycles at 0.5s.
//   Drummer plays melody and bass on top. Built-in fade-out over
//   ~5 minutes (600 quarter notes).
// KICK: Advance bass sequence
// FLOOR TOM: Advance melody sequence
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
0.12 => master.gain;

// --- State ---
0 => int bassCounter;
0 => int lineCounter;
0 => int hitTom;
now + 1000::second => time tomTime;
0 => int hitBass;
now + 1000::second => time bassTime;
0.0 => float noteLen;

// --- Note Data ---
notes2nums(["G3", "F3", "A3", "D3", "D#3", "A#3", "F3", "A#2", "A#2", "C#3", "D#3"], 4) @=> int melodyA[];
notes2nums(["D#2", "C#2", "F2", "A#1", "B1", "F#2", "C#2", "F#1", "F#1", "A#1", "B1"], 4) @=> int bassA[];
notes2nums(["G3", "A3", "B3", "F#3", "E3", "F#4", "E4", "F#5", "E5"], 4) @=> int melodyB[];
notes2nums(["D#1", "F1", "G1", "D1", "C1", "D1", "C1", "D1", "C1"], 4) @=> int bassB[];
notes2nums(["G3"], 1) @=> int transitionMelody[];
notes2nums(["D#2"], 1) @=> int transitionBass[];
notes2nums(["F#3", "E3", "F#3", "E3", "G3", "G3", "G3", "G3"], 1) @=> int melodyC[];
notes2nums(["D2", "C2", "D2", "C2", "E1", "D#1", "C1", "G#0"], 1) @=> int bassC[];
notes2nums(["F4", "G4", "C4"], 1) @=> int lineA1[];
notes2nums(["C#4", "G#4", "A#4"], 1) @=> int lineA2[];
notes2nums(["G4", "A4", "D5"], 1) @=> int lineB1[];
notes2nums(["A4", "B4", "E5"], 1) @=> int lineB2[];

changeOctave(concatArrays([melodyA, melodyB, transitionMelody, melodyC]), "down", 0) @=> int melody[];
changeOctave(concatArrays([bassA, bassB, transitionBass, bassC]), "down", 0) @=> int bass[];
changeOctave(concatArrays([lineA1, lineA2, lineA1, lineA2, lineB1, lineB2, lineB1, lineB2]), "down", 1) @=> int lines[];

// --- Oscillators ---
SqrOsc bassOsc => ADSR bassEnv => PRCRev bassReverb => master;
SawOsc melodyOsc => ADSR melodyEnv => PRCRev melodyReverb => master;
SqrOsc lineOsc => ADSR lineEnv => PRCRev lineReverb => master;

lineEnv.set(5::ms, 15::ms, .7, 1000::ms);
.01 => lineReverb.mix;
1.05 => bassOsc.gain;
1 => melodyOsc.gain;
1 => lineOsc.gain;

// --- Launch ---
spork ~ handleMidiEvents();
20::ms => now;
spork ~ handleMidiEvents();
20::ms => now;
spork ~ handleMidiEvents();
20::ms => now;
spork ~ voiceGate();

while (true) {
    1::second => now;
}

// --- Voice Gate (debounce) ---
fun void voiceGate() {
    while (true) {
        if (hitTom == 1 && (now > tomTime + 200::ms)) {
            0 => hitTom;
        }
        if (hitBass == 1 && (now > bassTime + 100::ms)) {
            0 => hitBass;
        }
        5::ms => now;
    }
}

// --- MIDI Handler ---
fun void handleMidiEvents() {
    while (true) {
        midiIn => now;

        while (midiIn.recv(msg)) {
            if (msg.data3 != 0 && msg.data2 == KICK_NOTE && hitBass == 0) {
                Std.mtof(bass[bassCounter]) => bassOsc.freq;
                Std.mtof(melody[bassCounter]) => melodyOsc.freq;

                if (bassCounter > 43 && bassCounter < 80) {
                    bassEnv.set(10::ms, 30::ms, 1.5, 5000::ms);
                    melodyEnv.set(10::ms, 30::ms, 1.5, 5000::ms);
                    .1 => bassReverb.mix;
                    .1 => melodyReverb.mix;
                    (((bassCounter + 11) / 11) * 10) => noteLen;
                } else if (bassCounter > 79) {
                    bassEnv.set(5::ms, 30::ms, .9, 5000::ms);
                    melodyEnv.set(5::ms, 30::ms, .9, 5000::ms);
                    .1 => bassReverb.mix;
                    .1 => melodyReverb.mix;
                    (((bassCounter + 11) / 11) * 10) => noteLen;
                } else {
                    (((bassCounter + 11) / 11) * 750) => float releaseMs;
                    bassEnv.set(10::ms, 30::ms, .9, releaseMs::ms);
                    melodyEnv.set(10::ms, 30::ms, .9, releaseMs::ms);
                    0.05 => bassReverb.mix;
                    0.05 => melodyReverb.mix;
                    (((bassCounter + 11) / 11) * 10) => noteLen;
                }

                1 => hitBass;
                now => bassTime;

                bassEnv.keyOn();
                melodyEnv.keyOn();
                noteLen::ms => now;
                bassEnv.keyOff();
                melodyEnv.keyOff();
                bassCounter++;

            } else if (msg.data3 != 0 && msg.data2 == FLOOR_TOM_NOTE && hitTom == 0) {
                if ((bassCounter % 11) > 3 && bassCounter < 44) {
                    Std.mtof(lineA2[lineCounter % 3]) => lineOsc.freq;
                } else if ((bassCounter % 11) < 4 && bassCounter < 44) {
                    Std.mtof(lineA1[lineCounter % 3]) => lineOsc.freq;
                } else if ((bassCounter % 9) > 3 && bassCounter > 43 && bassCounter < 80) {
                    Std.mtof(lineB2[lineCounter % 3]) => lineOsc.freq;
                } else {
                    Std.mtof(lineB1[lineCounter % 3]) => lineOsc.freq;
                }

                lineEnv.keyOn();
                10::ms => now;
                lineEnv.keyOff();
                1 => hitTom;
                now => tomTime;

                lineCounter++;
            }
        }
    }
}

// --- Utility Functions ---

fun int[] notes2nums(string notes[], int numcopies) {
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string A[];
    string numTOnote[127];
    int noteTOnum[127];

    for (0 => int i; i < 127; i++) {
        i % 12 => int mod;
        -2 + i / 12 => int counter;
        A[mod] + counter => numTOnote[i];
    }

    for (0 => int i; i < 127; i++) {
        i => noteTOnum[numTOnote[i]];
    }

    int numbers[notes.size() * numcopies];
    for (0 => int i; i < notes.size() * numcopies; i++) {
        i % notes.size() => int index;
        noteTOnum[notes[index]] => numbers[i];
    }
    return numbers;
}

fun int[] changeOctave(int noteNums[], string choice, int x) {
    int result[noteNums.size()];

    if (choice == "up") {
        for (0 => int i; i < noteNums.size(); i++) {
            noteNums[i] + 12 * x => result[i];
        }
    } else if (choice == "down") {
        for (0 => int i; i < noteNums.size(); i++) {
            noteNums[i] - 12 * x => result[i];
        }
    } else {
        <<<"ERROR">>>;
    }
    return result;
}

fun int[] concatArrays(int X[][]) {
    int len;

    for (0 => int i; i < X.size(); i++) {
        len + X[i].size() => len;
    }

    int result[len];
    0 => int counter;

    for (0 => int i; i < X.size(); i++) {
        for (0 => int j; j < X[i].size(); j++) {
            X[i][j] => result[counter];
            counter++;
        }
    }

    return result;
}

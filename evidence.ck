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

[
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

  ["A#1","C3","C#3","D#3","G#3"], 
  ["D#1", "C3","C#3","F3","A3"], 
  ["G#0","C3","D3","F#3","A#3"], 
  ["C#0","D#3","F3","G3","B3"],
  ["D2","E3","F3","G3","C4"],
  ["G1","F3","A3","B3","C#4"],
  ["F1","D#3","G3","A3","D4"],
  ["A#0","D3","G#3","A#3","E4"],

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

int numVoices;
chordStrings[0].size() => numVoices;
int chords[chordStrings.size()][numVoices];
chordSequenceMidiNotesToNumbers(chordStrings) @=> chords;

<<<"Translated MIDI chords into note numbers.">>>;

0 => int chordIndex;
0 => int soloOctave;

SawOsc chordOscs[numVoices];
ADSR chordAdsr[numVoices];
PRCRev chordReverb[numVoices];
BiQuad chordFilter[numVoices];

0.03 => float defaultGain;

for(0 => int i; i < numVoices; i++) {   
  chordOscs[i] => chordAdsr[i] => chordReverb[i] => dac;
  chordAdsr[i].set(20::ms, 10::ms, .9, 500::ms);
  0.01 => chordReverb[i].mix;
  .99 => chordFilter[i].prad; 
  1 => chordFilter[i].eqzs;
  defaultGain * 12.0 * (1.0 - (i / 10.0)) => chordOscs[i].gain;
  defaultGain * (7.0 - i) => chordFilter[i].gain;
}

PulseOsc soloOsc;
ADSR soloAdsr;
BiQuad soloFilter;
PRCRev soloReverb;
soloOsc => soloAdsr => soloFilter => soloReverb => dac;
soloAdsr.set(5::ms, 5::ms, .9, 30::ms);
.95 => soloFilter.prad; 
1 => soloFilter.eqzs;
0.01 => soloReverb.mix;
defaultGain * 8.0 => soloOsc.gain;
defaultGain * 8.0 => soloFilter.gain;

<<<"Created Oscillators!">>>;

3 => int numHandlers;

for(0 => int i; i < numHandlers; i++) {
  spork ~ main();
}

fun void main() {
  while(true) {
    min => now;
    while(min.recv(msg) && msg.data3 != 0) {
      <<< "Channel:", msg.data1, "MIDI Note #:", msg.data2, "Velocity:", msg.data3 >>>; 
      handleMidiEvent(msg.data2);
    }
  }    
}

while(true) {
  1::second => now;
}

<<<"Started!">>>;

fun void handleMidiEvent(int midiNote) {
  if(midiNote == 0) { // kick drum
    for(0 => int i; i < numVoices; i++) {  
      getSustain(chordIndex) => int sustain; 
      chordAdsr[i].set(10::ms, 40::ms, .9, sustain::ms); 
      chordAdsr[i].keyOff(); 
      Std.mtof(chords[chordIndex % chords.size()][i]) => chordOscs[i].freq;
      chordAdsr[i].keyOn();
    }
    10::ms => now;
    for(0 => int i; i < numVoices; i++) {
      chordAdsr[i].keyOff();
    }

    (chordIndex + 1) % chords.size() => chordIndex;
  } else if(midiNote >= 54 && midiNote <= 62) { // SPD
      
    midiNote - 54 => int spdPadNumber;
    int chordMidiNote;
    chords[((chordIndex + chords.size()) - 1) % chords.size()][spdPadNumber % 5] => chordMidiNote;
    if(spdPadNumber == 0) { // If it's the first pad, pitch it up so we don't play the super low bass note!
      chordMidiNote + 12 => chordMidiNote;
    }

    int midiNoteToPlay;
    chordMidiNote + (soloOctave * 12) => midiNoteToPlay;
    Std.mtof(midiNoteToPlay) => soloOsc.freq;
    soloAdsr.keyOff();
    soloAdsr.keyOn();
    10::ms=>now;
    soloAdsr.keyOff();  
  } else if(midiNote >= 61 && midiNote <= 62) {
    if(midiNote == 61) {
      soloOctave--;
    } else {
      soloOctave++;
    }
  }
}

fun int getSustain(int chordIndex) {
  if(chordIndex <= 13) {
    return 400;  
  } else if(chordIndex <= 27) {
    return 800;
  } else if(chordIndex <= 35) {
    return 2000;
  } else {
    return 4000;
  }
}


///UTIL FUNCTIONS///

function int[][] chordSequenceMidiNotesToNumbers(string chordSequence[][]) {
  int chordSequenceNumbers[chordSequence.size()][chordSequence[0].size()];

  for(0 => int i; i < chordSequence.size(); i++) {
    chordMidiNotesToNumbers(chordSequence[i]) @=> chordSequenceNumbers[i];
  }
  return chordSequenceNumbers;
}

function int[] chordMidiNotesToNumbers(string chord[]) {
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string noteNames[];
    string numToNote[127];
    int noteToNum[127];
    
    // create array mapping midi note number to name (with octave)
    for(0 => int i; i < 127; i++) {
      i % 12 => int mod;
      -2 + (i / 12) => int octaveNumber;
      noteNames[mod] + octaveNumber => numToNote[i];
    }
    
    // create array mapping midi note name to number (the inverse of numToNote)
    for(0 => int i; i < 127; i++) {
      i => noteToNum[numToNote[i]];
    }
    
    // use noteToNum to map each midi note name to midi note number.
    int numbers[chord.size()];
    for(0 => int i; i < chord.size(); i++) {
      noteToNum[chord[i]] => numbers[i];
    }

    return numbers;
}
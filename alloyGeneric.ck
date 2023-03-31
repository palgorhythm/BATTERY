<<<"Starting...">>>;

MidiIn min;
MidiMsg msg;
0 => int port; // MIDI port
if(!min.open(port)) {
  <<<"ERROR: midi port didn't open on port:", port>>>;
  me.exit();
}
<<<"MIDI connected!">>>;

[
  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"],

  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"],

  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"],

  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"],

  ["F1","A3","B3","E4"],
  ["B1","A#3","D#4","F4"],
  ["A#1","A3","D4","E4"],
  ["F#1","A#3","D4","F4"],
  ["G#1","D4","D#4","G"],
  ["D#1","A#3","D4","A4"],
  ["E1","B3","D#4","G#4"],
  ["A1","C4","G4","B4"],
  ["C#1","E4","B4","D#5"],
  ["C1","D#4","A#4","D5"],
  ["A#0","E4","F4","A4"],
  ["D1","C#4","G#4","A4"],
  ["G1","A#3","F4","A4"],
  ["F#1","A3","E4","G#4"],
  ["C1","B3","F#4","G4"],
  ["F#1","C4","A#4","F5"],
  ["C1","B3","F#4","D5"],
  ["F#1","A3","E4","G#4"],
  ["A#1","A3","E4","F4"],
  ["C2","C#4","F4","G#4"],
  ["B1","A#3","D#4","F4"],
  ["C2","B3","F#4","G4"],
  ["F#1","C4","F4","A#4"],
  ["F1","B3","E4","A4"],
  ["G#1","C4","D4","G4"],
  ["D#1","D4","F4","A4"],
  ["G#0","C4","D4","G4"],
  ["D#1","D4","G4","A4"],
  ["E1","D#4","G#4","A#4"],
  ["A1","C4","G4","B4"],
  ["C#1","G#3","B3","D#4"],
  ["E1","A3","E4","F4"],
  ["D#1","D4","G4","A4"],
  ["F#1","F4","A#4","C5"],
  ["B1","D#4","F4","A#"],
  ["E1","D#4","G#4","A#4"],

  ["F1","A3","B3","E4"],
  ["B1","A#3","D#4","F4"],
  ["A#1","A3","D4","E4"],
  ["F#1","A#3","D4","F4"],
  ["G#1","D4","D#4","G"],
  ["D#1","A#3","D4","A4"],
  ["E1","B3","D#4","G#4"],
  ["A1","C4","G4","B4"],
  ["C#1","E4","B4","D#5"],
  ["C1","D#4","A#4","D5"],
  ["A#0","E4","F4","A4"],
  ["D1","C#4","G#4","A4"],
  ["G1","A#3","F4","A4"],
  ["F#1","A3","E4","G#4"],
  ["C1","B3","F#4","G4"],
  ["F#1","C4","A#4","F5"],
  ["C1","B3","F#4","D5"],
  ["F#1","A3","E4","G#4"],
  ["A#1","A3","E4","F4"],
  ["C2","C#4","F4","G#4"],
  ["B1","A#3","D#4","F4"],
  ["C2","B3","F#4","G4"],
  ["F#1","C4","F4","A#4"],
  ["F1","B3","E4","A4"],
  ["G#1","C4","D4","G4"],
  ["D#1","D4","F4","A4"],
  ["G#0","C4","D4","G4"],
  ["D#1","D4","G4","A4"],
  ["E1","D#4","G#4","A#4"],
  ["A1","C4","G4","B4"],
  ["C#1","G#3","B3","D#4"],
  ["E1","A3","E4","F4"],
  ["D#1","D4","G4","A4"],
  ["F#1","F4","A#4","C5"],
  ["B1","D#4","F4","A#"],
  ["E1","D#4","G#4","A#4"],

  ["F1","A3","B3","E4"],
  ["B1","A#3","D#4","F4"],
  ["A#1","A3","D4","E4"],
  ["F#1","A#3","D4","F4"],
  ["G#1","D4","D#4","G"],
  ["D#1","A#3","D4","A4"],
  ["E1","B3","D#4","G#4"],
  ["A1","C4","G4","B4"],
  ["C#1","E4","B4","D#5"],
  ["C1","D#4","A#4","D5"],
  ["A#0","E4","F4","A4"],
  ["D1","C#4","G#4","A4"],
  ["G1","A#3","F4","A4"],
  ["F#1","A3","E4","G#4"],
  ["C1","B3","F#4","G4"],
  ["F#1","C4","A#4","F5"],
  ["C1","B3","F#4","D5"],
  ["F#1","A3","E4","G#4"],
  ["A#1","A3","E4","F4"],
  ["C2","C#4","F4","G#4"],
  ["B1","A#3","D#4","F4"],
  ["C2","B3","F#4","G4"],
  ["F#1","C4","F4","A#4"],
  ["F1","B3","E4","A4"],
  ["G#1","C4","D4","G4"],
  ["D#1","D4","F4","A4"],
  ["G#0","C4","D4","G4"],
  ["D#1","D4","G4","A4"],
  ["E1","D#4","G#4","A#4"],
  ["A1","C4","G4","B4"],
  ["C#1","G#3","B3","D#4"],
  ["E1","A3","E4","F4"],
  ["D#1","D4","G4","A4"],
  ["F#1","F4","A#4","C5"],
  ["B1","D#4","F4","A#"],
  ["E1","D#4","G#4","A#4"],

  ["F1","A3","B3","E4"],
  ["B1","A#3","D#4","F4"],
  ["A#1","A3","D4","E4"],
  ["F#1","A#3","D4","F4"],
  ["G#1","D4","D#4","G"],
  ["D#1","A#3","D4","A4"],
  ["E1","B3","D#4","G#4"],
  ["A1","C4","G4","B4"],
  ["C#1","E4","B4","D#5"],
  ["C1","D#4","A#4","D5"],
  ["A#0","E4","F4","A4"],
  ["D1","C#4","G#4","A4"],
  ["G1","A#3","F4","A4"],
  ["F#1","A3","E4","G#4"],
  ["C1","B3","F#4","G4"],
  ["F#1","C4","A#4","F5"],
  ["C1","B3","F#4","D5"],
  ["F#1","A3","E4","G#4"],
  ["A#1","A3","E4","F4"],
  ["C2","C#4","F4","G#4"],
  ["B1","A#3","D#4","F4"],
  ["C2","B3","F#4","G4"],
  ["F#1","C4","F4","A#4"],
  ["F1","B3","E4","A4"],
  ["G#1","C4","D4","G4"],
  ["D#1","D4","F4","A4"],
  ["G#0","C4","D4","G4"],
  ["D#1","D4","G4","A4"],
  ["E1","D#4","G#4","A#4"],
  ["A1","C4","G4","B4"],
  ["C#1","G#3","B3","D#4"],
  ["E1","A3","E4","F4"],
  ["D#1","D4","G4","A4"],
  ["F#1","F4","A#4","C5"],
  ["B1","D#4","F4","A#"],
  ["E1","D#4","G#4","A#4"],

  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"],

  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"],

  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"],

  ["F2","A3","B3","E4"],
  ["D#2","G3","A3","D4"],
  ["G#1","A#3","B3","D#4"],
  ["A#1","A3","D4","E4"],
  ["E1","A#3","B3","D#3"]
] @=> string chordStrings[][];

int numVoices;
chordStrings[0].size() => numVoices;
int chords[chordStrings.size()][numVoices];
chordSequenceMidiNoteToNumbers(chordStrings) @=> chords;

<<<"Translated MIDI chords into note numbers.">>>;

0 => int chordIndex;
0 => int chordSustain;
50 => int minSustain;
0 => int soloOctave;
2000 => int maxSustain;

SawOsc oscArray[numVoices];
ADSR adsr[numVoices];
PRCRev reverb[numVoices];
BiQuad filter[numVoices];

for(0 => int i; i < numVoices; i++) {   
  if(i == 0) {
      oscArray[i] => adsr[i] => reverb[i] => dac.left;
  }
  else {
      oscArray[i] => adsr[i] => reverb[i] => dac.right;
  }
  2 * (1 - (i / 20)) => oscArray[i].gain;
  adsr[i].set(20::ms, 10::ms, .9, 500::ms);
  0.01 => reverb[i].mix;
  .99 => filter[i].prad; 
  1 => filter[i].eqzs;
  (7 - i) * .07 => filter[i].gain;
}

PulseOsc soloOsc;
ADSR soloAdsr;
BiQuad soloFilter;
soloOsc => soloAdsr => soloFilter => dac.right;
soloAdsr.set(5::ms, 5::ms, .5, 20::ms);
0.9 => soloOsc.gain;
.99 => soloFilter.prad; 
5 => soloFilter.eqzs;
0.9 => soloFilter.gain;

<<<"Created Oscillators!">>>;

1 => int numBassHits;

3 => int numHandlers;

for(0 => int i; i < numHandlers; i++) {
  spork ~ main();
}

fun void main() {
  while(true) {
    min => now;
    while(min.recv(msg) && msg.data3 != 0) {
      <<< "Channel: ", msg.data1, "MIDI Note #: ", msg.data2, "Velocity: ", msg.data3 >>>; 
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
      (((chordIndex + 1) / chords.size()) * maxSustain) + minSustain => chordSustain;
      adsr[i].set(20::ms, 10::ms, .9, chordSustain::ms);   
      adsr[i].keyOff(); 
      Std.mtof(chords[chordIndex][i]) => oscArray[i].freq;
      adsr[i].keyOn();
    }
    20::ms => now;
    for(0 => int i; i < numVoices; i++) {
      adsr[i].keyOff();
    }

    (chordIndex + 1) % chords.size() => chordIndex;
  } else if(midiNote >= 54 && midiNote <= 58) {
    midiNote - 54 => int spdPadNumber;
    int chordMidiNote;
    chords[chordIndex % chords.size()][spdPadNumber] => chordMidiNote;
    if(spdPadNumber == 0) { // If it's the first pad, pitch it up so we don't play the bass!
      chordMidiNote + 12 => chordMidiNote;
    }

    int midiNoteToPlay;
    chordMidiNote + (soloOctave * 12) => midiNoteToPlay;
    Std.mtof(midiNoteToPlay) => soloOsc.freq;
    
    soloAdsr.keyOff();
    soloAdsr.keyOn();
    20::ms=>now;
    soloAdsr.keyOff();  
  } else if(midiNote >= 61 && midiNote <= 62) {
    if(midiNote == 61) {
      soloOctave--;
    } else {
      soloOctave++;
    }
  }
}


///UTIL FUNCTIONS///

function int[][] chordSequenceMidiNoteToNumbers(string chordSequence[][]) {
  int chordSequenceNumbers[chordSequence.size()][chordSequence[0].size()];

  for(0 => int i; i < chordSequence.size(); i++){
    chordMidiNoteToNumbers(chordSequence[i]) @=> chordSequenceNumbers[i];
  }
  return chordSequenceNumbers;
}

function int[] chordMidiNoteToNumbers(string chord[]) {
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string noteNames[];
    string numToNote[127];
    int noteToNum[127];
    
    //create array of midi notes indexed by integers 0-127
    for(0 => int i; i<127;i++) {
        i % 12 => int mod;
        -2 + (i / 12) => int counter;
        noteNames[mod] + counter => numToNote[i];
    }
    
    //create array indexed by midi notes (the inverse of B)
    for(0 => int i; i<127; i++) {
        i => noteToNum[numToNote[i]];
    }
    
    int numbers[chord.size()];
    for(0 => int i; i<chord.size();i++)
    {
        i % chord.size() => int index;
        noteToNum[chord[index]] => numbers[i];
    }
    return numbers;
}
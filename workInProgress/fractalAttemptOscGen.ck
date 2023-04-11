<<<"Starting...">>>;

MidiIn min;
MidiMsg msg;
0 => int port; // MIDI port
if(!min.open(port)) {
  <<<"ERROR: midi port didn't open on port:", port>>>;
  me.exit();
}
<<<"MIDI connected!">>>;

10 => int attack;
10 => int decay;
0.5 => float sustain;
4000 => int release;
10 => int numHandlers;
[
  ["D#2"], 
  ["G2"],
  ["C2"], 
  ["F2"], 
  ["D2"],
  ["A#2"],
  ["A2"],
  ["G#2"], 
  ["F#2"]
] @=> string chordStrings[][];
int numVoices;
chordStrings[0].size() => numVoices;
int chords[chordStrings.size()][numVoices];
chordSequenceMidiNoteToNumbers(chordStrings) @=> chords;
int chord[];
0 => int chordIndex;
1000 => int didInitializeChord;
0 => int playBSection;

PulseOsc soloOsc;
PRCRev soloReverb;
ADSR soloAdsr;
BiQuad soloFilter;
soloOsc => soloAdsr => soloReverb => soloFilter => dac;
soloAdsr.set(10::ms, 500::ms, .1, 1000::ms);
0.05 => soloReverb.mix;
2 => soloOsc.gain;
.99 => soloFilter.prad; 
1 => soloFilter.eqzs;
0.1 => soloFilter.gain;

Shakers shaker => JCRev shakerReverb => dac;
1 => shaker.gain;
0.95 => shakerReverb.gain;
.025 => shakerReverb.mix;

fun void hitShaker(int velocity) {
  Math.random2( 0, 10 ) => shaker.which;
  ((velocity + 1.0) / 127.0) => float velocityProportion;
  Std.mtof( Math.random2f( 60.0, 128.0 ) ) => shaker.freq;
  Math.random2f( 0, 128 ) => shaker.objects;
  1 * velocityProportion => shaker.noteOn;
}

fun ADSR[] createAdsrs(int numVoices) {
  10 => int newAttack;
  10 => int newDecay;
  0.5 => float newSustain;
  4000 => int newRelease;
  ADSR newAdsrs[numVoices];
  PRCRev newReverb[numVoices];
  BiQuad newFilters[numVoices];

  for(0 => int i; i < numVoices; i++) {   
    if(i == 0) {
      newAdsrs[i] => newReverb[i] => dac.left;
    }
    else {
      newAdsrs[i] => newReverb[i] => dac.right;
    }
    newAdsrs[i].set(newAttack::ms, newDecay::ms, newSustain, newRelease::ms);
    0.1 => newReverb[i].mix;
    .99 => newFilters[i].prad; 
    1 => newFilters[i].eqzs;
    (7 - i) * .1 => newFilters[i].gain;
  }
  return newAdsrs;
}

fun SinOsc[] createOscs(ADSR adsrs[]) {
  SinOsc newOscs[adsrs.size()];

  for(0 => int i; i < adsrs.size(); i++) {   
    if(i == 0) {
      newOscs[i] => adsrs[i];
    }
    else {
      newOscs[i] => adsrs[i];
    }
    1.0 * (1.0 - (i / 10.0)) => newOscs[i].gain;
  }

  return newOscs;
}

ADSR adsrs[numVoices];
SinOsc oscs[numVoices];
createAdsrs(numVoices) @=> adsrs;
createOscs(adsrs) @=> oscs;

<<<"Created Oscillators!">>>;

for(0 => int i; i < numHandlers; i++) {
  spork ~ main();
}

fun void main() {
  while(true) {
    min => now;
    while(min.recv(msg) && msg.data3 != 0) {
      <<< "Channel:", msg.data1, "MIDI Note #:", msg.data2, "Velocity:", msg.data3 >>>; 
      handleMidiEvent(msg.data2, msg.data3);
    }
  }    
}

while(true) {
  1::second => now;
}

<<<"Started!">>>;

fun void handleMidiEvent(int midiNote, int velocity) {
  ((velocity + 1.0) / 127.0) => float velocityProportion;
  if(didInitializeChord > 0){ 
    // Initialize chord once to handle when kick is not hit first.
    chords[0]  @=> chord;
    0 => didInitializeChord;
    0 => playBSection;
    <<<"Initialized chord.">>>;
  }
  if(midiNote == 0) { // kick drum
    soloAdsr.keyOff();
    if(playBSection == 1){
      playNotes([chord[0], chord[0] + 7, chord[0] + 12], velocity);
    } else {
      playNotes(chord, velocity);
    }
  } else if(midiNote == 1) { // snare
    (1.5 * velocityProportion) => soloOsc.gain;
    Math.round(500 * velocityProportion) => float release;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    playNotes([chord[Math.random2(1,4)] + (Math.random2(1,2) * 12)], velocity);
  } else if(midiNote == 2) { // floor tom
    (0.25 * velocityProportion) => soloOsc.gain;
    Math.round(1000 * velocityProportion) => float release;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    playNotes([chord[0] + (Math.random2(0,1) * 12)], velocity);
  } else if(midiNote >= 54 && midiNote <= 62) { // spd
    (2.0 * velocityProportion) => soloOsc.gain;
    midiNote - 54 => int index;
    chords[index] @=> chord;
    Math.round(index * 30 * velocityProportion) => float release;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    chord[index % chord.size()] + (Math.random2(2,3) * 12) => int midiNoteToPlay;
    // hitShaker(velocity);
    playNotes([midiNoteToPlay], velocity);
    if(midiNote == 62){
      if(playBSection == 1){
        0 => playBSection;
      } else {
        1 => playBSection;
      }
    }
  }
}

fun void playNotesFractal(float freqs[],float velocity) {
  3.0/2.0 => float ratio;
  float freqsUp[freqs.size()];
  float freqsDown[freqs.size()];
  ((velocity + 1.0) / 100.0) => float velocityProportion;
  100.0 / velocityProportion => float decay;
  <<<"velocity", velocity, "velocityProp", velocityProportion, "decay", decay, "freq", freqs[0]>>>;

  if(freqs[0] < 40.0 || decay > 5000.0){
    <<<"BASE CASE!">>>;
    return;
  }

  ADSR tempAdsrs[numVoices];
  SinOsc tempOscs[numVoices];
  createAdsrs(numVoices) @=> tempAdsrs;
  createOscs(tempAdsrs) @=> tempOscs;

  for(0 => int i; i < freqs.size(); i++) {
    velocityProportion => tempOscs[i].gain;
    <<<tempOscs[i].gain()>>>;
    freqs[i] => tempOscs[i].freq;
    tempAdsrs[i].keyOn();
  }
  (decay/2.0)::ms => now;
  for(0 => int i; i < freqs.size(); i++) {
    tempAdsrs[i].keyOff();
    freqs[i] * ratio => freqsUp[i];
    freqs[i] / ratio => freqsDown[i];
  }
  <<<"DONE playing", freqs[0]>>>;
  spork ~ playNotesFractal(freqsUp, velocity / Math.pow(ratio, 2));
  spork ~ playNotesFractal(freqsDown, velocity / Math.pow(ratio, 2));
  5::second => now;
}

fun void playNotes(int notes[],float velocity) {
  float freqs[notes.size()];

  for(0 => int i; i < notes.size(); i++) {
    Std.mtof(notes[i]) => freqs[i];
  }
  spork ~ playNotesFractal(freqs, velocity);
  5::second => now;
}

fun int[][] chordSequenceMidiNoteToNumbers(string chordSequence[][]) {
  int chordSequenceNumbers[chordSequence.size()][chordSequence[0].size()];

  for(0 => int i; i < chordSequence.size(); i++){
    chordMidiNoteToNumbers(chordSequence[i]) @=> chordSequenceNumbers[i];
  }
  return chordSequenceNumbers;
}

fun int[] chordMidiNoteToNumbers(string chord[]) {
    ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"] @=> string noteNames[];
    string numToNote[127];
    int noteToNum[127];
    
    //create array of midi notes indexed by integers 0-127
    for(0 => int i; i < 127;i++) {
        i % 12 => int mod;
        -2 + (i / 12) => int counter;
        noteNames[mod] + counter => numToNote[i];
    }
    
    //create array indexed by midi notes (the inverse of B)
    for(0 => int i; i < 127; i++) {
        i => noteToNum[numToNote[i]];
    }
    
    int numbers[chord.size()];
    for(0 => int i; i < chord.size(); i++)
    {
        i % chord.size() => int index;
        noteToNum[chord[index]] => numbers[i];
    }
    return numbers;
}
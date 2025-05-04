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

5 => int numVoices;
10 => int attack;
10 => int decay;
0.5 => float sustain;
4000 => int release;
10 => int numHandlers;
0.5 => float defaultGain;

PulseOsc soloOsc;
PRCRev soloReverb;
ADSR soloAdsr;
BiQuad soloFilter;
soloOsc => soloAdsr => soloReverb => soloFilter => Pan2 soloPan => dac;
soloAdsr.set(10::ms, 500::ms, .1, 1000::ms);
0.05 => soloReverb.mix;
0.2 => soloPan.pan;
defaultGain * 0.1 => soloFilter.gain;
defaultGain * 1.2 => soloOsc.gain;
.99 => soloFilter.prad; 
1 => soloFilter.eqzs;

Shakers shaker => JCRev shakerReverb => dac;
1 => shaker.gain;
defaultGain * 0.9 => shakerReverb.gain;
.025 => shakerReverb.mix;

fun void hitShaker(int velocity) {
  Math.random2( 0, 10 ) => shaker.which;
  ((velocity + 1.0) / 127.0) => float velocityProportion;
  Std.mtof( Math.random2f( 60.0, 128.0 ) ) => shaker.freq;
  Math.random2f( 0, 128 ) => shaker.objects;
  1 * velocityProportion => shaker.noteOn;
}

SqrOsc oscs[numVoices];
ADSR adsrs[numVoices];
PRCRev reverb[numVoices];
BiQuad filter[numVoices];
Pan2 pan[numVoices];

fun void configureOscillators() {
  for(0 => int i; i < numVoices; i++) {   
    oscs[i] => adsrs[i] => reverb[i] => pan[i] => dac;
    -0.1 * i => pan[i].pan;
    adsrs[i].set(attack::ms, decay::ms, sustain, release::ms);
    0.07 => reverb[i].mix;
    .99 => filter[i].prad; 
    1 => filter[i].eqzs;
    defaultGain * 1.0 * (1.0 - (i / 10.0)) => oscs[i].gain;
    defaultGain * 0.5 * (1.0 - (i / 10.0)) => filter[i].gain;
  }
}

configureOscillators();

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
[36, 36 + 7, 36 + 14, 36 + 21, 36 + 28] @=> int chord[];
1000 => int didInitializeChord;
0 => int playMelody;
0 => int melodyIndex;

fun void handleMidiEvent(int midiNote, int velocity) {
  ((velocity + 0.1) / 127.0) => float velocityProportion;
  if(didInitializeChord > 0){ 
    // Initialize chord once to handle when kick is not hit first.
    [36, 36 + 7, 36 + 14, 36 + 21, 36 + 28]  @=> chord;
    0 => didInitializeChord;
    0 => playMelody;
    0 => melodyIndex;
    <<<"Initialized chord.">>>;
  }
  if(midiNote == 0) { // kick drum
    soloAdsr.keyOff();
    generateRandomChord() @=> chord;
    if(playMelody == 1){
      playNotes(
        [chord[0], chord[0] + 7, chord[0] + 23], 
        adsrs, 
        oscs, 
        (1.0 * velocityProportion)
      );
      melodyIndex + 1 => melodyIndex;
    } else {
      playNotes(
        chord, 
        adsrs, 
        oscs, 
        (1.0 * velocityProportion)
      );
    }
  } else if(midiNote == 1) { // snare
    Math.round(500 * velocityProportion) => float release;
    0.2 => soloReverb.mix;
    defaultGain * 0.2 => soloFilter.gain;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    playNotes(
      [chord[Math.random2(1,4)] + (Math.random2(1,2) * 12)], 
      [soloAdsr], 
      [soloOsc], 
      (1.0 * velocityProportion)
    );
  } else if(midiNote == 2) { // floor tom
    0.05 => soloReverb.mix;
    defaultGain * 0.2 => soloFilter.gain;
    Math.round(1000 * velocityProportion) => float release;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    playNotes(
      [chord[0] + (Math.random2(0,1) * 12)], 
      [soloAdsr], 
      [soloOsc], 
      (0.2 * velocityProportion)
    );
  } else if(midiNote >= 54 && midiNote <= 62) { // spd
    midiNote - 54 => int normalizedMidiNote;
    Math.round(normalizedMidiNote * 30 * velocityProportion) => float release;
    0.01 => soloReverb.mix;
    defaultGain * 0.12 => soloFilter.gain;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    chord[normalizedMidiNote % chord.size()] + (Math.random2(2,3) * 12) => int midiNoteToPlay;
    hitShaker(velocity);
    playNotes(
      [midiNoteToPlay], 
      [soloAdsr], 
      [soloOsc], 
      (2.0 * velocityProportion)
    );
    if(midiNote == 62){
      if(playMelody == 1){
        0 => playMelody;
      } else {
        0 => melodyIndex;
        1 => playMelody;
      }
    }
  }
}

fun void playNotes(int notes[], ADSR adsrs[], Osc oscs[], float gain) {
  for(0 => int i; i < notes.size(); i++) {
    adsrs[i].keyOff(); 
    defaultGain * gain * (1.0 - (i / 5.0)) => oscs[i].gain;
    Math.random2f(0.0, 1.0) => oscs[i].phase;
    Std.mtof(notes[i]) => oscs[i].freq;
    adsrs[i].keyOn();
  }
  decay::ms => now;
  for(0 => int i; i < notes.size(); i++) {
    adsrs[i].keyOff();
  }
}

fun int[] generateRandomChord() {
  [
    [0,4,7,11,14], // Maj9
    [0,7,14,21,28], // Maj69
    [0,4,11,18,26], // Maj9#11
    [0,4,11,14,16] // sus
    // [0,3,7,10,16] // Minor
    // [0,4,7,10,14] // Dominant
  ] @=> int chordQualities[][];
  [0, 3, 6, 9, 11, 8, 5, 2, 1, 4, 7, 10] @=> int melodyIntervals[];

  int root;
  if(playMelody == 1) {
    36 + melodyIntervals[melodyIndex % melodyIntervals.size()] => root;
  } else {
    36 + (Math.random2(0, 11)) => root;
  }
  Math.random2(0, chordQualities.size() - 1) => int qualityIndex;
  chordQualities[qualityIndex] @=> int chord[];
  for(0 => int i; i < chord.size(); i ++) {
    Math.random2(1,3) => int randomOctave;
    if( i == 0 ){
      root + chord[i] => chord[i];
    } else {
      root + chord[i] + (randomOctave * 12) => chord[i];   
    }
  }
  return chord;
}
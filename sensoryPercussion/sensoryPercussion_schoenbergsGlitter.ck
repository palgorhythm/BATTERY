// ============================================================
// SCHOENBERG'S GLITTER - generative random chord piece
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// KICK: Generate and play random 5-voice chord (or 3-voice in melody mode)
// SNARE: Solo - random chord tone, 1-2 octaves up
// FLOOR TOM: Root note solo, 0-1 octaves up. Toggles melody mode.
// CRASH: Chord tone solo + shaker. Region 13 toggles melody mode.
// ============================================================

// Sensory Percussion MIDI map:
// Drums: kick=0, snare=1, rack tom=2, floor tom=3
// Hi-hat zones:  4 (bow), 5 (edge), 6 (bell-shoulder), 7 (bell-tip), 8 (ping)
// Crash zones:   9 (bow), 10 (edge), 11 (bell-shoulder), 12 (bell-tip), 13 (ping)
// Ride zones:    14 (bow), 15 (edge), 16 (bell-shoulder), 17 (bell-tip), 18 (ping)

MidiIn min;
MidiMsg msg;
fun void setUpMidi() {
    for(0 => int i; i < 8; i++){
        if(min.open(i) && min.name().find("IAC") > -1) {
            <<<"Opened IAC Driver on port", i>>>;
            return;
        }
    }
    <<<"ERROR: IAC Driver MIDI port not found.">>>;
    me.exit();
}
setUpMidi();

5 => int numVoices;
10 => int attack;
10 => int decay;
0.5 => float sustain;
4000 => int release;
0.2 => float defaultGain;

// master bus -> channels 3 & 4
Gain master => dac.chan(2);
master => dac.chan(3);

PulseOsc soloOsc;
PRCRev soloReverb;
ADSR soloAdsr;
BiQuad soloFilter;
soloOsc => soloAdsr => soloReverb => soloFilter => Pan2 soloPan => master;
soloAdsr.set(10::ms, 500::ms, .1, 1000::ms);
0.05 => soloReverb.mix;
0.2 => soloPan.pan;
defaultGain * 0.1 => soloFilter.gain;
defaultGain * 1.2 => soloOsc.gain;
.99 => soloFilter.prad;
1 => soloFilter.eqzs;

Shakers shaker => JCRev shakerReverb => master;
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
    oscs[i] => adsrs[i] => reverb[i] => pan[i] => master;
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

for(0 => int i; i < 3; i++) {
  spork ~ main();
  10::ms => now;
}

fun void main() {
  while(true) {
    min => now;
    while(min.recv(msg) && msg.data3 != 0) {
      <<< "midi note", msg.data2, "velocity", msg.data3 >>>;
      handleMidiEvent(msg.data2, msg.data3);
    }
  }
}

while(true) {
  1::second => now;
}

[36, 36 + 7, 36 + 14, 36 + 21, 36 + 28] @=> int chord[];
1000 => int didInitializeChord;
1 => int playMelody;
0 => int melodyIndex;

fun void handleMidiEvent(int midiNote, int velocity) {
  ((velocity + 0.1) / 127.0) => float velocityProportion;
  if(didInitializeChord > 0){
    [36, 36 + 7, 36 + 14, 36 + 21, 36 + 28]  @=> chord;
    0 => didInitializeChord;
    1 => playMelody;
    0 => melodyIndex;
  }
  if(midiNote == 0) { // kick drum
    soloAdsr.keyOff();
    generateRandomChord() @=> chord;
    if(playMelody == 1){
      [chord[0], chord[0] + 7, chord[0] + 23] @=> int melNotes[];
      playChord(melNotes, 1.0 * velocityProportion);
      melodyIndex + 1 => melodyIndex;
    } else {
      playChord(chord, 1.0 * velocityProportion);
    }
  } else if(midiNote == 3) { // floor tom (was 2)
    0.05 => soloReverb.mix;
    defaultGain * 0.2 => soloFilter.gain;
    Math.round(1000 * velocityProportion) => float release;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    playSolo(chord[0] + (Math.random2(0,1) * 12), 0.2 * velocityProportion);
    // toggle melody mode
    if(playMelody == 1){
      0 => playMelody;
    } else {
      0 => melodyIndex;
      1 => playMelody;
    }
  } else if(midiNote >= 9 && midiNote <= 13) { // crash (was 54-62)
    midiNote - 9 => int normalizedMidiNote;
    Math.round((normalizedMidiNote + 1) * 50 * velocityProportion) => float release;
    0.01 => soloReverb.mix;
    defaultGain * 0.5 => soloFilter.gain;
    soloAdsr.set(10::ms, 10::ms, .9, release::ms);
    chord[normalizedMidiNote % chord.size()] + (Math.random2(2,3) * 12) => int midiNoteToPlay;
    hitShaker(velocity);
    playSolo(midiNoteToPlay, 4.0 * velocityProportion);
    if(midiNote == 13){ // last crash zone toggles melody mode
      if(playMelody == 1){
        0 => playMelody;
      } else {
        0 => melodyIndex;
        1 => playMelody;
      }
    }
  }
}

fun void playChord(int notes[], float gain) {
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

fun void playSolo(int note, float gain) {
  soloAdsr.keyOff();
  defaultGain * gain => soloOsc.gain;
  Math.random2f(0.0, 1.0) => soloOsc.phase;
  Std.mtof(note) => soloOsc.freq;
  soloAdsr.keyOn();
  decay::ms => now;
  soloAdsr.keyOff();
}

fun int[] generateRandomChord() {
  [
    [0,4,7,11,14], // Maj9
    [0,7,14,21,28], // Maj69
    [0,4,11,18,26], // Maj9#11
    [0,4,11,14,16] // sus
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

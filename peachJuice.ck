MidiIn min;
MidiMsg msg;
0 => int port;

if(!min.open(port)) {
  <<<"ERROR: midi didn't open on port:", port>>>;
  me.exit();
}

// set up sequences
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
chordMidiNotesToNumbers(["A3","A3", "D4","E4","B3","E3","A3","C3","E4","A3","A3","D4","E4","G4","A4","B4","E5"]) @=> int snare[];

// set up oscillators
PulseOsc sin => ADSR e1 => BiQuad f => PRCRev reverb1 => dac.left;
e1.set( 10::ms, 20::ms, .5, 80::ms );
.99 => f.prad; 
1 => f.eqzs;
.05 => f.gain;
0.8 => sin.gain;
.01 => reverb1.mix;

PulseOsc saw => ADSR e2 => PRCRev reverb2 => dac.right;
e2.set( 10::ms, 20::ms, .5, 1000::ms );
1.0 => saw.gain;
.1 => reverb2.mix;

SawOsc OSCarray[6];
ADSR E[6];
PRCRev R[6];

for(0 => int i; i < 6; i++) {   
  if(i == 0) {
    OSCarray[i] => E[i] => R[i] => dac.left;
  } else {
    OSCarray[i] => E[i] => R[i] => dac.right;
  }
  1.0 * (1.0 - (i / 30.0)) => OSCarray[i].gain;
  E[i].set(10::ms, 20::ms, .9, 4000::ms);
  0.01 => R[i].mix;
}

// initialize our state variables
0 => int bassIndex;
0 => int snareIndex;
0 => int bSection; // whether we're in the b sectiomn
0 => int chordIndex;
1 => int chordGo;
0 => int songSectionIndex;
0 => int interDiv;
now  => time bassTime;
40::ms => dur interval; // duration between bass drum hits
interval / 4 => dur hitInter; // duration for each synth sound

spork ~ handleMidiEvents();
spork ~ handleMidiEvents();
spork ~ handleMidiEvents();

while(true) {
  1::second => now;
}

fun void handleMidiEvents() {
  while(true) {
    min => now;
    while(min.recv(msg)) {
      <<<"songSectionIndex", songSectionIndex,"chordIndex", chordIndex>>>;
      if(msg.data3 != 0 && msg.data2 == 0) { // kick drum
        e1.keyOff();
        now - bassTime => interval; // the amount of time since the last time we hit the bass drum.
        interval / 4.0 => hitInter; // divide the amount of time that passed by 4 to get a sensible duration.
        now => bassTime; // save the current time we hit the bass drum.
        
        if(bSection == 0) { // if in A section, hit the current note 4 times
          if(bassIndex == bass.size() - 1) {
            6 => interDiv; // do 16th triplets if we're on the last note of the sequence
          } else {
            4 => interDiv; // otherwise, do 16ths.
          }
          
          for(0 => int i; i < interDiv; i++) {
            Std.mtof(bass[bassIndex]) => sin.freq;
            e1.keyOn();
            hitInter/(interDiv / 2.0) => now; // these ensure that the total amount of time that passes after this loop is hitInter
            e1.keyOff();
            hitInter/(interDiv / 2.0) => now;
          }
        } else if(chordGo == 1) {
          for(0 => int i; i < chords[chordIndex].size(); i++) {
            E[i].keyOff();
            Std.mtof(chords[chordIndex][i]) => OSCarray[i].freq;
            E[i].keyOn();
          }

          10::ms => now;

          for(0 => int i; i < chords[chordIndex].size(); i++) {
            E[i].keyOff();
          }

          if(chordIndex == chords.size() - 1) { // if we got to the end of the chord sequence, increment the section
            songSectionIndex + 1 => songSectionIndex;
          }
          (chordIndex + 1) % chords.size() => chordIndex;  
          0 => chordGo; // need to hit the floor tom again to release the next chord.
        }

        if(bSection == 0) { 
          (bassIndex + 1) % bass.size() => bassIndex;  
          0 => chordIndex;
        } else {
          0 => bassIndex;
        }
      } else if(msg.data3 != 0 && msg.data2 == 1 && bSection == 0) { // snare
        Std.mtof(snare[snareIndex]) => saw.freq; // play the current snare melody note.
        e2.keyOn();
        10::ms => now;
        e2.keyOff();
        (snareIndex + 1) % snare.size() => snareIndex;  
      } else if(msg.data3 != 0 && msg.data2 == 2) { // tom   
        if(bSection == 0) {
          e1.keyOff();
          1 => bSection; // make it the B section
          1 => chordGo; // unleash the CHORDS!
          0 => bassIndex; // reset the bass sequence
        } else if (songSectionIndex == 1 || songSectionIndex == 4) { // if we've played through the chord sequence once or 4 times
          0 => bSection; // now it's the A section.
          songSectionIndex + 1 => songSectionIndex;
          for(0 => int i; i < chords[chordIndex].size(); i++) {
            E[i].keyOff();
          }
          0 => bassIndex; // reset the bass sequence
        } else {
          1 => chordGo; // unleash the CHORDS!
        } 
      }
    }
  }    
}


///UTIL FUNCTIONS///

fun int[][] chordSequenceMidiNotesToNumbers(string chordSequence[][]) {
  int chordSequenceNumbers[chordSequence.size()][chordSequence[0].size()];

  for(0 => int i; i < chordSequence.size(); i++){
    chordMidiNotesToNumbers(chordSequence[i]) @=> chordSequenceNumbers[i];
  }
  return chordSequenceNumbers;
}

fun int[] chordMidiNotesToNumbers(string chord[]) {
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
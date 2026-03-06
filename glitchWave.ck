// GlitchWave - A new song for BATTERY project
// By Claude for solo drums & triggers performance
// Designed to be controlled via MIDI triggers from a drum kit

// Global variables
60::second => dur songLength; // Total song length
0 => int currentSection; // Track which section we're in
0.0 => float masterGain; // Master volume control
0 => int performanceMode; // 0 = intro, 1 = verse, 2 = chorus, 3 = bridge, 4 = outro

// Arrays for notes in different scales
[60, 62, 64, 65, 67, 69, 71, 72] @=> int minorScale[]; // A minor
[60, 62, 63, 65, 67, 68, 70, 72] @=> int majorScale[]; // C major
[60, 63, 65, 67, 70, 72, 75, 77] @=> int pentatonicScale[]; // C pentatonic
[60, 61, 63, 66, 67, 68, 70, 72] @=> int dorianScale[]; // D dorian

// Create a master gain control
Gain master => dac;
1.0 => master.gain;

// Bass synth
class BassSynth {
    SawOsc saw => LPF filter => ADSR env => Gain output => master;
    SinOsc sub => env;
    
    0.7 => saw.gain;
    0.5 => sub.gain;
    1000 => filter.freq;
    5 => filter.Q;
    
    env.set(10::ms, 100::ms, 0.7, 500::ms);
    
    fun void playNote(int note, dur length) {
        Std.mtof(note) => saw.freq;
        Std.mtof(note - 12) => sub.freq; // Sub oscillator one octave down
        1 => env.keyOn;
        length - 50::ms => now;
        1 => env.keyOff;
        50::ms => now;
    }
    
    fun void setFilter(float freq, float res) {
        freq => filter.freq;
        res => filter.Q;
    }
}

// Pad synth with chorus effect
class PadSynth {
    // Multiple oscillators for richness
    SawOsc saw1 => LPF filter => ADSR env => NRev reverb => Gain output => master;
    SawOsc saw2 => filter;
    TriOsc tri => filter;
    
    0.3 => saw1.gain;
    0.3 => saw2.gain;
    0.2 => tri.gain;
    1.0 => output.gain;
    
    2000 => filter.freq;
    1 => filter.Q;
    0.3 => reverb.mix;
    
    env.set(200::ms, 300::ms, 0.6, 800::ms);
    
    fun void playChord(int notes[], dur length) {
        Std.mtof(notes[0]) => saw1.freq;
        Std.mtof(notes[1]) => saw2.freq;
        Std.mtof(notes[2]) => tri.freq;
        
        1 => env.keyOn;
        length - 100::ms => now;
        1 => env.keyOff;
        100::ms => now;
    }
    
    fun void setFilter(float freq, float res) {
        freq => filter.freq;
        res => filter.Q;
    }
}

// Lead synth with delay
class LeadSynth {
    TriOsc osc => ADSR env => Echo delay => NRev reverb => Gain output => master;
    
    0.8 => osc.gain;
    0.7 => output.gain;
    
    env.set(5::ms, 50::ms, 0.8, 200::ms);
    
    // Set up echo
    250::ms => delay.max => delay.delay;
    0.4 => delay.mix;
    0.6 => delay.gain;
    delay => delay; // Feedback loop
    
    0.1 => reverb.mix;
    
    fun void playNote(int note, dur length) {
        Std.mtof(note) => osc.freq;
        1 => env.keyOn;
        length - 50::ms => now;
        1 => env.keyOff;
        50::ms => now;
    }
    
    fun void setDelay(dur delayTime, float feedbackGain) {
        delayTime => delay.delay;
        feedbackGain => delay.gain;
    }
}

// Glitch effects processor
class GlitchProcessor {
    Gain input => PitShift pitch => Chorus chorus => BitCrusher crusher => Gain output => master;
    
    1.0 => pitch.mix;
    1.0 => pitch.shift;
    
    0.3 => chorus.mix;
    0.7 => chorus.modFreq;
    0.5 => chorus.modDepth;
    
    8 => crusher.bits;
    1.0 => crusher.downsampleFactor;
    
    fun void glitchEffect(int effectType) {
        if(effectType == 0) {
            // Pitch down effect
            0.5 => pitch.shift;
            20::ms => now;
            1.0 => pitch.shift;
        }
        else if(effectType == 1) {
            // Bit crush effect
            4 => crusher.bits;
            4.0 => crusher.downsampleFactor;
            50::ms => now;
            8 => crusher.bits;
            1.0 => crusher.downsampleFactor;
        }
        else if(effectType == 2) {
            // Stutter effect
            for(0 => int i; i < 8; i++) {
                if(i % 2 == 0) 1.0 => output.gain;
                else 0.0 => output.gain;
                10::ms => now;
            }
            1.0 => output.gain;
        }
    }
}

// Create our synth instances
BassSynth bass;
PadSynth pad;
LeadSynth lead;
GlitchProcessor glitch;

// MIDI setup for receiving drum triggers
MidiIn min;
MidiMsg msg;

// Try to open the MIDI device
// Change this number based on your MIDI interface
if(min.open(0)) {
    <<< "MIDI device opened!", "" >>>;
}
else {
    <<< "Failed to open MIDI device...", "" >>>;
    me.exit();
}

// Function to map MIDI notes to different behaviors
fun void midiListener() {
    while(true) {
        // Wait on MIDI event
        min => now;
        
        // Get the message
        while(min.recv(msg)) {
            // Note on message
            if(msg.data1 == 144) {
                // Extract note number and velocity
                msg.data2 => int note;
                msg.data3 => int velocity;
                
                // Map different drum triggers to different functions
                if(note == 36) { // Kick drum (usually note 36)
                    spawnBassLine(velocity);
                }
                else if(note == 38) { // Snare (usually note 38)
                    triggerGlitch(velocity);
                }
                else if(note == 42) { // Hi-hat closed (usually note 42)
                    playLeadNote(velocity);
                }
                else if(note == 46) { // Hi-hat open (usually note 46)
                    changeSection();
                }
                else if(note == 49) { // Crash cymbal (usually note 49)
                    triggerPadChord(velocity);
                }
                else if(note == 51) { // Ride cymbal (usually note 51)
                    changeScale(velocity);
                }
                else if(note == 41) { // Low tom (usually note 41)
                    decreaseTempo();
                }
                else if(note == 43) { // High tom (usually note 43)
                    increaseTempo();
                }
            }
        }
    }
}

// Function to spawn a bass line based on current section
fun void spawnBassLine(int velocity) {
    0.5 + (velocity / 127.0) * 0.5 => float vol;
    
    // Create a bass pattern based on the current section
    if(currentSection == 0) { // Intro
        spork ~ playBassPattern([0, 0, 4, 0], 200::ms, vol);
    }
    else if(currentSection == 1) { // Verse
        spork ~ playBassPattern([0, 3, 5, 7], 150::ms, vol);
    }
    else if(currentSection == 2) { // Chorus
        spork ~ playBassPattern([0, 7, 5, 3], 100::ms, vol);
    }
    else if(currentSection == 3) { // Bridge
        spork ~ playBassPattern([0, 2, 4, 6, 7], 125::ms, vol);
    }
    else if(currentSection == 4) { // Outro
        spork ~ playBassPattern([7, 5, 4, 0], 250::ms, vol);
    }
}

// Function to play a bass pattern
fun void playBassPattern(int pattern[], dur noteLength, float volume) {
    volume => bass.output.gain;
    
    for(0 => int i; i < pattern.size(); i++) {
        bass.playNote(minorScale[pattern[i]] - 12, noteLength);
    }
}

// Function to trigger glitch effects
fun void triggerGlitch(int velocity) {
    // Different glitch effect based on velocity
    if(velocity < 40) {
        spork ~ glitch.glitchEffect(0);
    }
    else if(velocity < 90) {
        spork ~ glitch.glitchEffect(1);
    }
    else {
        spork ~ glitch.glitchEffect(2);
    }
}

// Function to play a lead note
fun void playLeadNote(int velocity) {
    0.3 + (velocity / 127.0) * 0.7 => float vol;
    vol => lead.output.gain;
    
    // Play different notes depending on section
    if(currentSection == 0) { // Intro
        lead.playNote(minorScale[Math.random2(0, 3)], 75::ms);
    }
    else if(currentSection == 1) { // Verse
        lead.playNote(minorScale[Math.random2(2, 5)], 100::ms);
    }
    else if(currentSection == 2) { // Chorus
        lead.playNote(minorScale[Math.random2(4, 7)], 150::ms);
    }
    else if(currentSection == 3) { // Bridge
        lead.playNote(dorianScale[Math.random2(0, 7)], 125::ms);
    }
    else if(currentSection == 4) { // Outro
        lead.playNote(pentatonicScale[Math.random2(3, 7)], 200::ms);
    }
}

// Function to change sections
fun void changeSection() {
    (currentSection + 1) % 5 => currentSection;
    
    // Update synth parameters for new section
    if(currentSection == 0) { // Intro
        2000 => bass.filter.freq;
        3 => bass.filter.Q;
        lead.setDelay(250::ms, 0.4);
        <<< "Section: INTRO", "" >>>;
    }
    else if(currentSection == 1) { // Verse
        1000 => bass.filter.freq;
        2 => bass.filter.Q;
        lead.setDelay(125::ms, 0.3);
        <<< "Section: VERSE", "" >>>;
    }
    else if(currentSection == 2) { // Chorus
        4000 => bass.filter.freq;
        5 => bass.filter.Q;
        lead.setDelay(333::ms, 0.6);
        <<< "Section: CHORUS", "" >>>;
    }
    else if(currentSection == 3) { // Bridge
        500 => bass.filter.freq;
        8 => bass.filter.Q;
        lead.setDelay(500::ms, 0.7);
        <<< "Section: BRIDGE", "" >>>;
    }
    else if(currentSection == 4) { // Outro
        1500 => bass.filter.freq;
        1 => bass.filter.Q;
        lead.setDelay(375::ms, 0.5);
        <<< "Section: OUTRO", "" >>>;
    }
}

// Function to trigger pad chords
fun void triggerPadChord(int velocity) {
    0.4 + (velocity / 127.0) * 0.6 => float vol;
    vol => pad.output.gain;
    
    // Different chord progressions for different sections
    if(currentSection == 0) { // Intro
        spork ~ playPadProgression([[48, 52, 55], [48, 51, 55]], 1::second);
    }
    else if(currentSection == 1) { // Verse
        spork ~ playPadProgression([[48, 52, 55], [50, 53, 57], [51, 55, 58], [53, 57, 60]], 800::ms);
    }
    else if(currentSection == 2) { // Chorus
        spork ~ playPadProgression([[48, 52, 55], [53, 57, 60], [51, 55, 58], [50, 53, 57]], 600::ms);
    }
    else if(currentSection == 3) { // Bridge
        spork ~ playPadProgression([[51, 55, 58], [48, 52, 55], [46, 50, 53], [43, 47, 50]], 700::ms);
    }
    else if(currentSection == 4) { // Outro
        spork ~ playPadProgression([[48, 52, 55], [48, 51, 55]], 1.2::second);
    }
}

// Function to play a pad chord progression
fun void playPadProgression(int chords[][], dur chordLength) {
    for(0 => int i; i < chords.size(); i++) {
        pad.playChord(chords[i], chordLength);
    }
}

// Function to change scale based on velocity
fun void changeScale(int velocity) {
    if(velocity < 40) {
        // Change to minor scale
        [60, 62, 63, 65, 67, 68, 70, 72] @=> minorScale;
        <<< "Scale: MINOR", "" >>>;
    }
    else if(velocity < 80) {
        // Change to major scale
        [60, 62, 64, 65, 67, 69, 71, 72] @=> majorScale;
        <<< "Scale: MAJOR", "" >>>;
    }
    else if(velocity < 100) {
        // Change to pentatonic scale
        [60, 63, 65, 67, 70, 72, 75, 77] @=> pentatonicScale;
        <<< "Scale: PENTATONIC", "" >>>;
    }
    else {
        // Change to dorian scale
        [60, 62, 63, 65, 67, 69, 70, 72] @=> dorianScale;
        <<< "Scale: DORIAN", "" >>>;
    }
}

// Functions to change tempo
fun void decreaseTempo() {
    0.95 => Math.max(0.5, Global.tempo) => Global.tempo;
    <<< "Tempo decreased to:", Global.tempo * 60, "BPM" >>>;
}

fun void increaseTempo() {
    1.05 =>  Math.min(2.0, Global.tempo) => Global.tempo;
    <<< "Tempo increased to:", Global.tempo * 60, "BPM" >>>;
}

// Main program
fun void main() {
    // Set initial tempo (120 BPM)
    1.0 => Global.tempo;
    
    // Start MIDI listener in background
    spork ~ midiListener();
    
    // Keep program running for song duration
    songLength => now;
}

// Run the main program
main();
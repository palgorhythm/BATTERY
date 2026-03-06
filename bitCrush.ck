// PercussionSynth - A drum-triggered ChucK song
// No independent sequences - all sounds triggered directly by drums
// Designed for BATTERY project with:
// - Kick drum = MIDI note 0
// - Snare drum = MIDI note 1
// - Floor tom = MIDI note 2
// - SPD pad = MIDI notes 54-62

// Global variables
0 => int mode; // Different sound modes/palettes
120 => float bpm; // Track tempo for time-based effects

// Set up master gain route
Gain master => dac;
0.8 => master.gain;

// Create a global reverb that all sounds can share
NRev globalRev => master;
0.1 => globalRev.mix;

// Multi-voice synth triggered by kick drum
class KickSynth {
    // Layered sound sources
    SinOsc sub => ADSR env => LPF filter => Gain output;
    SawOsc mid => env;
    Noise click => HPF clickFilter => env;
    
    // Connect to master
    output => globalRev;
    output => master;
    
    // Configure components
    0.5 => output.gain;
    100 => filter.freq;
    1.0 => filter.Q;
    5000 => clickFilter.freq;
    
    // Configure envelope
    env.set(5::ms, 80::ms, 0.0, 10::ms);
    
    // Main trigger function
    fun void trigger(int velocity, int modeParam) {
        // Scale volume by velocity
        (velocity / 127.0) * 0.8 => float vol;
        vol => output.gain;
        
        // Different kick sounds based on mode
        if(modeParam == 0) {
            // Deep sub kick
            40 => Std.mtof => sub.freq;
            0.7 => sub.gain;
            0.1 => mid.gain;
            0.05 => click.gain;
            100 => filter.freq;
            env.set(5::ms, 150::ms, 0.0, 10::ms);
        }
        else if(modeParam == 1) {
            // Punchy techno kick
            60 => Std.mtof => sub.freq;
            0.5 => sub.gain;
            0.4 => mid.gain;
            0.2 => click.gain;
            500 => filter.freq;
            env.set(2::ms, 50::ms, 0.0, 10::ms);
        }
        else if(modeParam == 2) {
            // FM kick
            55 => Std.mtof => sub.freq;
            0.8 => sub.gain;
            0.2 => mid.gain;
            0.1 => click.gain;
            800 => filter.freq;
            
            // FM-style pitch envelope
            spork ~ pitchSweep();
            env.set(1::ms, 100::ms, 0.0, 10::ms);
        }
        else {
            // Glitchy kick
            65 => Std.mtof => sub.freq;
            0.4 => sub.gain;
            0.5 => mid.gain;
            0.3 => click.gain;
            1200 => filter.freq;
            env.set(1::ms, 40::ms, 0.2, 100::ms);
        }
        
        // Trigger the envelope
        1 => env.keyOn;
        300::ms => now;
        1 => env.keyOff;
    }
    
    // Helper function for FM-style pitch sweep
    fun void pitchSweep() {
        200 => float startFreq;
        40 => float endFreq;
        
        startFreq => sub.freq;
        
        // Create quick pitch envelope
        for(0 => int i; i < 30; i++) {
            startFreq - (i * (startFreq - endFreq) / 30) => sub.freq;
            1::ms => now;
        }
        
        endFreq => sub.freq;
    }
}

// Harmonic synth triggered by snare
class SnareSynth {
    // Blend of harmonic and noise elements
    TriOsc osc => ADSR env => Gain output;
    Noise noise => BPF filter => env;
    
    // Add effects
    output => Echo delay => globalRev;
    output => master;
    
    // Configure components
    0.4 => output.gain;
    2000 => filter.freq;
    1.0 => filter.Q;
    
    // Set up delay
    250::ms => delay.max => delay.delay;
    0.3 => delay.mix;
    0.4 => delay.gain;
    
    // Configure envelope
    env.set(2::ms, 60::ms, 0.1, 200::ms);
    
    // Main trigger function
    fun void trigger(int velocity, int modeParam, int noteValue) {
        // Scale volume by velocity
        (velocity / 127.0) * 0.6 => float vol;
        vol => output.gain;
        
        // Calculate the note to play based on the current mode
        determineNote(modeParam, noteValue) => int note;
        
        // Set oscillator frequency based on note
        Std.mtof(note) => osc.freq;
        
        // Different snare characters based on mode
        if(modeParam == 0) {
            // Harmonic snare with little noise
            0.6 => osc.gain;
            0.3 => noise.gain;
            1800 => filter.freq;
            env.set(2::ms, 80::ms, 0.1, 200::ms);
            
            150::ms => delay.delay;
            0.2 => delay.mix;
        }
        else if(modeParam == 1) {
            // More noise-focused snare
            0.3 => osc.gain;
            0.7 => noise.gain;
            3000 => filter.freq;
            env.set(1::ms, 100::ms, 0.0, 150::ms);
            
            200::ms => delay.delay;
            0.4 => delay.mix;
        }
        else if(modeParam == 2) {
            // Short, tight snare
            0.4 => osc.gain;
            0.5 => noise.gain;
            5000 => filter.freq;
            env.set(1::ms, 40::ms, 0.0, 100::ms);
            
            333::ms => delay.delay;
            0.5 => delay.mix;
        }
        else {
            // Long, atmospheric snare
            0.5 => osc.gain;
            0.4 => noise.gain;
            2500 => filter.freq;
            env.set(5::ms, 150::ms, 0.2, 400::ms);
            
            500::ms => delay.delay;
            0.6 => delay.mix;
        }
        
        // Trigger the envelope
        1 => env.keyOn;
        400::ms => now;
        1 => env.keyOff;
    }
    
    // Helper function to determine which note to play
    fun int determineNote(int modeParam, int noteValue) {
        // Different scales/note sets for different modes
        if(modeParam == 0) {
            // C minor pentatonic
            [60, 63, 65, 67, 70, 72, 75, 79] @=> int scale[];
            return scale[noteValue % scale.size()];
        }
        else if(modeParam == 1) {
            // D dorian
            [62, 64, 65, 67, 69, 71, 72, 74] @=> int scale[];
            return scale[noteValue % scale.size()];
        }
        else if(modeParam == 2) {
            // G mixolydian
            [67, 69, 71, 72, 74, 76, 77, 79] @=> int scale[];
            return scale[noteValue % scale.size()];
        }
        else {
            // E phrygian
            [64, 65, 67, 69, 71, 72, 74, 76] @=> int scale[];
            return scale[noteValue % scale.size()];
        }
    }
}

// Bass and texture synth triggered by floor tom
class TomSynth {
    // Main oscillators with waveshaping
    SqrOsc osc => LPF filter => ADSR env => Gain output;
    SawOsc sub => filter;
    
    // Effects chain
    output => Echo echo => globalRev;
    output => master;
    
    // Configure components
    0.6 => output.gain;
    500 => filter.freq;
    2.0 => filter.Q;
    
    // Set up echo
    375::ms => echo.max => echo.delay;
    0.4 => echo.mix;
    0.3 => echo.gain;
    
    // Configure envelope
    env.set(10::ms, 100::ms, 0.6, 300::ms);
    
    // Arrays for harmonic sequence patterns
    [0, 7, 5, 3, 0, 2] @=> int pattern1[];
    [0, 3, 7, 0, 5, 3] @=> int pattern2[];
    [7, 5, 3, 0, 7, 5] @=> int pattern3[];
    [0, 12, 7, 3, 5, 0] @=> int pattern4[];
    
    // Current pattern position
    0 => int patPos;
    
    // Main trigger function
    fun void trigger(int velocity, int modeParam) {
        // Scale volume by velocity
        (velocity / 127.0) * 0.7 => float vol;
        vol => output.gain;
        
        // Select the pattern based on mode
        int pattern[];
        if(modeParam == 0) pattern1 @=> pattern;
        else if(modeParam == 1) pattern2 @=> pattern;
        else if(modeParam == 2) pattern3 @=> pattern;
        else pattern4 @=> pattern;
        
        // Get current note from pattern
        pattern[patPos % pattern.size()] => int step;
        (patPos + 1) % pattern.size() => patPos;
        
        // Base note depends on mode
        int baseNote;
        if(modeParam == 0) 48 => baseNote;
        else if(modeParam == 1) 50 => baseNote;
        else if(modeParam == 2) 53 => baseNote;
        else 46 => baseNote;
        
        // Set oscillator frequencies
        Std.mtof(baseNote + step) => osc.freq;
        Std.mtof(baseNote + step - 12) => sub.freq;
        
        // Different tom/bass characters based on mode
        if(modeParam == 0) {
            // Deep sub bass
            0.4 => osc.gain;
            0.7 => sub.gain;
            400 => filter.freq;
            4.0 => filter.Q;
            env.set(15::ms, 200::ms, 0.5, 400::ms);
            
            250::ms => echo.delay;
            0.2 => echo.mix;
        }
        else if(modeParam == 1) {
            // Punchy mid bass
            0.6 => osc.gain;
            0.4 => sub.gain;
            800 => filter.freq;
            2.0 => filter.Q;
            env.set(5::ms, 100::ms, 0.4, 300::ms);
            
            333::ms => echo.delay;
            0.3 => echo.mix;
        }
        else if(modeParam == 2) {
            // Resonant acid-style bass
            0.7 => osc.gain;
            0.2 => sub.gain;
            1200 => filter.freq;
            8.0 => filter.Q;
            env.set(5::ms, 80::ms, 0.3, 250::ms);
            
            // Filter sweep
            spork ~ filterSweep();
            
            500::ms => echo.delay;
            0.4 => echo.mix;
        }
        else {
            // Atmospheric texture
            0.5 => osc.gain;
            0.5 => sub.gain;
            2000 => filter.freq;
            1.0 => filter.Q;
            env.set(20::ms, 300::ms, 0.7, 800::ms);
            
            666::ms => echo.delay;
            0.6 => echo.mix;
        }
        
        // Trigger the envelope
        1 => env.keyOn;
        600::ms => now;
        1 => env.keyOff;
    }
    
    // Helper function for filter sweep
    fun void filterSweep() {
        500 => float startFreq;
        3000 => float peakFreq;
        800 => float endFreq;
        
        // Up sweep
        for(0 => int i; i < 20; i++) {
            startFreq + (i * (peakFreq - startFreq) / 20) => filter.freq;
            5::ms => now;
        }
        
        // Down sweep
        for(0 => int i; i < 40; i++) {
            peakFreq - (i * (peakFreq - endFreq) / 40) => filter.freq;
            10::ms => now;
        }
        
        endFreq => filter.freq;
    }
}

// Special FX synth for SPD pad triggers
class SPDSynth {
    // Flexible sound generators
    SinOsc sine => ADSR env => PitShift pitch => Gain output;
    SawOsc saw => env;
    TriOsc tri => env;
    Noise noise => BPF bpf => env;
    
    // Effects chain
    output => Chorus chorus => Echo echo => globalRev;
    output => master;
    
    // Configure components
    0.6 => output.gain;
    1.0 => pitch.mix;
    1.0 => pitch.shift;
    
    0.3 => chorus.mix;
    0.5 => chorus.modDepth;
    0.8 => chorus.modFreq;
    
    500::ms => echo.max => echo.delay;
    0.5 => echo.mix;
    0.4 => echo.gain;
    
    2000 => bpf.freq;
    2.0 => bpf.Q;
    
    // Configure envelope
    env.set(10::ms, 100::ms, 0.6, 500::ms);
    
    // Main trigger function - different effects for each SPD pad
    fun void trigger(int padID, int velocity, int modeParam) {
        // Scale volume by velocity
        (velocity / 127.0) * 0.7 => float vol;
        vol => output.gain;
        
        // Customize sound based on which pad was hit (padID 54-62)
        if(padID == 54) {
            // Pad 1: Pitched sound that varies with mode
            if(modeParam == 0) {
                // Chord stab
                spork ~ playChord([60, 64, 67], velocity);
            }
            else if(modeParam == 1) {
                // Melodic ping
                spork ~ playNote(72 + Math.random2(0, 12), velocity);
            }
            else if(modeParam == 2) {
                // Vocoded-style sound
                spork ~ playVocodedSound(velocity);
            }
            else {
                // Wobbly bass
                spork ~ playWobblyBass(velocity);
            }
        }
        else if(padID == 55) {
            // Pad 2: Filter sweep effect
            spork ~ playSweepEffect(velocity, modeParam);
        }
        else if(padID == 56) {
            // Pad 3: Rhythmic glitch
            spork ~ playGlitchEffect(velocity, modeParam);
        }
        else if(padID == 57) {
            // Pad 4: Atmospheric pad
            spork ~ playAtmosphere(velocity, modeParam);
        }
        else if(padID == 58) {
            // Pad 5: Percussive hit
            spork ~ playPercHit(velocity, modeParam);
        }
        else if(padID == 59) {
            // Pad 6: Change mode
            (modeParam + 1) % 4 => mode;
            <<< "Mode changed to:", mode >>>;
            spork ~ playModeIndicator(mode);
        }
        else if(padID == 60) {
            // Pad 7: Reverb splash
            spork ~ playReverbSplash(velocity);
        }
        else if(padID == 61) {
            // Pad 8: Delay feedback burst
            spork ~ playDelayBurst(velocity);
        }
        else if(padID == 62) {
            // Pad 9: Pitch-shifted texture
            spork ~ playPitchTexture(velocity, modeParam);
        }
    }
    
    // Special sound generation functions for SPD pads
    fun void playChord(int notes[], int velocity) {
        // Set oscillator mix
        0.4 => sine.gain;
        0.3 => saw.gain;
        0.2 => tri.gain;
        0.0 => noise.gain;
        
        // Play root note
        Std.mtof(notes[0]) => sine.freq;
        
        // Play 3rd
        Std.mtof(notes[1]) => saw.freq;
        
        // Play 5th
        Std.mtof(notes[2]) => tri.freq;
        
        // Envelope settings
        env.set(5::ms, 100::ms, 0.5, 400::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        500::ms => now;
        1 => env.keyOff;
        100::ms => now;
    }
    
    fun void playNote(int note, int velocity) {
        // Set oscillator mix
        0.6 => sine.gain;
        0.3 => saw.gain;
        0.1 => tri.gain;
        0.0 => noise.gain;
        
        // Set frequency
        Std.mtof(note) => sine.freq;
        Std.mtof(note + 0.02) => saw.freq; // Slight detuning
        Std.mtof(note - 0.02) => tri.freq; // Slight detuning
        
        // Envelope settings
        env.set(10::ms, 50::ms, 0.7, 300::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        400::ms => now;
        1 => env.keyOff;
        100::ms => now;
    }
    
    fun void playVocodedSound(int velocity) {
        // Set oscillator mix
        0.2 => sine.gain;
        0.6 => saw.gain;
        0.1 => tri.gain;
        0.3 => noise.gain;
        
        // Vocoder-like formant frequencies
        440 => sine.freq;
        1200 => saw.freq;
        2500 => tri.freq;
        2000 => bpf.freq;
        
        // Vocoder character with pitch shifter
        0.8 => pitch.shift;
        
        // Envelope settings for vocoder character
        env.set(20::ms, 100::ms, 0.6, 300::ms);
        
        // Apply tremolo effect
        spork ~ applyTremolo(8.0);
        
        // Trigger envelope
        1 => env.keyOn;
        500::ms => now;
        1 => env.keyOff;
        100::ms => now;
        
        // Reset pitch shifter
        1.0 => pitch.shift;
    }
    
    fun void playWobblyBass(int velocity) {
        // Set oscillator mix
        0.2 => sine.gain;
        0.7 => saw.gain;
        0.1 => tri.gain;
        0.0 => noise.gain;
        
        // Bass frequency
        Std.mtof(36) => sine.freq;
        Std.mtof(36 - 0.01) => saw.freq;
        Std.mtof(36 + 0.01) => tri.freq;
        
        // LFO-style wobble with pitch shifter
        spork ~ applyWobble(4.0);
        
        // Envelope settings
        env.set(10::ms, 100::ms, 0.7, 400::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        800::ms => now;
        1 => env.keyOff;
        200::ms => now;
        
        // Reset pitch shifter
        1.0 => pitch.shift;
    }
    
    fun void playSweepEffect(int velocity, int modeParam) {
        // Different sweep types for different modes
        if(modeParam % 2 == 0) {
            // Upward sweep
            spork ~ upwardSweep(velocity);
        }
        else {
            // Downward sweep
            spork ~ downwardSweep(velocity);
        }
    }
    
    fun void upwardSweep(int velocity) {
        // Set oscillator mix
        0.3 => sine.gain;
        0.5 => saw.gain;
        0.2 => tri.gain;
        0.4 => noise.gain;
        
        // Start frequencies
        100 => float startFreq;
        8000 => float endFreq;
        
        startFreq => sine.freq;
        startFreq * 1.01 => saw.freq;
        startFreq * 0.99 => tri.freq;
        startFreq => bpf.freq;
        
        // Wide filter
        0.5 => bpf.Q;
        
        // Envelope settings
        env.set(5::ms, 300::ms, 0.6, 200::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        
        // Perform sweep
        for(0 => int i; i < 60; i++) {
            startFreq * Math.pow(endFreq/startFreq, i/60.0) => float currentFreq;
            currentFreq => sine.freq;
            currentFreq * 1.01 => saw.freq;
            currentFreq * 0.99 => tri.freq;
            currentFreq => bpf.freq;
            10::ms => now;
        }
        
        // Release
        1 => env.keyOff;
        300::ms => now;
    }
    
    fun void downwardSweep(int velocity) {
        // Set oscillator mix
        0.3 => sine.gain;
        0.5 => saw.gain;
        0.2 => tri.gain;
        0.4 => noise.gain;
        
        // Start frequencies
        8000 => float startFreq;
        100 => float endFreq;
        
        startFreq => sine.freq;
        startFreq * 1.01 => saw.freq;
        startFreq * 0.99 => tri.freq;
        startFreq => bpf.freq;
        
        // Narrow filter
        5.0 => bpf.Q;
        
        // Envelope settings
        env.set(5::ms, 50::ms, 0.6, 500::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        
        // Perform sweep
        for(0 => int i; i < 60; i++) {
            startFreq * Math.pow(endFreq/startFreq, i/60.0) => float currentFreq;
            currentFreq => sine.freq;
            currentFreq * 1.01 => saw.freq;
            currentFreq * 0.99 => tri.freq;
            currentFreq => bpf.freq;
            10::ms => now;
        }
        
        // Release
        1 => env.keyOff;
        300::ms => now;
    }
    
    fun void playGlitchEffect(int velocity, int modeParam) {
        // Set oscillator mix
        0.1 => sine.gain;
        0.3 => saw.gain;
        0.1 => tri.gain;
        0.8 => noise.gain;
        
        // Random frequencies
        Math.random2(200, 5000) => bpf.freq;
        Math.random2(8, 30) => bpf.Q;
        
        // Stutter effect with envelope
        for(0 => int i; i < 8; i++) {
            if(i % 2 == 0) {
                1 => env.keyOn;
                Math.random2(200, 8000) => bpf.freq;
                Math.random2f(0.8, 1.2) => pitch.shift;
            }
            else {
                1 => env.keyOff;
                0 => output.gain;
            }
            
            30::ms => now;
            (velocity / 127.0) * 0.7 => output.gain;
        }
        
        // Final envelope release
        1 => env.keyOff;
        200::ms => now;
        
        // Reset pitch shifter
        1.0 => pitch.shift;
    }
    
    fun void playAtmosphere(int velocity, int modeParam) {
        // Set oscillator mix
        0.3 => sine.gain;
        0.3 => saw.gain;
        0.3 => tri.gain;
        0.2 => noise.gain;
        
        // Base frequencies depend on mode
        int baseNote;
        if(modeParam == 0) 60 => baseNote;
        else if(modeParam == 1) 62 => baseNote;
        else if(modeParam == 2) 57 => baseNote;
        else 65 => baseNote;
        
        // Set frequencies for a chord
        Std.mtof(baseNote) => sine.freq;
        Std.mtof(baseNote + 4) => saw.freq; // Major third
        Std.mtof(baseNote + 7) => tri.freq; // Perfect fifth
        
        // Filter the noise component
        Std.mtof(baseNote + 12) => bpf.freq;
        1.0 => bpf.Q;
        
        // Heavy chorus and reverb
        0.8 => chorus.mix;
        1.0 => chorus.modDepth;
        0.2 => chorus.modFreq;
        
        // Slow attack and release
        env.set(300::ms, 400::ms, 0.6, 800::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        1500::ms => now;
        1 => env.keyOff;
        500::ms => now;
        
        // Reset chorus
        0.3 => chorus.mix;
        0.5 => chorus.modDepth;
        0.8 => chorus.modFreq;
    }
    
    fun void playPercHit(int velocity, int modeParam) {
        // Set oscillator mix based on mode
        if(modeParam == 0) {
            // Bell-like
            0.7 => sine.gain;
            0.2 => saw.gain;
            0.1 => tri.gain;
            0.0 => noise.gain;
            
            // Bell frequencies
            Std.mtof(84) => sine.freq;
            Std.mtof(84 + 8) => saw.freq;
            Std.mtof(84 + 15) => tri.freq;
            
            // Metallic envelope
            env.set(1::ms, 40::ms, 0.2, 600::ms);
        }
        else if(modeParam == 1) {
            // Clap-like
            0.0 => sine.gain;
            0.0 => saw.gain;
            0.0 => tri.gain;
            1.0 => noise.gain;
            
            // Clap filter settings
            2000 => bpf.freq;
            1.0 => bpf.Q;
            
            // Short, snappy envelope
            env.set(1::ms, 20::ms, 0.0, 200::ms);
        }
        else if(modeParam == 2) {
            // Wood block
            0.6 => sine.gain;
            0.0 => saw.gain;
            0.2 => tri.gain;
            0.4 => noise.gain;
            
            // Wood block frequencies
            Std.mtof(96) => sine.freq;
            Std.mtof(96 + 19) => tri.freq;
            5000 => bpf.freq;
            10.0 => bpf.Q;
            
            // Very short envelope
            env.set(1::ms, 10::ms, 0.0, 100::ms);
        }
        else {
            // Digital hit
            0.3 => sine.gain;
            0.4 => saw.gain;
            0.2 => tri.gain;
            0.3 => noise.gain;
            
            // Digital frequencies
            Std.mtof(72) => sine.freq;
            Std.mtof(72 * 2.7) => saw.freq; // Non-harmonic
            Std.mtof(72 * 4.5) => tri.freq; // Non-harmonic
            8000 => bpf.freq;
            4.0 => bpf.Q;
            
            // Quick digital envelope
            env.set(1::ms, 30::ms, 0.1, 200::ms);
        }
        
        // Trigger envelope
        1 => env.keyOn;
        300::ms => now;
        1 => env.keyOff;
        200::ms => now;
    }
    
    fun void playModeIndicator(int modeValue) {
        // Simple indicator sound that tells which mode we're in
        // Set oscillator mix
        1.0 => sine.gain;
        0.0 => saw.gain;
        0.0 => tri.gain;
        0.0 => noise.gain;
        
        // Use mode to determine pitch
        if(modeValue == 0) Std.mtof(60) => sine.freq; // C
        else if(modeValue == 1) Std.mtof(62) => sine.freq; // D
        else if(modeValue == 2) Std.mtof(64) => sine.freq; // E
        else Std.mtof(65) => sine.freq; // F
        
        // Simple beep envelope
        env.set(5::ms, 20::ms, 0.6, 100::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        200::ms => now;
        1 => env.keyOff;
        100::ms => now;
    }
    
    fun void playReverbSplash(int velocity) {
        // Set oscillator mix
        0.3 => sine.gain;
        0.3 => saw.gain;
        0.3 => tri.gain;
        0.3 => noise.gain;
        
        // Random frequencies
        Math.random2(1000, 5000) => float baseFreq;
        baseFreq => sine.freq;
        baseFreq * 1.5 => saw.freq;
        baseFreq * 2.1 => tri.freq;
        baseFreq => bpf.freq;
        
        // Heavy reverb
        1.0 => globalRev.mix;
        
        // Short but bright sound
        env.set(1::ms, 30::ms, 0.0, 100::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        100::ms => now;
        1 => env.keyOff;
        100::ms => now;
        
        // Wait a bit before resetting reverb
        500::ms => now;
        0.1 => globalRev.mix;
    }
    
    fun void playDelayBurst(int velocity) {
        // Set oscillator mix
        0.4 => sine.gain;
        0.4 => saw.gain;
        0.2 => tri.gain;
        0.0 => noise.gain;
        
        // Pick a frequency
        Std.mtof(Math.random2(60, 84)) => sine.freq;
        sine.freq() * 1.01 => saw.freq;
        sine.freq() * 0.99 => tri.freq;
        
        // Heavy delay
        0.9 => echo.mix;
        0.8 => echo.gain; // High feedback
        
        // Short sound to create burst
        env.set(1::ms, 10::ms, 0.0, 100::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        50::ms => now;
        1 => env.keyOff;
        50::ms => now;
        
        // Wait for delay to build then decay
        700::ms => now;
        
        // Gradually reduce feedback to avoid endless echoes
        for(0 => int i; i < 10; i++) {
            0.8 - (i * 0.08) => echo.gain;
            100::ms => now;
        }
        
        // Reset echo parameters
        0.5 => echo.mix;
        0.4 => echo.gain;
    }
    
    fun void playPitchTexture(int velocity, int modeParam) {
        // Set oscillator mix
        0.3 => sine.gain;
        0.5 => saw.gain;
        0.2 => tri.gain;
        0.1 => noise.gain;
        
        // Base frequencies
        Std.mtof(72) => sine.freq;
        Std.mtof(72 + 7) => saw.freq;
        Std.mtof(72 + 12) => tri.freq;
        4000 => bpf.freq;
        
        // Envelope settings
        env.set(100::ms, 200::ms, 0.6, 500::ms);
        
        // Trigger envelope
        1 => env.keyOn;
        
        // Pitch shifting pattern
        for(0 => int i; i < 10; i++) {
            // Different pitch patterns for different modes
            if(modeParam == 0) {
                // Rising pitches
                1.0 + (i * 0.04) => pitch.shift;
            }
            else if(modeParam == 1) {
                // Falling pitches
                1.0 - (i * 0.03) => pitch.shift;
            }
            else if(modeParam == 2) {
                // Alternating pitches
                if(i % 2 == 0) 1.2 => pitch.shift;
                else 0.8 => pitch.shift;
            }
            else {
                // Random pitches
                Math.random2f(0.7, 1.3) => pitch.shift;
            }
            
            80::ms => now;
        }
        
        // Release
        1 => env.keyOff;
        500::ms => now;
        
        // Reset pitch shifter
        1.0 => pitch.shift;
    }
    
    // Helper functions for modulation effects
    fun void applyTremolo(float rate) {
        // Save original gain
        output.gain() => float originalGain;
        
        // Duration for one cycle
        (second / rate) => dur cycleDur;
        
        // Apply tremolo for a fixed time
        now + 600::ms => time endTime;
        while(now < endTime) {
            // Tremolo curve (0.3 to 1.0)
            0.3 + 0.7 * Math.sin(((now % cycleDur) / cycleDur) * 2 * Math.PI) => float tremAmp;
            tremAmp * originalGain => output.gain;
            1::ms => now;
        }
        
        // Restore original gain
        originalGain => output.gain;
    }
    
    fun void applyWobble(float rate) {
        // Duration for one cycle
        (second / rate) => dur cycleDur;
        
        // Apply wobble for a fixed time
        now + 800::ms => time endTime;
        while(now < endTime) {
            // LFO curve for pitch shifting (0.8 to 1.2)
            0.8 + 0.4 * Math.sin(((now % cycleDur) / cycleDur) * 2 * Math.PI) => float wobbleAmount;
            wobbleAmount => pitch.shift;
            1::ms => now;
        }
        
        // Reset pitch shifter
        1.0 => pitch.shift;
    }
}

// Create our synth instances
KickSynth kick;
SnareSynth snare;
TomSynth tom;
SPDSynth spd;

// MIDI setup for receiving drum triggers
MidiIn min;
MidiMsg msg;

// Try to open the MIDI device
// Change this number based on your MIDI interface
if(min.open(1)) {
    <<< "MIDI device opened!", "" >>>;
}
else {
    <<< "Failed to open MIDI device...", "" >>>;
    me.exit();
}

// Function to map MIDI notes to different behaviors
fun void midiListener() {
    // Note counter to generate melodic variation
    0 => int noteCounter;
    
    while(true) {
        // Wait on MIDI event
        min => now;
        
        // Get the message
        while(min.recv(msg)) {
                // Extract note number and velocity
                msg.data2 => int note;
                msg.data3 => int velocity;
                
                // Map different drum triggers to different functions
                if(note == 0) { // Kick drum
                    spork ~ kick.trigger(velocity, mode);
                }
                else if(note == 1) { // Snare
                    noteCounter++;
                    spork ~ snare.trigger(velocity, mode, noteCounter);
                }
                else if(note == 2) { // Floor tom
                    spork ~ tom.trigger(velocity, mode);
                }
                else if(note >= 54 && note <= 62) { // SPD pads
                    spork ~ spd.trigger(note, velocity, mode);
                }
        }
    }
}

// Main program
fun void main() {
    // Start MIDI listener in background
    spork ~ midiListener();
    
    // Print initial instructions
    <<< "PercussionSynth loaded!", "" >>>;
    <<< "MIDI Mapping:", "" >>>;
    <<< "- Kick Drum (0): Bass synth sounds", "" >>>;
    <<< "- Snare (1): Harmonic/melodic sounds", "" >>>;
    <<< "- Floor Tom (2): Sequenced bass notes", "" >>>;
    <<< "- SPD Pads (54-62): Various effects and sounds", "" >>>;
    <<< "- SPD Pad 6 (59): Changes sound mode (0-3)", "" >>>;
    
    // Keep program running
    while(true) {
        1::second => now;
    }
}

// Run the main program
main();
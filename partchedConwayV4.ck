/*
* BATTERY: Conway's Game of Life on 15-Limit Just Intonation Tonality Diamond
* Interactive Performance for Solo Drums + Electronics
* 
* ENHANCED COMPREHENSIVE FUNCTIONALITY:
* 
* CORE SYSTEM:
* - 8x8 Conway's Game of Life grid mapped to 15-limit JI tonality diamond frequencies
* - Kick drum (MIDI 0) advances Conway generation and plays resulting chord
* - Five compositional sections evolve over ~12 minutes with increasing complexity
* - Voice leading algorithm ensures smooth chord progressions with stepwise motion
* - Spectral evolution: filters adapt to Conway grid density and activity patterns
* 
* DRUM TRIGGERS:
* - Kick (MIDI 0): Advances Conway, triggers chord with bass note (1-2 octaves down)
* - Snare (MIDI 1): Loud TriOsc synth playing current chord notes with texture bursts
* - Floor Tom (MIDI 2): Quiet SawOsc synth with melodic memory and rhythm recording
* - SPD Pads (MIDI 54-62): Solo notes from current chord with echo and polyrhythms
* 
* VELOCITY SENSITIVITY:
* - Filter cutoffs respond to velocity (harder hits = brighter sounds)
* - Reverb amounts scale with velocity (harder hits = more space)
* - Chord density varies with kick velocity (harder kicks = more voices)
* - Texture effects intensity scales with velocity
* 
* ADAPTIVE SYSTEMS:
* - Generative textures respond to playing activity levels
* - Rhythm echo system records and replays floor tom patterns using shakers
* - Melodic memory system creates harmonic relationships between instruments
* - Life injection prevents Conway grid stagnation with complexity based on section
* 
* SPECTRAL EVOLUTION:
* - Filter frequencies track Conway grid activity and density
* - High activity = brighter, more open filters
* - Low activity = darker, more closed filters
* - Each voice has independent spectral evolution
* - Progressive brightening through sections creates intensity arc
* 
* INTENSITY ARC:
* - Section A (0-60 gen): Sparse, 1-3 voices, 8 kicks to advance
* - Section B (61-120 gen): Building, 3-8 voices, 6 kicks to advance
* - Section C (121-180 gen): Dense, 8-20 voices, 4 kicks to advance
* - Section D (181-240 gen): Complex, 20-40 voices, 2 kicks to advance
* - Section E (241+ gen): Climax, 40-64 voices, 1 kick to advance
*/

// ============================================================================
// GLOBAL CONFIGURATION
// ============================================================================

// Voice and timing constants
64 => int MAX_TOTAL_VOICES;      // Maximum possible voices (full grid)
12 => int MAX_CHORD_VOICES;      // Maximum voices per chord (ChucK limitation)
0.55 => float DEFAULT_GAIN;
0.85 => float MASTER_GAIN;       // Increased for climactic sections

// Fade out configuration
200 => int FADE_START_GENERATION;  // Start fading at generation 200
250 => int FADE_END_GENERATION;    // Complete fade by generation 250

// Timing configuration
3.0 => float SHORT_DURATION;
8.0 => float LONG_DURATION;
16.0 => float TIMEOUT_DURATION;

// Conway grid configuration
220.0 => float BASE_FREQ;
8 => int GRID_WIDTH;
8 => int GRID_HEIGHT;

// Section configuration - 40 generations per section for ~10 minute performance
40 => int GENERATIONS_PER_SECTION;
4 => int STABILITY_THRESHOLD;    // Generations before life injection
0 => int START_SECTION;          // Which section to start in (0-4)
0 => int START_GENERATION;       // Which generation to start at (overrides section if > 0)

// Initial empty grid - life will be injected dynamically
[
[0, 0, 0, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0]
] @=> int INITIAL_PATTERN[][];

// 15-limit Just Intonation Tonality Diamond ratios
[
[15, 8], [7, 4], [5, 3], [14, 9], [3, 2], [32, 21], [5, 3], [15, 8],
[9, 8], [10, 9], [11, 10], [12, 11], [13, 12], [14, 13], [15, 14], [1, 1],
[16, 9], [9, 5], [20, 11], [11, 6], [24, 13], [13, 7], [28, 15], [8, 5],
[18, 11], [5, 3], [22, 13], [11, 7], [8, 5], [26, 15], [6, 5], [16, 13],
[3, 2], [16, 11], [20, 13], [11, 7], [22, 15], [4, 3], [18, 13], [9, 7],
[13, 10], [21, 16], [4, 3], [15, 11], [11, 8], [32, 23], [7, 5], [10, 7],
[13, 9], [16, 11], [22, 15], [3, 2], [20, 13], [14, 9], [11, 7], [19, 12],
[8, 5], [13, 8], [18, 11], [5, 3], [22, 13], [12, 7], [19, 11], [7, 4]
] @=> int DIAMOND_RATIOS[][];

// ============================================================================
// INSTRUMENT CLASSES
// ============================================================================

/**
* Bass synthesizer - provides foundational low-end harmonic support
* Features octave-shifted notes from current chord with velocity-sensitive reverb
*/
class BassSynth extends Chugraph {
    TriOsc osc => ADSR env => PRCRev rev => outlet;
    
    fun void init() {
        env.set(50::ms, 300::ms, 0.3, 3000::ms);
        0.03 => rev.mix;
        DEFAULT_GAIN * 1.0 => osc.gain;
    }
    
    fun void play(float freq, dur duration, float velocity, int section) {
        // Don't play bass in section 0 - wait until section 1
        if(section < 1) return;
        
        freq => osc.freq;
        env.set(50::ms, 300::ms, 0.3, duration);
        
        // Progressive gain increase through sections - CAPPED for section 4
        if(section >= 4) {
            DEFAULT_GAIN * (1.0 + (3 * 0.08)) $ float => osc.gain;  // Cap at section 3 level
        } else {
            DEFAULT_GAIN * (1.0 + (section * 0.08)) $ float => osc.gain;
        }
        
        // Velocity and section affect reverb - CAPPED at section 2 level
        Math.min(section, 2) $ int => int reverbSection;  // Cap section for reverb at 2
        (0.03 + (velocity * 0.03) + (reverbSection * 0.005)) $ float => rev.mix;
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void playMultiOctave(float freq, dur duration, float velocity, int section) {
        // Play bass note in multiple octaves for climactic sections
        play(freq, duration, velocity, section);
        
        if(section >= 4) {
            // Bass doubling goes one octave lower
            spork ~ playOctaveDouble(freq * 0.5, duration, velocity * 0.7, section);   // One octave lower
        }
    }
    
    fun void playOctaveDouble(float freq, dur duration, float velocity, int section) {
        // Removed delay - play immediately for tight timing
        play(freq, duration, velocity, section);
    }
    
    fun void release() {
        150::ms => now;
        env.keyOff();
    }
}

/**
* Chord synthesizer - main harmonic content with voice leading and spectral evolution
* Supports up to MAX_CHORD_VOICES simultaneous voices with progressive filter brightening
*/
class ChordSynth extends Chugraph {
    TriOsc oscs[MAX_CHORD_VOICES];
    ADSR envs[MAX_CHORD_VOICES];
    PRCRev revs[MAX_CHORD_VOICES];
    BiQuad filters[MAX_CHORD_VOICES];
    Pan2 pans[MAX_CHORD_VOICES];
    Gain master => outlet;
    
    // Voice leading state
    float previousFreqs[MAX_CHORD_VOICES];
    int previousVoiceCount;
    
    fun void init() {
        for(0 => int i; i < MAX_CHORD_VOICES; i++) {
            oscs[i] => envs[i] => revs[i] => filters[i] => pans[i] => master;
            
            envs[i].set(50::ms, 300::ms, 0.2, 3000::ms);
            0.03 => revs[i].mix;
            DEFAULT_GAIN * (1.8 - (i * 0.06)) * 0.6 => oscs[i].gain;
            
            // Alternating stereo panning
            if(i % 2 == 0) -0.7 => pans[i].pan;
            else 0.7 => pans[i].pan;
            
            // Initialize filters
            0.97 => filters[i].prad;
            300.0 + (i * 150) => filters[i].pfreq;
            1 => filters[i].eqzs;
            DEFAULT_GAIN * 0.8 => filters[i].gain;
            
            0.0 => previousFreqs[i];
        }
        DEFAULT_GAIN * 0.7 => master.gain;
        0 => previousVoiceCount;
    }
    
    fun void play(float freqs[], int numVoices, dur duration, float velocity, float gridActivity, int section) {
        stop();
        
        // Limit to available oscillators
        Math.min(numVoices, MAX_CHORD_VOICES) $ int => int actualRequestedVoices;
        
        // Voice leading - use previous frequencies for smooth transitions
        float targetFreqs[actualRequestedVoices];
        for(0 => int i; i < actualRequestedVoices; i++) {
            freqs[i] => targetFreqs[i];
        }
        
        if(previousVoiceCount > 0) {
            applyVoiceLeading(targetFreqs, actualRequestedVoices);
        }
        
        // Velocity affects chord density
        Math.min(actualRequestedVoices, Math.max(1, (actualRequestedVoices * velocity) $ int)) $ int => int actualVoices;
        
        for(0 => int i; i < actualVoices; i++) {
            targetFreqs[i] => oscs[i].freq;
            targetFreqs[i] => previousFreqs[i];
            
            envs[i].set(50::ms, 300::ms, 0.2, duration);
            
            // Progressive gain increase through sections - CAPPED for section 4
            if(section >= 4) {
                DEFAULT_GAIN * (1.8 - (i * 0.06)) * (0.6 + (3 * 0.08)) $ float => oscs[i].gain;  // Cap at section 3 level
            } else {
                DEFAULT_GAIN * (1.8 - (i * 0.06)) * (0.6 + (section * 0.08)) $ float => oscs[i].gain;
            }
            
            // Velocity and section affect reverb - CAPPED at section 2 level
            Math.min(section, 2) $ int => int reverbSection;  // Cap section for reverb at 2
            (0.03 + (velocity * 0.02) + (reverbSection * 0.008)) $ float => revs[i].mix;  // Reduced from 0.04 and 0.015
            
            // Spectral evolution based on grid activity and section
            updateSpectralFilter(i, velocity, gridActivity, section);
            
            envs[i].keyOn();
        }
        
        actualVoices => previousVoiceCount;
        spork ~ release(actualVoices);
    }
    
    /**
    * Voice leading algorithm - minimizes voice movement for smooth progressions
    */
    fun void applyVoiceLeading(float targetFreqs[], int numVoices) {
        if(previousVoiceCount == 0) return;
        
        // Create sorted arrays for optimal voice assignment
        float sortedPrev[previousVoiceCount];
        float sortedTarget[numVoices];
        
        // Copy and sort frequencies
        for(0 => int i; i < previousVoiceCount; i++) {
            previousFreqs[i] => sortedPrev[i];
        }
        for(0 => int i; i < numVoices; i++) {
            targetFreqs[i] => sortedTarget[i];
        }
        
        // Simple bubble sort for both arrays
        bubbleSort(sortedPrev, previousVoiceCount);
        bubbleSort(sortedTarget, numVoices);
        
        // Find optimal voice assignments to minimize movement
        for(0 => int i; i < numVoices && i < previousVoiceCount; i++) {
            0 => int bestMatch;
            Math.fabs(sortedTarget[i] - sortedPrev[0]) => float minDistance;
            
            for(0 => int j; j < previousVoiceCount; j++) {
                Math.fabs(sortedTarget[i] - sortedPrev[j]) => float distance;
                if(distance < minDistance) {
                    distance => minDistance;
                    j => bestMatch;
                }
            }
            
            // Prefer stepwise motion when possible
            if(minDistance < (sortedTarget[i] * 0.12)) {
                sortedPrev[bestMatch] => targetFreqs[i];
            }
        }
    }
    
    /**
    * Simple bubble sort implementation
    */
    fun void bubbleSort(float arr[], int size) {
        for(0 => int i; i < size - 1; i++) {
            for(0 => int j; j < size - 1 - i; j++) {
                if(arr[j] > arr[j + 1]) {
                    arr[j] => float temp;
                    arr[j + 1] => arr[j];
                    temp => arr[j + 1];
                }
            }
        }
    }
    
    /**
    * Progressive spectral evolution - filters brighten through sections and with activity
    * FIXED: Capped filter frequencies to prevent shrillness in later sections
    */
    fun void updateSpectralFilter(int voiceIndex, float velocity, float gridActivity, int section) {
        // Base frequency increases through sections - CAPPED to prevent shrillness
        (300.0 + (section * 200.0)) $ float => float sectionBase;  // Reduced from 400.0
        
        // Velocity component (harder hits = brighter) - CAPPED
        sectionBase + (velocity * 800.0) $ float => float baseFreq;  // Reduced from 1500.0
        
        // Grid activity modulation (more active = brighter) - CAPPED
        baseFreq + (gridActivity * 600.0) $ float => float finalFreq;  // Reduced from 1200.0
        
        // Per-voice offset
        finalFreq + (voiceIndex * 80) $ float => float voiceFreq;  // Reduced from 120
        
        // CAP maximum filter frequency to prevent shrillness
        Math.min(voiceFreq, 4000.0) $ float => filters[voiceIndex].pfreq;
        
        // Progressive resonance increase through sections - CAPPED
        (0.95 + (velocity * 0.02) + (section * 0.004)) $ float => float resonance;  // Reduced amounts
        Math.min(resonance, 0.98) $ float => filters[voiceIndex].prad;  // Capped resonance
    }
    
    fun void stop() {
        for(0 => int i; i < MAX_CHORD_VOICES; i++) {
            envs[i].keyOff();
        }
    }
    
    fun void release(int numVoices) {
        150::ms => now;
        for(0 => int i; i < numVoices; i++) {
            envs[i].keyOff();
        }
    }
}

/**
* Snare synthesizer - aggressive textural element with progressive gain increase
*/
class SnareSynth extends Chugraph {
    TriOsc osc => ADSR env => BiQuad filter => PRCRev rev => outlet;
    
    fun void init() {
        env.set(5::ms, 150::ms, 0.3, 300::ms);
        0.95 => filter.prad;
        3500.0 => filter.pfreq;
        2 => filter.eqzs;
        0.08 => rev.mix;
        DEFAULT_GAIN * 2.2 => osc.gain;
        DEFAULT_GAIN * 1.5 => filter.gain;
    }
    
    fun void play(float freq, float velocity, int section) {
        freq => osc.freq;
        
        // Progressive gain increase through sections - CAPPED to prevent harshness
        DEFAULT_GAIN * (2.2 + (section * 0.15)) $ float => float gainValue;  // Reduced from 0.3
        Math.min(gainValue, DEFAULT_GAIN * 3.5) $ float => osc.gain;  // Capped gain
        
        // Velocity and section affect filter cutoff - CAPPED
        (3500.0 + (velocity * 3000.0) + (section * 400.0)) $ float => float filterFreq;  // Reduced amounts
        Math.min(filterFreq, 8000.0) $ float => filter.pfreq;  // Capped filter frequency
        
        // Velocity and section affect reverb - REDUCED
        (0.08 + (velocity * 0.08) + (section * 0.01)) $ float => rev.mix;  // Reduced from 0.12 and 0.02
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void release() {
        120::ms => now;
        env.keyOff();
    }
}

/**
* Floor tom synthesizer - melodic memory system with saw wave character
*/
class FloorTomSynth extends Chugraph {
    SawOsc osc => ADSR env => BiQuad filter => PRCRev rev => outlet;
    
    fun void init() {
        env.set(10::ms, 200::ms, 0.4, 500::ms);
        0.95 => filter.prad;
        900.0 => filter.pfreq;
        2 => filter.eqzs;
        0.05 => rev.mix;
        DEFAULT_GAIN * 0.3 => osc.gain;
        DEFAULT_GAIN * 0.4 => filter.gain;
    }
    
    fun void play(float freq, float velocity, int section) {
        freq => osc.freq;
        
        // Progressive gain increase through sections - CAPPED for section 4
        if(section >= 4) {
            DEFAULT_GAIN * (0.3 + (3 * 0.05)) $ float => osc.gain;  // Cap at section 3 level
        } else {
            DEFAULT_GAIN * (0.3 + (section * 0.05)) $ float => osc.gain;
        }
        
        // Velocity and section affect filter cutoff - CAPPED for section 4
        if(section >= 4) {
            (900.0 + (velocity * 1500.0) + (3 * 300.0)) $ float => filter.pfreq;  // Cap at section 3 level
        } else {
            (900.0 + (velocity * 1500.0) + (section * 300.0)) $ float => filter.pfreq;
        }
        
        // Velocity and section affect reverb - CAPPED at section 2 level
        Math.min(section, 2) $ int => int reverbSection;  // Cap section for reverb at 2
        (0.05 + (velocity * 0.05) + (reverbSection * 0.008)) $ float => rev.mix;  // Reduced from 0.08 and 0.015
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void release() {
        80::ms => now;
        env.keyOff();
    }
}

/**
* SPD pad synthesizer - solo melodic notes with echo and progressive complexity
*/
class SPDSynth extends Chugraph {
    PulseOsc osc => ADSR env => Echo echo => PRCRev rev => outlet;
    
    fun void init() {
        env.set(5::ms, 100::ms, 0.5, 400::ms);
        250::ms => echo.max => echo.delay;
        0.3 => echo.mix;
        0.4 => echo.gain;
        0.05 => rev.mix;
        DEFAULT_GAIN * 0.5 => osc.gain;
    }
    
    fun void play(float freq, float velocity, int section) {
        freq => osc.freq;
        
        // Progressive gain increase through sections - MUCH MORE REDUCED for section 3+
        if(section >= 3) {
            DEFAULT_GAIN * (0.5 + (1 * 0.04)) $ float => osc.gain;  // Much quieter, cap at section 1 level
        } else {
            DEFAULT_GAIN * (0.5 + (section * 0.08)) $ float => osc.gain;
        }
        
        // Velocity and section affect echo feedback
        (0.4 + (velocity * 0.4) + (section * 0.1)) $ float => echo.gain;
        
        // Velocity and section affect reverb - CAPPED at section 2 level for normal sections
        Math.min(section, 2) $ int => int reverbSection;  // Cap section for reverb at 2
        if(section >= 4) {
            (0.05 + (velocity * 0.03) + (reverbSection * 0.005)) $ float => rev.mix;  // Much less reverb in section 4
        } else {
            (0.05 + (velocity * 0.06) + (reverbSection * 0.01)) $ float => rev.mix;
        }
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void playPolyrhythmic(float freq, float velocity, int section) {
        // Always play the main note first
        play(freq, velocity, section);
        
        // Only add polyrhythmic notes in section 4+ (and only occasionally)
        if(section >= 4 && Math.random2(0, 3) == 0) {
            spork ~ delayedNote(freq * 1.5, velocity * 0.8, section, 50::ms);
            spork ~ delayedNote(freq * 0.75, velocity * 0.6, section, 100::ms);
            spork ~ delayedNote(freq * 2.0, velocity * 0.7, section, 150::ms);
        }
    }
    
    fun void delayedNote(float freq, float velocity, int section, dur delay) {
        delay => now;
        play(freq, velocity, section);
    }
    
    fun void release() {
        100::ms => now;
        env.keyOff();
    }
}

/**
* Texture generator - ambient textures with increasing density through sections
*/
class TextureGenerator extends Chugraph {
    Noise noise => BPF filter => ADSR env => PRCRev rev => outlet;
    Impulse click => ADSR clickEnv => HPF clickFilter => rev;
    SinOsc rumble => ADSR rumbleEnv => LPF rumbleFilter => rev;
    
    fun void init() {
        env.set(200::ms, 800::ms, 0.2, 1500::ms);
        1200.0 => filter.freq;
        3.0 => filter.Q;
        0.15 => rev.mix;
        DEFAULT_GAIN * 0.08 => noise.gain;
        
        clickEnv.set(1::ms, 5::ms, 0.0, 10::ms);
        5500.0 => clickFilter.freq;
        2.0 => clickFilter.Q;
        DEFAULT_GAIN * 0.4 => click.gain;
        
        rumbleEnv.set(500::ms, 1000::ms, 0.4, 2000::ms);
        85.0 => rumbleFilter.freq;
        1.0 => rumbleFilter.Q;
        DEFAULT_GAIN * 0.15 => rumble.gain;
    }
    
    fun void burst(float velocity, int section) {
        // Progressive frequency range and gain through sections - CAPPED
        Math.random2f(600, 3500) + (velocity * 1500.0) + (section * 300.0) $ float => float burstFreq;  // Reduced amounts
        Math.min(burstFreq, 6000.0) $ float => filter.freq;  // Capped frequency
        
        Math.random2f(2.0, 6.0) + (velocity * 2.0) $ float => filter.Q;  // Reduced Q range
        // Texture reverb - CAPPED at section 2 level
        Math.min(section, 2) $ int => int reverbSection;  // Cap section for reverb at 2
        (0.15 + (velocity * 0.06) + (reverbSection * 0.01)) $ float => rev.mix;
        
        DEFAULT_GAIN * (0.08 + (section * 0.02)) $ float => noise.gain;  // Reduced gain increase
        
        env.keyOn();
        spork ~ releaseBurst();
    }
    
    fun void clickSound(float velocity, int section) {
        Math.random2f(4000, 8000) + (velocity * 1500.0) + (section * 300.0) $ float => float clickFreq;  // Reduced amounts
        Math.min(clickFreq, 10000.0) $ float => clickFilter.freq;  // Capped frequency
        
        DEFAULT_GAIN * (0.4 + (section * 0.05)) $ float => click.gain;  // Reduced gain increase
        
        1.0 => click.next;
        clickEnv.keyOn();
        spork ~ releaseClick();
    }
    
    fun void rumbleSound(float velocity, float baseFreq, int section) {
        baseFreq * 0.25 $ float => rumble.freq;
        DEFAULT_GAIN * (0.15 + (section * 0.05)) $ float => rumble.gain;
        
        // Texture reverb - CAPPED at section 2 level
        Math.min(section, 2) $ int => int reverbSection;  // Cap section for reverb at 2
        (0.15 + (velocity * 0.06) + (reverbSection * 0.01)) $ float => rev.mix;
        
        rumbleEnv.keyOn();
        spork ~ releaseRumble();
    }
    
    fun void releaseBurst() {
        Math.random2(250, 700)::ms => now;
        env.keyOff();
    }
    
    fun void releaseClick() {
        12::ms => now;
        clickEnv.keyOff();
    }
    
    fun void releaseRumble() {
        Math.random2(700, 1300)::ms => now;
        rumbleEnv.keyOff();
    }
}

/**
* Rhythm echo system - records and replays floor tom patterns
*/
class RhythmEcho extends Chugraph {
    Shakers shaker => PRCRev rev => outlet;
    float rhythmTimes[32];
    0 => int rhythmIndex;
    now => time startTime;
    0 => int hasStarted;
    
    fun void init() {
        7 => shaker.which;
        0.12 => rev.mix;
        DEFAULT_GAIN * 0.7 => shaker.gain;
        
        for(0 => int i; i < rhythmTimes.size(); i++) {
            0.0 => rhythmTimes[i];
        }
    }
    
    fun void recordHit() {
        if(hasStarted == 0) {
            now => startTime;
            1 => hasStarted;
            0.0 => rhythmTimes[rhythmIndex];
        } else {
            (now - startTime) / 1::second => rhythmTimes[rhythmIndex];
        }
        (rhythmIndex + 1) % rhythmTimes.size() => rhythmIndex;
    }
    
    fun void playback(float speed, int section) {
        if(rhythmIndex < 2) return;
        
        // Progressive gain increase through sections
        DEFAULT_GAIN * (0.7 + (section * 0.05)) $ float => shaker.gain;  // Reduced from 0.08
        
        0 => int startIndex;
        rhythmIndex => int endIndex;
        if(rhythmIndex > 8) rhythmIndex - 8 => startIndex;
        
        for(0 => int i; i < (endIndex - startIndex - 1); i++) {
            (startIndex + i) % rhythmTimes.size() => int currentIdx;  
            (startIndex + i + 1) % rhythmTimes.size() => int nextIdx;
            
            rhythmTimes[nextIdx] - rhythmTimes[currentIdx] => float interval;
            
            if(interval > 0.04 && interval < 4.5) {
                Math.random2(5, 12) => shaker.which;
                Math.random2f(70, 140) + (section * 15) $ float => shaker.freq;
                Math.random2f(25, 90) + (section * 10) $ float => shaker.objects;
                shaker.noteOn(Math.random2f(8, 20) + (section * 3) $ float);
                
                (interval / speed)::second => now;
            }
        }
    }
}

// ============================================================================
// CONWAY'S GAME OF LIFE ENGINE
// ============================================================================

/**
* Enhanced Conway engine with progressive complexity and life injection
*/
class ConwayEngine {
    int grid[GRID_HEIGHT][GRID_WIDTH];
    int nextGrid[GRID_HEIGHT][GRID_WIDTH];
    
    // State tracking
    0 => int generation;
    0 => int stableCount;
    0 => int currentSection;
    0 => int totalGenerations;
    
    fun void init() {
        // Initialize with empty grid - life will be injected
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                INITIAL_PATTERN[y][x] => grid[y][x];
            }
        }
        
        // Set starting generation and section
        if(START_GENERATION > 0) {
            // Use specific generation override
            START_GENERATION => totalGenerations;
            START_GENERATION / GENERATIONS_PER_SECTION => currentSection;
            START_GENERATION % GENERATIONS_PER_SECTION => generation;
        } else {
            // Use section-based start
            START_SECTION => currentSection;
            START_SECTION * GENERATIONS_PER_SECTION => totalGenerations;
            0 => generation;  // Reset generation counter for current section
        }
        
        // Inject initial life pattern
        injectSimplePattern();
        
        // Print starting info
        if(START_GENERATION > 0 || START_SECTION > 0) {
            <<< "=== STARTING AT GENERATION", totalGenerations, "SECTION", currentSection, "===" >>>;
            printSectionChange();
        }
    }
    
    fun int countNeighbors(int y, int x) {
        0 => int count;
        for(-1 => int dy; dy <= 1; dy++) {
            for(-1 => int dx; dx <= 1; dx++) {
                if(dy == 0 && dx == 0) continue;
                
                (y + dy + GRID_HEIGHT) % GRID_HEIGHT => int ny;
                (x + dx + GRID_WIDTH) % GRID_WIDTH => int nx;
                count + grid[ny][nx] => count;
            }
        }
        return count;
    }
    
    fun float getGridActivity() {
        0 => int livingCells;
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                livingCells + grid[y][x] => livingCells;
            }
        }
        return livingCells / 64.0; // Normalize to 0-1
    }
    
    fun void nextGeneration() {
        // Apply Conway's rules
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                countNeighbors(y, x) => int neighbors;
                
                if(grid[y][x] == 1) {
                    // Living cell survives with 2 or 3 neighbors
                    if(neighbors == 2 || neighbors == 3) 1 => nextGrid[y][x];
                    else 0 => nextGrid[y][x];
                } else {
                    // Dead cell becomes alive with exactly 3 neighbors
                    if(neighbors == 3) 1 => nextGrid[y][x];
                    else 0 => nextGrid[y][x];
                }
            }
        }
        
        // Check for changes
        1 => int hasChanged;
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                if(nextGrid[y][x] != grid[y][x]) {
                    0 => hasChanged;
                    break;
                }
            }
            if(hasChanged == 0) break;
        }
        
        // Update grid
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                nextGrid[y][x] => grid[y][x];
            }
        }
        
        // Update counters
        generation++;
        totalGenerations++;
        updateSection();
        
        // Track stability for life injection
        if(hasChanged == 1) stableCount + 1 => stableCount;
        else 0 => stableCount;
        
        // Inject life if grid becomes too stable
        0 => int injected;
        getDynamicStabilityThreshold() => int threshold;
        if(stableCount >= threshold) {
            injectLife();
            0 => stableCount;
            1 => injected;
        }
        
        printGrid(injected, 0);  // Pass 0 since activeVoices not accessible here
    }
    
    /**
    * Updates current section based on total generations
    */
    fun void updateSection() {
        totalGenerations / GENERATIONS_PER_SECTION => int newSection;
        Math.min(newSection, 4) $ int => newSection; // 5 sections (0-4)
        
        if(newSection != currentSection) {
            newSection => currentSection;
            printSectionChange();
        }
    }
    
    fun void printSectionChange() {
        if(currentSection == 0) <<< "=== SECTION A: Sparse Foundation (1-3 voices) ===" >>>;
        else if(currentSection == 1) <<< "=== SECTION B: Building Energy (3-8 voices) ===" >>>;
        else if(currentSection == 2) <<< "=== SECTION C: Dense Complexity (8-20 voices) ===" >>>;
        else if(currentSection == 3) <<< "=== SECTION D: Approaching Climax (20-40 voices) ===" >>>;
        else <<< "=== SECTION E: CLIMACTIC FINALE (40-64 voices) ===" >>>;
    }
    
    /**
    * Returns kick advance requirement for current section
    */
    fun int getKicksToAdvance() {
        if(currentSection == 0) return 8;      // Slow, meditative
        else if(currentSection == 1) return 6; // Building momentum
        else if(currentSection == 2) return 4; // Increasing urgency
        else if(currentSection == 3) return 2; // High energy
        else return 1;                         // Climactic - every kick advances
    }
    
    /**
    * Dynamic stability threshold - decreases over time for more activity and density
    */
    fun int getDynamicStabilityThreshold() {
        // Base threshold decreases as total generations increase
        (totalGenerations / 50) $ int => int reductionFactor;  // Reduce threshold every 50 generations
        (STABILITY_THRESHOLD - reductionFactor) $ int => int dynamicThreshold;
        
        // Additional section-based reduction
        if(currentSection <= 1) dynamicThreshold => dynamicThreshold;
        else if(currentSection == 2) (dynamicThreshold - 1) $ int => dynamicThreshold;
        else (dynamicThreshold - 2) $ int => dynamicThreshold;
        
        // Never go below 1 for stability
        Math.max(dynamicThreshold, 1) $ int => dynamicThreshold;
        
        return dynamicThreshold;
    }
    
    /**
    * Progressive life injection based on current section - ENHANCED: Gets denser over time
    */
    fun void injectLife() {
        // Increase injection frequency and complexity based on total generations
        totalGenerations / 30 => int densityLevel;  // 0-5+ density levels
        
        if(currentSection == 0) {
            injectSimplePattern();
        } else if(currentSection == 1) {
            if(Math.random2(0, 1) == 0) injectSimplePattern();
            else injectMediumPattern();
        } else if(currentSection == 2) {
            if(Math.random2(0, 2) == 0) injectMediumPattern();
            else injectComplexPattern();
            
            // Additional pattern for higher density
            if(densityLevel >= 3 && Math.random2(0, 3) == 0) {
                injectMediumPattern();
            }
        } else if(currentSection == 3) {
            // Multiple patterns for high energy - density increases over time
            for(0 => int i; i < Math.random2(1, 2 + densityLevel); i++) {
                if(Math.random2(0, 1) == 0) injectMediumPattern();
                else injectComplexPattern();
            }
        } else {
            // Climactic section - life bursts get more intense over time
            for(0 => int i; i < Math.random2(2, 4 + densityLevel); i++) {
                if(Math.random2(0, 2) == 0) injectComplexPattern();
                else injectChaosPattern();
            }
            
            // Extra chaos for very high density levels
            if(densityLevel >= 4) {
                for(0 => int i; i < Math.random2(1, 3); i++) {
                    injectChaosPattern();
                }
            }
        }
    }
    
    /**
    * Simple glider pattern
    */
    fun void injectSimplePattern() {
        Math.random2(0, GRID_HEIGHT - 3) => int startY;
        Math.random2(0, GRID_WIDTH - 3) => int startX;
        
        1 => grid[startY][startX + 1];
        1 => grid[startY + 1][startX + 2];  
        1 => grid[startY + 2][startX];
        1 => grid[startY + 2][startX + 1];
        1 => grid[startY + 2][startX + 2];
    }
    
    /**
    * Medium complexity pattern
    */
    fun void injectMediumPattern() {
        Math.random2(1, GRID_HEIGHT - 4) => int startY;
        Math.random2(1, GRID_WIDTH - 4) => int startX;
        
        1 => grid[startY][startX + 1];
        1 => grid[startY][startX + 2];
        1 => grid[startY + 1][startX];
        1 => grid[startY + 1][startX + 1];
        1 => grid[startY + 2][startX + 1];
        1 => grid[startY + 3][startX + 1];
    }
    
    /**
    * Complex oscillating pattern
    */
    fun void injectComplexPattern() {
        Math.random2(1, GRID_HEIGHT - 5) => int startY;
        Math.random2(1, GRID_WIDTH - 5) => int startX;
        
        1 => grid[startY][startX + 2];
        1 => grid[startY][startX + 3];
        1 => grid[startY + 1][startX + 1];
        1 => grid[startY + 1][startX + 4];
        1 => grid[startY + 2][startX];
        1 => grid[startY + 2][startX + 5];
        1 => grid[startY + 3][startX + 2];
        1 => grid[startY + 3][startX + 3];
    }
    
    /**
    * Chaotic pattern for climactic sections
    */
    fun void injectChaosPattern() {
        Math.random2(1, GRID_HEIGHT - 6) => int startY;
        Math.random2(1, GRID_WIDTH - 6) => int startX;
        
        // Dense random-ish pattern
        for(0 => int dy; dy < 4; dy++) {
            for(0 => int dx; dx < 4; dx++) {
                if(Math.random2(0, 2) == 0) {
                    1 => grid[startY + dy][startX + dx];
                }
            }
        }
    }
    
    /**
    * Returns array of living cell indices
    */
    fun int[] getLivingCells() {
        int livingCells[64];
        0 => int count;
        
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                if(grid[y][x] == 1) {
                    y * GRID_WIDTH + x => livingCells[count];
                    count++;
                }
            }
        }
        
        int result[count];
        for(0 => int i; i < count; i++) {
            livingCells[i] => result[i];
        }
        return result;
    }
    
    /**
    * Debug output
    */
    fun void printGrid(int injected, int voices) {
        for(0 => int y; y < GRID_HEIGHT; y++) {
            "" => string row;
            for(0 => int x; x < GRID_WIDTH; x++) {
                if(grid[y][x] == 1) row + "1 " => row;
                else row + "0 " => row;
            }
            <<< row >>>;
        }
        
        if(injected == 1) <<< "*** LIFE INJECTED ***" >>>;
        <<< "Generation: " + generation + " | Total: " + totalGenerations + " | Section: " + currentSection + " | Living: " + getLivingCells().size() >>>;
        <<< "================================================" >>>;
    }
}

// ============================================================================
// MAIN PERFORMANCE SYSTEM
// ============================================================================

/**
* Global state variables
*/
// Frequency lookup table
float diamondFreqs[64];

// Core systems
ConwayEngine conway;

// Performance state
int melodicMemory[16];
0 => int memoryIndex;
0 => int activeVoices;
float chordDuration;
0 => int kickCount;
now => time chordStartTime;
0 => int hasKickedOnce;
now => time lastKickTime;

// Activity tracking for generative systems
0 => int kickActivity;
0 => int snareActivity;
0 => int floorTomActivity;
0 => int spdActivity;

// Audio chain with fade control
Gain master => Gain fadeGain => Dyno limiter => JCRev masterReverb => dac;
MASTER_GAIN => master.gain;
1.0 => fadeGain.gain;  // Will be controlled by fade multiplier

// Limiter settings
limiter.limit();
0.6 => limiter.thresh;
0.08 => limiter.slopeAbove;
4::ms => limiter.attackTime;
180::ms => limiter.releaseTime;

// Instrument instances
BassSynth bass;
ChordSynth chord;  
SnareSynth snare;
FloorTomSynth floorTom;
SPDSynth spd;
TextureGenerator texture;
RhythmEcho rhythmEcho;

// Connect instruments to master
bass => master;
chord => master;
snare => master;
floorTom => master;
spd => master;
texture => master;
rhythmEcho => master;

// MIDI setup
MidiIn min;
MidiMsg msg;

/**
* MIDI device setup - looks for SPD-SX drum pad
*/
fun void setupMidi() {
    [0,1,2,3,4,5] @=> int ports[];
    for(0 => int i; i < ports.size(); i++){
        if(min.open(ports[i])) {
            <<< "MIDI device connected:", min.name() >>>;
            if(min.name() == "SPD-SX") {
                <<< "SPD-SX detected and connected!" >>>;
                break;
            }
        }
    }
}

/**
* Calculate all 64 frequencies for the tonality diamond
*/
fun void calculateFrequencies() {
    for(0 => int i; i < 64; i++) {
        i / 8 => int row;
        i % 8 => int col;
        
        // Calculate frequency from ratio
        BASE_FREQ * DIAMOND_RATIOS[row * 8 + col][0] / DIAMOND_RATIOS[row * 8 + col][1] => diamondFreqs[i];
        
        // Ensure frequencies are in reasonable range
        while(diamondFreqs[i] < BASE_FREQ * 0.4) diamondFreqs[i] * 2.0 => diamondFreqs[i];
        while(diamondFreqs[i] > BASE_FREQ * 5.0) diamondFreqs[i] / 2.0 => diamondFreqs[i];
    }
    
    <<< "Tonality diamond frequencies calculated" >>>;
}

/**
* Initialize all systems
*/
fun void init() {
    <<< "=== BATTERY: Conway Life JI Performance System ===" >>>;
    if(START_GENERATION > 0) {
        <<< "Starting generation:", START_GENERATION >>>;
    } else {
        <<< "Starting section:", START_SECTION >>>;
    }
    
    setupMidi();
    calculateFrequencies();
    conway.init();
    
    // Initialize instruments
    bass.init();
    chord.init();
    snare.init();
    floorTom.init();
    spd.init();
    texture.init();
    rhythmEcho.init();
    
    // Initial performance state - adjusted for starting section
    Math.max(1, START_SECTION + 1) $ int => activeVoices;  // Start with appropriate voice count
    SHORT_DURATION => chordDuration;
    
    // Clear melodic memory
    for(0 => int i; i < melodicMemory.size(); i++) {
        0 => melodicMemory[i];
    }
    
    // Set initial master reverb based on starting section
    updateMasterReverb();
    updateActiveVoices();  // Calculate correct voice count for starting section
    
    // Play initial chord
    playCurrentChord(0.5);
    
    <<< "System initialized - ready for performance!" >>>;
}

/**
* Calculate fade multiplier based on total generations
*/
fun float getFadeMultiplier() {
    if(conway.totalGenerations < FADE_START_GENERATION) {
        return 1.0;  // No fade
    } else if(conway.totalGenerations >= FADE_END_GENERATION) {
        return 0.0;  // Complete fade
    } else {
        // Linear fade between start and end
        (FADE_END_GENERATION - conway.totalGenerations) / (FADE_END_GENERATION - FADE_START_GENERATION) $ float => float fadeMultiplier;
        return fadeMultiplier;
    }
}
fun void updateMasterReverb() {
    if(conway.currentSection == 0) 0.03 => masterReverb.mix;
    else if(conway.currentSection == 1) 0.05 => masterReverb.mix;  
    else if(conway.currentSection == 2) 0.08 => masterReverb.mix;
    else if(conway.currentSection == 3) 0.12 => masterReverb.mix;
    else 0.16 => masterReverb.mix; // Climactic section
}

/**
* Dynamic voice count calculation based on section and generation
*/
fun void updateActiveVoices() {
    // Simple: 1 voice + 1 more every 10 generations
    1 + (conway.totalGenerations / 10) => activeVoices;
    
    // Cap at maximum
    if(activeVoices > 64) 64 => activeVoices;
    
    // Absolute safety: never negative
    if(activeVoices < 1) 1 => activeVoices;
    
    updateMasterReverb();
}

/**
* Calculate how many chord voices to use from available living cells
*/
fun int getChordVoiceCount(int livingCellCount) {
    // Start with 1 chord voice, add 1 more every 20 generations
    1 + (conway.totalGenerations / 20) => int chordVoices;
    
    // Cap by available living cells and MAX_CHORD_VOICES
    Math.min(chordVoices, livingCellCount) $ int => chordVoices;
    Math.min(chordVoices, MAX_CHORD_VOICES) $ int => chordVoices;
    
    // Never less than 1
    Math.max(chordVoices, 1) $ int => chordVoices;
    
    return chordVoices;
}

/**
* Main chord playing function with voice limiting for ChucK
*/
fun void playCurrentChord(float velocity) {
    conway.getLivingCells() @=> int livingCells[];
    conway.getGridActivity() => float gridActivity;
    
    // Handle empty grid case
    if(livingCells.size() == 0) {
        bass.playMultiOctave(BASE_FREQ, chordDuration::second, velocity, conway.currentSection);
        return;
    }
    
    // Sort living cells by frequency for voice leading
    int sortedCells[livingCells.size()];
    for(0 => int i; i < livingCells.size(); i++) {
        livingCells[i] => sortedCells[i];
    }
    
    // Simple insertion sort by frequency
    for(0 => int i; i < sortedCells.size(); i++) {
        sortedCells[i] => int key;
        diamondFreqs[key] => float keyFreq;
        i - 1 => int j;
        
        while(j >= 0 && diamondFreqs[sortedCells[j]] > keyFreq) {
            sortedCells[j] => sortedCells[j + 1];
            j--;
        }
        key => sortedCells[j + 1];
    }
    
    // Play bass note
    if(sortedCells.size() > 0) {
        Math.random2(0, sortedCells.size() - 1) => int bassNoteIdx;
        Math.random2(1, 2) => int bassOctaveDown;
        diamondFreqs[sortedCells[bassNoteIdx]] / Math.pow(2, bassOctaveDown) => float bassFreq;
        bass.playMultiOctave(bassFreq, chordDuration::second, velocity, conway.currentSection);
    }
    
    // Determine voices to play (limited by available oscillators) - FIXED: Added bounds checking
    getChordVoiceCount(sortedCells.size()) => int voicesToPlay;
    
    // SAFETY CHECK: Ensure voicesToPlay is positive
    Math.max(voicesToPlay, 1) $ int => voicesToPlay;
    
    if(voicesToPlay <= 0) {
        <<< "WARNING: voicesToPlay is", voicesToPlay, "- skipping chord" >>>;
        return;
    }
    
    // Create frequency array for chord
    float chordFreqs[voicesToPlay];
    for(0 => int i; i < voicesToPlay; i++) {
        diamondFreqs[sortedCells[i]] => chordFreqs[i];
    }
    
    // Play chord
    chord.play(chordFreqs, voicesToPlay, chordDuration::second, velocity, gridActivity, conway.currentSection);
}

/**
* Check if Conway generation should advance
*/
fun int shouldAdvance() {
    if(kickCount >= conway.getKicksToAdvance()) return 1;
    if(now - chordStartTime >= chordDuration::second) return 1;
    return 0;
}

/**
* Reset timing counters
*/
fun void resetTiming() {
    0 => kickCount;
    now => chordStartTime;
}

/**
* Update chord duration based on activity
*/
fun void updateChordDuration() {
    if(hasKickedOnce == 0) {
        SHORT_DURATION => chordDuration;
    } else {
        if(now - lastKickTime >= TIMEOUT_DURATION::second) {
            SHORT_DURATION => chordDuration;
            0 => hasKickedOnce;
        } else {
            LONG_DURATION => chordDuration;
        }
    }
}

/**
* Melodic memory system for related note selection
*/
fun void addToMelodyMemory(int note) {
    note => melodicMemory[memoryIndex];
    (memoryIndex + 1) % melodicMemory.size() => memoryIndex;
}

fun int getRelatedNote(int currentNote) {
    for(0 => int i; i < melodicMemory.size(); i++) {
        melodicMemory[i] => int memNote;
        if(memNote > 0) {
            // Check for fifth relationship
            if(Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.5) < 0.12) {
                return memNote;
            }
            // Check for fourth relationship  
            if(Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.333) < 0.12) {
                return memNote;
            }
            // Check for octave relationship
            if(Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 2.0) < 0.12) {
                return memNote;
            }
        }
    }
    return currentNote;
}

/**
* Main MIDI handler with progressive complexity
*/
fun void handleMidi(int midiNote, int velocity) {
    (velocity / 127.0) => float vel;
    
    if(midiNote == 0) {
        // KICK DRUM - advances Conway and triggers chord
        kickCount++;
        kickActivity++;
        now => lastKickTime;
        
        // High velocity rumble for powerful kicks
        if(velocity > 85) {
            conway.getLivingCells() @=> int livingCells[];
            if(livingCells.size() > 0) {
                texture.rumbleSound(vel, diamondFreqs[livingCells[0]], conway.currentSection);
            } else {
                texture.rumbleSound(vel, BASE_FREQ, conway.currentSection);
            }
        }
        
        // Update activity state
        if(hasKickedOnce == 0) {
            1 => hasKickedOnce;
            updateChordDuration();
        }
        
        // Advance Conway if conditions met
        if(shouldAdvance()) {
            conway.nextGeneration();
            updateActiveVoices();
            // Update fade based on generation count
            getFadeMultiplier() => fadeGain.gain;
            
            playCurrentChord(vel);
            resetTiming();
        }
        
    } else if(midiNote == 1) {
        // SNARE - textural bursts with related harmonies
        snareActivity++;
        conway.getLivingCells() @=> int livingCells[];
        
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIdx;
            livingCells[randomIdx] => int selectedNote;
            
            // Use melodic memory in later sections
            if(conway.currentSection >= 1 && melodicMemory[memoryIndex] > 0) {
                getRelatedNote(melodicMemory[memoryIndex]) => selectedNote;
            }
            
            // Progressive octave range through sections
            Math.random2(-1, 1 + conway.currentSection) => int octaveOffset;
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            snare.play(freq, 2.8 * vel, conway.currentSection);
        }
        
        // Texture generation with increasing probability
        texture.burst(vel, conway.currentSection);
        if(Math.random2(0, 3 - conway.currentSection) == 0) {
            texture.clickSound(vel, conway.currentSection);
        }
        
    } else if(midiNote == 2) {
        // FLOOR TOM - melodic memory system
        floorTomActivity++;
        rhythmEcho.recordHit();
        
        conway.getLivingCells() @=> int livingCells[];
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIdx;
            livingCells[randomIdx] => int selectedNote;
            
            // Apply harmonic relationships in complex sections
            if(conway.currentSection >= 2) {
                getRelatedNote(selectedNote) => selectedNote;
            }
            
            addToMelodyMemory(selectedNote);
            
            // Progressive octave range
            Math.random2(1, 2 + conway.currentSection) => int octaveOffset;
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            floorTom.play(freq, 1.6 * vel, conway.currentSection);
        }
        
        // Occasional texture clicks
        if(Math.random2(0, 2) == 0) {
            texture.clickSound(vel, conway.currentSection);
        }
        
    } else if(midiNote >= 54 && midiNote <= 62) {
        // SPD PADS - solo notes with progressive polyrhythms
        spdActivity++;
        conway.getLivingCells() @=> int livingCells[];
        midiNote - 54 => int padIdx;
        
        if(livingCells.size() > 0) {
            padIdx % livingCells.size() => int chordNoteIdx;
            livingCells[chordNoteIdx] => int selectedNote;
            
            // Progressive octave range through sections
            0 => int octaveOffset;
            if(conway.currentSection == 0) Math.random2(-1, 2) => octaveOffset;
            else if(conway.currentSection == 1) Math.random2(-1, 3) => octaveOffset;
            else if(conway.currentSection == 2) Math.random2(-2, 4) => octaveOffset;
            else Math.random2(-2, 5) => octaveOffset;
            
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            
            // Use polyrhythmic playing in later sections
            spd.playPolyrhythmic(freq, 1.8 * vel, conway.currentSection);
            
        } else {
            // Fallback to diamond grid
            padIdx % 64 => int diamondIdx;
            Math.random2(0, 2 + conway.currentSection) => int octaveOffset;
            diamondFreqs[diamondIdx] * Math.pow(2, octaveOffset) => float freq;
            spd.playPolyrhythmic(freq, 1.8 * vel, conway.currentSection);
        }
    }
}

/**
* MIDI listener thread
*/
fun void midiListener() {
    while(true) {
        min => now;
        while(min.recv(msg) && msg.data3 != 0) {
            handleMidi(msg.data2, msg.data3);
        }
    }
}

/**
* Automatic advancement system
*/
fun void autoAdvance() {
    while(true) {
        100::ms => now;
        updateChordDuration();
        
        if(shouldAdvance()) {
            conway.nextGeneration();
            updateActiveVoices();
            
            // Update fade based on generation count
            getFadeMultiplier() => fadeGain.gain;
            
            playCurrentChord(0.5);
            resetTiming();
        }
    }
}

/**
* Generative texture system with progressive complexity
*/
fun void generativeTextures() {
    while(true) {
        // Faster updates in later sections
        (4.0 - (conway.currentSection * 0.5))::second => now;
        
        kickActivity + snareActivity + floorTomActivity + spdActivity => int totalActivity;
        
        // Progressive texture generation thresholds
        int burstThreshold, clickThreshold, rumbleThreshold;
        
        if(conway.currentSection <= 1) {
            12 => burstThreshold;
            8 => clickThreshold; 
            5 => rumbleThreshold;
        } else if(conway.currentSection == 2) {
            8 => burstThreshold;
            5 => clickThreshold;
            3 => rumbleThreshold;
        } else {
            5 => burstThreshold;
            3 => clickThreshold;
            2 => rumbleThreshold;
        }
        
        // Generate textures based on activity and section
        if(totalActivity > burstThreshold) {
            if(Math.random2(0, 3) == 0) texture.burst(0.7, conway.currentSection);
        }
        
        if(totalActivity > clickThreshold) {
            if(Math.random2(0, 4) == 0) texture.clickSound(0.5, conway.currentSection);
        }
        
        if(totalActivity > rumbleThreshold && conway.currentSection >= 2) {
            if(Math.random2(0, 5) == 0) texture.rumbleSound(0.4, BASE_FREQ, conway.currentSection);
        }
        
        // Rhythm echo playback with varied speeds
        if(totalActivity > 1) {
            [1.0, 1.5, 0.75, 2.0, 0.5] @=> float speeds[];
            speeds[Math.random2(0, speeds.size() - 1)] => float chosenSpeed;
            spork ~ rhythmEcho.playback(chosenSpeed, conway.currentSection);
        }
        
        // Activity decay
        (kickActivity * 0.65) $ int => kickActivity;
        (snareActivity * 0.65) $ int => snareActivity;
        (floorTomActivity * 0.65) $ int => floorTomActivity;
        (spdActivity * 0.65) $ int => spdActivity;
    }
}

/**
* Main performance function
*/
fun void main() {
    init();
    
    // Launch concurrent threads
    spork ~ midiListener();
    spork ~ autoAdvance();
    spork ~ generativeTextures();
    
    // Main loop
    while(true) {
        1::second => now;
        
        // Optional: Performance statistics every 30 seconds
        if(conway.totalGenerations % 30 == 0 && conway.totalGenerations > 0) {
            <<< "Performance Status - Section:", conway.currentSection, 
            "| Active Voices:", activeVoices, 
            "| Grid Activity:", conway.getGridActivity() >>>;
        }
    }
}

// Launch the performance
main();
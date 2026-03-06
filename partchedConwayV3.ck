/*
* BATTERY: Conway's Game of Life on 15-Limit Just Intonation Tonality Diamond
* Interactive Performance for Solo Drums + Electronics
* 
* COMPREHENSIVE FUNCTIONALITY:
* 
* CORE SYSTEM:
* - 8x8 Conway's Game of Life grid mapped to 15-limit JI tonality diamond frequencies
* - Kick drum (MIDI 0) advances Conway generation and plays resulting chord
* - Four compositional sections evolve over ~12 minutes with increasing complexity
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
*/

// ============================================================================
// CONFIGURATION
// ============================================================================

12 => int MAX_VOICES;
3 => int MIN_VOICES;
0.55 => float DEFAULT_GAIN;
0.75 => float MASTER_GAIN;
0.03 => float MASTER_REVERB;

3.0 => float SHORT_DURATION;
8.0 => float LONG_DURATION;
16.0 => float TIMEOUT_DURATION;
8 => int KICKS_TO_ADVANCE;

220.0 => float BASE_FREQ;

8 => int GRID_WIDTH;
8 => int GRID_HEIGHT;

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

class BassSynth extends Chugraph {
    TriOsc osc => ADSR env => PRCRev rev => outlet;
    
    fun void init() {
        env.set(50::ms, 300::ms, 0.3, 3000::ms);
        0.03 => rev.mix;
        DEFAULT_GAIN * 0.8 => osc.gain;
    }
    
    fun void play(float freq, dur duration, float velocity) {
        freq => osc.freq;
        env.set(50::ms, 300::ms, 0.3, duration);
        
        // Velocity affects reverb
        (0.03 + (velocity * 0.05)) => rev.mix;
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void release() {
        150::ms => now;
        env.keyOff();
    }
}

class ChordSynth extends Chugraph {
    TriOsc oscs[MAX_VOICES];
    ADSR envs[MAX_VOICES];
    PRCRev revs[MAX_VOICES];
    BiQuad filters[MAX_VOICES];
    Pan2 pans[MAX_VOICES];
    Gain master => outlet;
    
    float previousFreqs[MAX_VOICES];
    int previousVoiceCount;
    
    fun void init() {
        for(0 => int i; i < MAX_VOICES; i++) {
            oscs[i] => envs[i] => revs[i] => filters[i] => pans[i] => master;
            
            envs[i].set(50::ms, 300::ms, 0.2, 3000::ms);
            0.03 => revs[i].mix;
            DEFAULT_GAIN * (1.8 - (i * 0.06)) * 0.8 => oscs[i].gain;
            
            if(i % 2 == 0) -0.7 => pans[i].pan;
            else 0.7 => pans[i].pan;
            
            0.97 => filters[i].prad;
            200.0 + (i * 100) => filters[i].pfreq;
            1 => filters[i].eqzs;
            DEFAULT_GAIN * 1.0 => filters[i].gain;
            
            0.0 => previousFreqs[i];
        }
        DEFAULT_GAIN * 0.6 => master.gain;
        0 => previousVoiceCount;
    }
    
    fun void play(float freqs[], int numVoices, dur duration, float velocity, float gridActivity) {
        stop();
        
        // Voice leading - use previous frequencies for smooth transitions
        float targetFreqs[numVoices];
        for(0 => int i; i < numVoices; i++) {
            freqs[i] => targetFreqs[i];
        }
        
        if(previousVoiceCount > 0) {
            applyVoiceLeading(targetFreqs, numVoices);
        }
        
        // Velocity affects chord density - FIX: Cast float result to int
        Math.min(numVoices, Math.max(1, (numVoices * velocity) $ int)) $ int => int actualVoices;
        
        for(0 => int i; i < actualVoices && i < MAX_VOICES; i++) {
            targetFreqs[i] => oscs[i].freq;
            targetFreqs[i] => previousFreqs[i];
            
            envs[i].set(50::ms, 300::ms, 0.2, duration);
            
            // Velocity affects reverb
            (0.03 + (velocity * 0.04)) => revs[i].mix;
            
            // Spectral evolution based on grid activity
            updateSpectralFilter(i, velocity, gridActivity);
            
            envs[i].keyOn();
        }
        
        actualVoices => previousVoiceCount;
        spork ~ release(actualVoices);
    }
    
    fun void applyVoiceLeading(float targetFreqs[], int numVoices) {
        // Sort both previous and target frequencies
        float sortedPrev[previousVoiceCount];
        float sortedTarget[numVoices];
        
        for(0 => int i; i < previousVoiceCount; i++) {
            previousFreqs[i] => sortedPrev[i];
        }
        for(0 => int i; i < numVoices; i++) {
            targetFreqs[i] => sortedTarget[i];
        }
        
        // Simple bubble sort for both arrays
        for(0 => int i; i < previousVoiceCount - 1; i++) {
            for(0 => int j; j < previousVoiceCount - 1 - i; j++) {
                if(sortedPrev[j] > sortedPrev[j + 1]) {
                    sortedPrev[j] => float temp;
                    sortedPrev[j + 1] => sortedPrev[j];
                    temp => sortedPrev[j + 1];
                }
            }
        }
        
        for(0 => int i; i < numVoices - 1; i++) {
            for(0 => int j; j < numVoices - 1 - i; j++) {
                if(sortedTarget[j] > sortedTarget[j + 1]) {
                    sortedTarget[j] => float temp;
                    sortedTarget[j + 1] => sortedTarget[j];
                    temp => sortedTarget[j + 1];
                }
            }
        }
        
        // Find optimal voice assignments to minimize movement
        for(0 => int i; i < numVoices; i++) {
            if(i < previousVoiceCount) {
                // Find closest frequency match
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
                if(minDistance < (sortedTarget[i] * 0.1)) {
                    sortedPrev[bestMatch] => targetFreqs[i];
                }
            }
        }
    }
    
    fun void updateSpectralFilter(int voiceIndex, float velocity, float gridActivity) {
        // Base frequency from velocity (harder hits = brighter)
        200.0 + (velocity * 2000.0) => float baseFreq;
        
        // Modulate by grid activity (more active = brighter)
        baseFreq + (gridActivity * 1500.0) => float finalFreq;
        
        // Per-voice offset
        finalFreq + (voiceIndex * 100) => filters[voiceIndex].pfreq;
        
        // Velocity affects filter resonance
        0.95 + (velocity * 0.04) => filters[voiceIndex].prad;
    }
    
    fun void stop() {
        for(0 => int i; i < MAX_VOICES; i++) {
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

class SnareSynth extends Chugraph {
    TriOsc osc => ADSR env => BiQuad filter => PRCRev rev => outlet;
    
    fun void init() {
        env.set(5::ms, 150::ms, 0.3, 300::ms);
        0.95 => filter.prad;
        3000.0 => filter.pfreq;
        2 => filter.eqzs;
        0.08 => rev.mix;
        DEFAULT_GAIN * 2.5 => osc.gain;
        DEFAULT_GAIN * 1.5 => filter.gain;
    }
    
    fun void play(float freq, float velocity) {
        freq => osc.freq;
        
        // Velocity affects filter cutoff
        (3000.0 + (velocity * 4000.0)) => filter.pfreq;
        
        // Velocity affects reverb
        (0.08 + (velocity * 0.12)) => rev.mix;
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void release() {
        120::ms => now;
        env.keyOff();
    }
}

class FloorTomSynth extends Chugraph {
    SawOsc osc => ADSR env => BiQuad filter => PRCRev rev => outlet;
    
    fun void init() {
        env.set(10::ms, 200::ms, 0.4, 500::ms);
        0.95 => filter.prad;
        800.0 => filter.pfreq;
        2 => filter.eqzs;
        0.05 => rev.mix;
        DEFAULT_GAIN * 0.3 => osc.gain;
        DEFAULT_GAIN * 0.3 => filter.gain;
    }
    
    fun void play(float freq, float velocity) {
        freq => osc.freq;
        
        // Velocity affects filter cutoff
        (800.0 + (velocity * 1500.0)) => filter.pfreq;
        
        // Velocity affects reverb
        (0.05 + (velocity * 0.08)) => rev.mix;
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void release() {
        80::ms => now;
        env.keyOff();
    }
}

class SPDSynth extends Chugraph {
    PulseOsc osc => ADSR env => Echo echo => PRCRev rev => outlet;
    
    fun void init() {
        env.set(5::ms, 100::ms, 0.5, 400::ms);
        250::ms => echo.max => echo.delay;
        0.3 => echo.mix;
        0.4 => echo.gain;
        0.05 => rev.mix;
        DEFAULT_GAIN * 0.6 => osc.gain;
    }
    
    fun void play(float freq, float velocity) {
        freq => osc.freq;
        
        // Velocity affects echo feedback
        (0.4 + (velocity * 0.4)) => echo.gain;
        
        // Velocity affects reverb
        (0.05 + (velocity * 0.10)) => rev.mix;
        
        env.keyOn();
        spork ~ release();
    }
    
    fun void release() {
        100::ms => now;
        env.keyOff();
    }
}

class TextureGenerator extends Chugraph {
    Noise noise => BPF filter => ADSR env => PRCRev rev => outlet;
    Impulse click => ADSR clickEnv => HPF clickFilter => rev;
    SinOsc rumble => ADSR rumbleEnv => LPF rumbleFilter => rev;
    
    fun void init() {
        env.set(200::ms, 800::ms, 0.2, 1500::ms);
        1000.0 => filter.freq;
        3.0 => filter.Q;
        0.15 => rev.mix;
        DEFAULT_GAIN * 0.10 => noise.gain;
        
        clickEnv.set(1::ms, 5::ms, 0.0, 10::ms);
        5000.0 => clickFilter.freq;
        2.0 => clickFilter.Q;
        DEFAULT_GAIN * 0.5 => click.gain;
        
        rumbleEnv.set(500::ms, 1000::ms, 0.4, 2000::ms);
        80.0 => rumbleFilter.freq;
        1.0 => rumbleFilter.Q;
        DEFAULT_GAIN * 0.2 => rumble.gain;
    }
    
    fun void burst(float velocity) {
        Math.random2f(500, 3000) + (velocity * 2000.0) => filter.freq;
        Math.random2f(2.0, 8.0) + (velocity * 3.0) => filter.Q;
        (0.15 + (velocity * 0.10)) => rev.mix;
        
        env.keyOn();
        spork ~ releaseBurst();
    }
    
    fun void clickSound(float velocity) {
        Math.random2f(3000, 8000) + (velocity * 2000.0) => clickFilter.freq;
        1.0 => click.next;
        clickEnv.keyOn();
        spork ~ releaseClick();
    }
    
    fun void rumbleSound(float velocity, float baseFreq) {
        baseFreq * 0.25 => rumble.freq;
        (0.15 + (velocity * 0.10)) => rev.mix;
        rumbleEnv.keyOn();
        spork ~ releaseRumble();
    }
    
    fun void releaseBurst() {
        Math.random2(300, 800)::ms => now;
        env.keyOff();
    }
    
    fun void releaseClick() {
        15::ms => now;
        clickEnv.keyOff();
    }
    
    fun void releaseRumble() {
        Math.random2(800, 1500)::ms => now;
        rumbleEnv.keyOff();
    }
}

class RhythmEcho extends Chugraph {
    Shakers shaker => PRCRev rev => outlet;
    float rhythmTimes[32];
    0 => int rhythmIndex;
    now => time startTime;
    0 => int hasStarted;
    
    fun void init() {
        7 => shaker.which;
        0.12 => rev.mix;
        DEFAULT_GAIN * 0.8 => shaker.gain;
        
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
    
    fun void playback(float speed) {
        if(rhythmIndex < 2) return;
        
        0 => int startIndex;
        rhythmIndex => int endIndex;
        if(rhythmIndex > 8) rhythmIndex - 8 => startIndex;
        
        for(0 => int i; i < (endIndex - startIndex - 1); i++) {
            (startIndex + i) % rhythmTimes.size() => int currentIdx;  
            (startIndex + i + 1) % rhythmTimes.size() => int nextIdx;
            
            rhythmTimes[nextIdx] - rhythmTimes[currentIdx] => float interval;
            
            if(interval > 0.05 && interval < 5.0) {
                Math.random2(5, 10) => shaker.which;
                Math.random2f(60, 120) => shaker.freq;
                Math.random2f(20, 80) => shaker.objects;
                shaker.noteOn(Math.random2f(5, 15));
                
                (interval / speed)::second => now;
            }
        }
    }
}

// ============================================================================
// GAME OF LIFE ENGINE
// ============================================================================

class ConwayEngine {
    int grid[GRID_HEIGHT][GRID_WIDTH];
    int nextGrid[GRID_HEIGHT][GRID_WIDTH];
    0 => int generation;
    0 => int stableCount;
    0 => int currentSection;
    0 => int totalGenerations;
    
    fun void init() {
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                if(y < INITIAL_PATTERN.size() && x < INITIAL_PATTERN[y].size()) {
                    INITIAL_PATTERN[y][x] => grid[y][x];
                } else {
                    0 => grid[y][x];
                }
            }
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
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                countNeighbors(y, x) => int neighbors;
                
                if(grid[y][x] == 1) {
                    if(neighbors == 2 || neighbors == 3) 1 => nextGrid[y][x];
                    else 0 => nextGrid[y][x];
                } else {
                    if(neighbors == 3) 1 => nextGrid[y][x];
                    else 0 => nextGrid[y][x];
                }
            }
        }
        
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
        
        for(0 => int y; y < GRID_HEIGHT; y++) {
            for(0 => int x; x < GRID_WIDTH; x++) {
                nextGrid[y][x] => grid[y][x];
            }
        }
        
        generation++;
        totalGenerations++;
        updateSection();
        
        if(hasChanged == 1) stableCount + 1 => stableCount;
        else 0 => stableCount;
        
        0 => int injected;
        if(stableCount >= 4) {
            injectLife();
            0 => stableCount;
            1 => injected;
        }
        
        printGrid(injected);
    }
    
    fun void updateSection() {
        totalGenerations / 40 => int newSection;
        Math.min(newSection, 3) $ int => newSection;
        
        if(newSection != currentSection) {
            newSection => currentSection;
            if(currentSection == 0) <<< "=== SECTION A: Sparse, Simple ===" >>>;
            else if(currentSection == 1) <<< "=== SECTION B: Building, More Voices ===" >>>;
            else if(currentSection == 2) <<< "=== SECTION C: Dense, Complex ===" >>>;
            else <<< "=== SECTION D: Resolution, Full Complexity ===" >>>;
        }
        
        if(currentSection == 0) 8 => KICKS_TO_ADVANCE;
        else if(currentSection == 1) 6 => KICKS_TO_ADVANCE;
        else if(currentSection == 2) 4 => KICKS_TO_ADVANCE;
        else Math.random2(3, 7) => KICKS_TO_ADVANCE;
    }
    
    fun void injectLife() {
        if(currentSection == 0) {
            injectSimplePattern();
        } else if(currentSection == 1) {
            if(Math.random2(0, 2) < 2) injectSimplePattern();
            else injectMediumPattern();
        } else if(currentSection == 2) {
            if(Math.random2(0, 3) == 0) injectSimplePattern();
            else if(Math.random2(0, 2) == 0) injectMediumPattern();
            else injectComplexPattern();
        } else {
            for(0 => int i; i < Math.random2(1, 3); i++) {
                if(Math.random2(0, 1) == 0) injectMediumPattern();
                else injectComplexPattern();
            }
        }
    }
    
    fun void injectSimplePattern() {
        Math.random2(0, GRID_HEIGHT - 3) => int startY;
        Math.random2(0, GRID_WIDTH - 3) => int startX;
        
        1 => grid[startY][startX + 1];
        1 => grid[startY + 1][startX + 2];  
        1 => grid[startY + 2][startX];
        1 => grid[startY + 2][startX + 1];
        1 => grid[startY + 2][startX + 2];
    }
    
    fun void injectMediumPattern() {
        Math.random2(1, GRID_HEIGHT - 4) => int startY;
        Math.random2(1, GRID_WIDTH - 4) => int startX;
        
        1 => grid[startY][startX + 1];
        1 => grid[startY][startX + 2];
        1 => grid[startY + 1][startX];
        1 => grid[startY + 1][startX + 1];
        1 => grid[startY + 2][startX + 1];
    }
    
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
    
    fun void printGrid(int injected) {
        for(0 => int y; y < GRID_HEIGHT; y++) {
            "" => string row;
            for(0 => int x; x < GRID_WIDTH; x++) {
                if(grid[y][x] == 1) row + "1 " => row;
                else row + "0 " => row;
            }
            <<< row >>>;
        }
        
        if(injected == 1) <<< "LIFE INJECTED" >>>;
        <<< "generation: " + generation + " totalGenerations: " + totalGenerations + " section: " + currentSection >>>;
        <<< "-------" >>>;
    }
}

// ============================================================================
// MAIN SYSTEM
// ============================================================================

float diamondFreqs[64];
ConwayEngine conway;
int melodicMemory[16];
0 => int memoryIndex;
0 => int activeVoices;
float chordDuration;
0 => int kickCount;
now => time chordStartTime;
0 => int hasKickedOnce;
now => time lastKickTime;

0 => int kickActivity;
0 => int snareActivity;
0 => int floorTomActivity;
0 => int spdActivity;

Gain master => Dyno limiter => JCRev masterReverb => dac;
MASTER_GAIN => master.gain;
MASTER_REVERB => masterReverb.mix;

limiter.limit();
0.5 => limiter.thresh;
0.1 => limiter.slopeAbove;
5::ms => limiter.attackTime;
200::ms => limiter.releaseTime;

BassSynth bass;
ChordSynth chord;  
SnareSynth snare;
FloorTomSynth floorTom;
SPDSynth spd;
TextureGenerator texture;
RhythmEcho rhythmEcho;

bass => master;
chord => master;
snare => master;
floorTom => master;
spd => master;
texture => master;
rhythmEcho => master;

MidiIn min;
MidiMsg msg;

fun void setupMidi() {
    [0,1,2,3,4,5] @=> int ports[];
    for(0 => int i; i < ports.size(); i++){
        if(min.open(ports[i]) && min.name() == "SPD-SX") {
            break;
        }
    }
}

fun void calculateFrequencies() {
    for(0 => int i; i < 64; i++) {
        i / 8 => int row;
        i % 8 => int col;
        BASE_FREQ * DIAMOND_RATIOS[row * 8 + col][0] / DIAMOND_RATIOS[row * 8 + col][1] => diamondFreqs[i];
        
        while(diamondFreqs[i] < BASE_FREQ * 0.5) diamondFreqs[i] * 2.0 => diamondFreqs[i];
        while(diamondFreqs[i] > BASE_FREQ * 4.0) diamondFreqs[i] / 2.0 => diamondFreqs[i];
    }
}

fun void init() {
    setupMidi();
    calculateFrequencies();
    conway.init();
    
    bass.init();
    chord.init();
    snare.init();
    floorTom.init();
    spd.init();
    texture.init();
    rhythmEcho.init();
    
    1 => activeVoices;
    SHORT_DURATION => chordDuration;
    
    for(0 => int i; i < melodicMemory.size(); i++) {
        0 => melodicMemory[i];
    }
    
    playCurrentChord(0.5);
    conway.printGrid(0);
}

fun void playCurrentChord(float velocity) {
    conway.getLivingCells() @=> int livingCells[];
    conway.getGridActivity() => float gridActivity;
    
    if(livingCells.size() == 0) {
        bass.play(BASE_FREQ, chordDuration::second, velocity);
        return;
    }
    
    int sortedCells[livingCells.size()];
    for(0 => int i; i < livingCells.size(); i++) {
        livingCells[i] => sortedCells[i];
    }
    
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
    
    if(sortedCells.size() > 0) {
        Math.random2(0, sortedCells.size() - 1) => int bassNoteIdx;
        Math.random2(1, 2) => int bassOctaveDown;
        diamondFreqs[sortedCells[bassNoteIdx]] / Math.pow(2, bassOctaveDown) => float bassFreq;
        bass.play(bassFreq, chordDuration::second, velocity);
    }
    
    Math.min(Math.min(sortedCells.size(), MAX_VOICES), activeVoices) $ int => int voicesToPlay;
    float chordFreqs[voicesToPlay];
    for(0 => int i; i < voicesToPlay; i++) {
        diamondFreqs[sortedCells[i]] => chordFreqs[i];
    }
    chord.play(chordFreqs, voicesToPlay, chordDuration::second, velocity, gridActivity);
}

fun int shouldAdvance() {
    if(kickCount >= KICKS_TO_ADVANCE) return 1;
    if(now - chordStartTime >= chordDuration::second) return 1;
    return 0;
}

fun void resetTiming() {
    0 => kickCount;
    now => chordStartTime;
}

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

fun void updateActiveVoices() {
    // Dynamic voice scaling based on total generations
    1 => int newActiveVoices;
    
    if(conway.totalGenerations <= 5) {
        1 => newActiveVoices; // Start with 1 voice
    } else if(conway.totalGenerations <= 15) {
        // Quick ramp to 3 voices over generations 5-15
        (1 + ((conway.totalGenerations - 5) * 2 / 10)) $ int => newActiveVoices;
    } else if(conway.totalGenerations <= 40) {
        3 => newActiveVoices; // Stay at 3 voices for a while
    } else {
        // Slow ramp from 3 to 64 voices after generation 40
        (3 + ((conway.totalGenerations - 40) * 61 / 120)) $ int => newActiveVoices;
        Math.min(newActiveVoices, 64) $ int => newActiveVoices;
    }
    
    newActiveVoices => activeVoices;
    
    if(conway.currentSection == 0) 0.03 => MASTER_REVERB;
    else if(conway.currentSection == 1) 0.04 => MASTER_REVERB;  
    else if(conway.currentSection == 2) 0.06 => MASTER_REVERB;
    else 0.08 => MASTER_REVERB;
    
    MASTER_REVERB => masterReverb.mix;
}

fun void addToMelodyMemory(int note) {
    note => melodicMemory[memoryIndex];
    (memoryIndex + 1) % melodicMemory.size() => memoryIndex;
}

fun int getRelatedNote(int currentNote) {
    for(0 => int i; i < melodicMemory.size(); i++) {
        melodicMemory[i] => int memNote;
        if(memNote > 0) {
            if(Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.5) < 0.1) {
                return memNote;
            }
            if(Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.333) < 0.1) {
                return memNote;
            }
        }
    }
    return currentNote;
}

fun void handleMidi(int midiNote, int velocity) {
    (velocity / 127.0) => float vel;
    
    if(midiNote == 0) {
        kickCount++;
        kickActivity++;
        now => lastKickTime;
        
        if(velocity > 90) {
            conway.getLivingCells() @=> int livingCells[];
            if(livingCells.size() > 0) {
                texture.rumbleSound(vel, diamondFreqs[livingCells[0]]);
            } else {
                texture.rumbleSound(vel, BASE_FREQ);
            }
        }
        
        if(hasKickedOnce == 0) {
            1 => hasKickedOnce;
            updateChordDuration();
        }
        
        if(shouldAdvance()) {
            conway.nextGeneration();
            updateActiveVoices();
            playCurrentChord(vel);
            resetTiming();
        }
        
    } else if(midiNote == 1) {
        snareActivity++;
        conway.getLivingCells() @=> int livingCells[];
        
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIdx;
            livingCells[randomIdx] => int selectedNote;
            
            if(conway.currentSection >= 1) {
                if(melodicMemory[memoryIndex] > 0) {
                    getRelatedNote(melodicMemory[memoryIndex]) => selectedNote;
                }
            }
            
            Math.random2(-1, 1) => int octaveOffset;
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            snare.play(freq, 2.5 * vel);
        }
        
        texture.burst(vel);
        if(Math.random2(0, 2) == 0) {
            texture.clickSound(vel);
        }
        
    } else if(midiNote == 2) {
        floorTomActivity++;
        
        rhythmEcho.recordHit();
        
        conway.getLivingCells() @=> int livingCells[];
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIdx;
            livingCells[randomIdx] => int selectedNote;
            
            if(conway.currentSection >= 2) {
                getRelatedNote(selectedNote) => selectedNote;
            }
            
            addToMelodyMemory(selectedNote);
            Math.random2(1, 3) => int octaveOffset;
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            floorTom.play(freq, 1.4 * vel);
        }
        
        if(Math.random2(0, 2) == 0) {
            texture.clickSound(vel);
        }
        
    } else if(midiNote >= 54 && midiNote <= 62) {
        spdActivity++;
        conway.getLivingCells() @=> int livingCells[];
        midiNote - 54 => int padIdx;
        
        if(livingCells.size() > 0) {
            padIdx % livingCells.size() => int chordNoteIdx;
            livingCells[chordNoteIdx] => int selectedNote;
            
            0 => int octaveOffset;
            if(conway.currentSection == 0) Math.random2(-1, 2) => octaveOffset;
            else if(conway.currentSection == 1) Math.random2(-1, 3) => octaveOffset;
            else Math.random2(-2, 4) => octaveOffset;
            
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            
            if(conway.currentSection >= 3 && Math.random2(0, 2) == 0) {
                spd.play(freq, 1.4 * vel);
                100::ms => now;
                spd.play(freq * Math.pow(2, 1), 1.2 * vel);
            } else {
                spd.play(freq, 1.6 * vel);
            }
        } else {
            padIdx % 64 => int diamondIdx;
            Math.random2(0, 2) => int octaveOffset;
            diamondFreqs[diamondIdx] * Math.pow(2, octaveOffset) => float freq;
            spd.play(freq, 1.6 * vel);
        }
    }
}

fun void midiListener() {
    while(true) {
        min => now;
        while(min.recv(msg) && msg.data3 != 0) {
            handleMidi(msg.data2, msg.data3);
        }
    }
}

fun void autoAdvance() {
    while(true) {
        100::ms => now;
        updateChordDuration();
        
        if(shouldAdvance()) {
            conway.nextGeneration();
            updateActiveVoices();
            playCurrentChord(0.5);
            resetTiming();
        }
    }
}

fun void generativeTextures() {
    while(true) {
        3::second => now;
        
        kickActivity + snareActivity + floorTomActivity + spdActivity => int totalActivity;
        
        if(totalActivity > 8 && conway.currentSection >= 1) {
            if(Math.random2(0, 3) == 0) texture.burst(0.6);
        } else if(totalActivity > 4 && conway.currentSection >= 2) {
            if(Math.random2(0, 4) == 0) texture.clickSound(0.4);
        }
        
        if(totalActivity > 2 && conway.currentSection >= 3 && Math.random2(0, 5) == 0) {
            texture.rumbleSound(0.3, BASE_FREQ);
        }
        
        if(totalActivity > 0 && conway.currentSection >= 0) {
            [1.0, 2.0, 0.5, 1.5] @=> float speeds[];
            speeds[Math.random2(0, speeds.size() - 1)] => float chosenSpeed;
            spork ~ rhythmEcho.playback(chosenSpeed);
        }
        
        (kickActivity * 0.7) $ int => kickActivity;
        (snareActivity * 0.7) $ int => snareActivity;
        (floorTomActivity * 0.7) $ int => floorTomActivity;
        (spdActivity * 0.7) $ int => spdActivity;
    }
}

fun void main() {
    init();
    
    spork ~ midiListener();
    spork ~ autoAdvance();
    spork ~ generativeTextures();
    
    while(true) {
        1::second => now;
    }
}

main();
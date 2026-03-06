// Enhanced Conway's Game of Life on 13-Limit Tonality Diamond
// BATTERY Project - Interactive Performance for Solo Drums + Electronics
// Refactored for maintainability and clarity

// =====================
// CONFIGURATION
// =====================

// Audio Settings
12 => int MAX_VOICES;                   // Maximum simultaneous chord notes (will evolve)
3 => int MIN_VOICES;                    // Minimum voices to maintain
0.55 => float DEFAULT_GAIN;             // Base gain level (reduced very slightly from 0.6)
0.75 => float MASTER_GAIN;              // Overall output level (reduced very slightly from 0.8)
0.03 => float MASTER_REVERB;            // Master reverb amount (will evolve, but less drastically)

// Timing Settings  
3.0 => float CHORD_DURATION;            // Seconds for chord decay (starts at 3, changes to 8 when kick hit)
8 => int KICKS_TO_ADVANCE;              // Kick hits needed to advance chord (will evolve)
3.0 => float SHORT_DURATION;            // Short chord duration
8.0 => float LONG_DURATION;             // Long chord duration
16.0 => float TIMEOUT_DURATION;         // Seconds without kick to revert to short duration

// Evolution Settings
0 => int currentSection;                // Current composition section (0-3)
int melodicMemory[16];                  // Store recent solo notes for development
0 => int memoryIndex;                   // Current position in melodic memory
0 => int activeVoices;                  // Current number of active chord voices

// Tuning Settings
220.0 => float BASE_FREQ;               // Base frequency in Hz

// Grid Settings
8 => int GRID_WIDTH;                    // Conway grid width (8x8 for 15-limit diamond)
8 => int GRID_HEIGHT;                   // Conway grid height

// Initial Conway Pattern (all zeros - converged state)
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

// Solo Settings
250::ms => dur SOLO_ECHO_TIME;          // Echo delay for solo notes
0.3 => float SOLO_ECHO_MIX;             // Echo wet/dry mix
400::ms => dur SOLO_DECAY_TIME;         // Solo note decay time

// ================================
// 15-LIMIT TONALITY DIAMOND RATIOS  
// ================================

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

// ==================
// GLOBAL VARIABLES
// ==================

float diamondFreqs[64]; // 8x8 => 64 frequencies
int grid[GRID_HEIGHT][GRID_WIDTH];
int nextGrid[GRID_HEIGHT][GRID_WIDTH];
0 => int generation;
0 => int kickCount;
now => time chordStartTime;
0 => int totalGenerations; // Total generations across all sections
int lastGrid[GRID_HEIGHT][GRID_WIDTH]; // Store previous grid state
0 => int stableCount; // Count generations with no change
0 => int hasKickedOnce; // Track if kick has been hit at least once
now => time lastKickTime; // Time of last kick

// =================
// SYNTHESIS SYSTEM
// =================

// Master chain
Gain master => Dyno limiter => JCRev masterReverb => dac;
MASTER_GAIN => master.gain;
MASTER_REVERB => masterReverb.mix;

// Configure limiter
limiter.limit();
0.5 => limiter.thresh;
0.1 => limiter.slopeAbove;
5::ms => limiter.attackTime;
200::ms => limiter.releaseTime;

// Chord synthesis
TriOsc chordOscs[MAX_VOICES];
ADSR chordAdsrs[MAX_VOICES];
PRCRev chordReverbs[MAX_VOICES];
BiQuad chordFilters[MAX_VOICES]; // For spectral evolution
Gain chordMaster => master;

// Solo synthesis
PulseOsc soloOsc => ADSR soloAdsr => Echo soloEcho => PRCRev soloReverb => master;

// Snare synthesis (separate from SPD pads)
SawOsc snareOsc => ADSR snareAdsr => BiQuad snareFilter => PRCRev snareReverb => master;

// Tom synthesis (separate from SPD pads)
TriOsc tomOsc => ADSR tomAdsr => LPF tomFilter => PRCRev tomReverb => master;

// Ambient layer
SinOsc ambientOsc => ADSR ambientAdsr => NRev ambientReverb => master;

// NEW: Generative texture layers based on playing activity
Noise textureNoise => BPF textureFilter => ADSR textureAdsr => PRCRev textureReverb => master;
Impulse clickOsc => ADSR clickAdsr => HPF clickFilter => PRCRev clickReverb => master;
SinOsc rumbleOsc => ADSR rumbleAdsr => LPF rumbleFilter => PRCRev rumbleReverb => master;

// NEW: Rhythm echo system
Shakers rhythmShaker => PRCRev rhythmReverb => master;
float snareRhythms[32];  // Store timing of last 32 snare hits
0 => int rhythmIndex;    // Current position in rhythm array
now => time firstSnareTime; // Time of first snare hit for reference
0 => int hasFirstSnare;  // Flag to track if we've had our first snare

// Texture tracking variables
0 => int kickActivity;
0 => int snareActivity; 
0 => int tomActivity;
0 => int spdActivity;
now => time lastTextureTime;

// =============
// MIDI SETUP
// =============

MidiIn min;
MidiMsg msg;

fun void setupMidi() {
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
        me.exit();
    }
}

// ====================
// FREQUENCY CALCULATION
// ====================

fun void calculateFrequencies() {
    for(0 => int i; i < 64; i++) { // 8x8 grid
        i / 8 => int row;
        i % 8 => int col;
        BASE_FREQ * DIAMOND_RATIOS[row * 8 + col][0] / DIAMOND_RATIOS[row * 8 + col][1] => diamondFreqs[i];
        
        // Keep frequencies in reasonable range
        while(diamondFreqs[i] < BASE_FREQ * 0.5) {
            diamondFreqs[i] * 2.0 => diamondFreqs[i];
        }
        while(diamondFreqs[i] > BASE_FREQ * 4.0) {
            diamondFreqs[i] / 2.0 => diamondFreqs[i];
        }
    }
}

// =================
// SYNTHESIS SETUP
// =================

fun void initSynthesis() {
    // Initialize melodic memory
    for(0 => int i; i < melodicMemory.size(); i++) {
        0 => melodicMemory[i];
    }
    MIN_VOICES => activeVoices; // Start with minimum voices
    
    // Chord oscillators
    for(0 => int i; i < MAX_VOICES; i++) {
        chordOscs[i] => chordAdsrs[i] => chordReverbs[i] => chordFilters[i] => chordMaster;
        
        chordAdsrs[i].set(50::ms, 300::ms, 0.2, (CHORD_DURATION * 1000)::ms);
        0.03 => chordReverbs[i].mix;
        // Dynamic gain reduction based on active voices
        DEFAULT_GAIN * (1.8 - (i * 0.06)) * (8.0 / (activeVoices + 8.0)) => chordOscs[i].gain;
        
        // Initialize filters for spectral evolution
        0.97 => chordFilters[i].prad;
        200.0 + (i * 100) => chordFilters[i].pfreq; // Start with low-pass filtering
        1 => chordFilters[i].eqzs;
        DEFAULT_GAIN * 0.6 => chordFilters[i].gain;
    }
    DEFAULT_GAIN * 1.0 => chordMaster.gain;
    
    // Solo oscillator (quieter relative to chords)
    soloAdsr.set(5::ms, 100::ms, 0.5, SOLO_DECAY_TIME);
    SOLO_ECHO_TIME => soloEcho.max => soloEcho.delay;
    SOLO_ECHO_MIX => soloEcho.mix;
    0.4 => soloEcho.gain;
    0.05 => soloReverb.mix;
    DEFAULT_GAIN * 0.5 => soloOsc.gain; // Reduced from 0.6
    
    // Snare synthesis (separate from SPD)
    snareAdsr.set(5::ms, 150::ms, 0.3, 300::ms);
    0.95 => snareFilter.prad;
    3000.0 => snareFilter.pfreq;
    2 => snareFilter.eqzs;
    0.08 => snareReverb.mix;
    DEFAULT_GAIN * 0.8 => snareOsc.gain; // Increased from 0.6
    DEFAULT_GAIN * 1.0 => snareFilter.gain; // Increased from 0.8
    
    // Tom synthesis (separate from SPD)
    tomAdsr.set(10::ms, 200::ms, 0.4, 500::ms);
    800.0 => tomFilter.freq;
    2.0 => tomFilter.Q;
    0.05 => tomReverb.mix;
    DEFAULT_GAIN * 0.25 => tomOsc.gain; // Reduced from 0.4
    
    // Ambient layer
    ambientAdsr.set(1000::ms, 2000::ms, 0.3, 3000::ms);
    0.2 => ambientReverb.mix;
    DEFAULT_GAIN * 0.3 => ambientOsc.gain; // Reduced from 0.4
    
    // NEW: Setup texture layers
    textureAdsr.set(200::ms, 800::ms, 0.2, 1500::ms);
    1000.0 => textureFilter.freq;
    3.0 => textureFilter.Q;
    0.15 => textureReverb.mix;
    DEFAULT_GAIN * 0.15 => textureNoise.gain;
    
    clickAdsr.set(1::ms, 5::ms, 0.0, 10::ms);
    5000.0 => clickFilter.freq;
    2.0 => clickFilter.Q;
    0.05 => clickReverb.mix;
    DEFAULT_GAIN * 0.8 => clickOsc.gain;
    
    rumbleAdsr.set(500::ms, 1000::ms, 0.4, 2000::ms);
    80.0 => rumbleFilter.freq;
    1.0 => rumbleFilter.Q;
    0.1 => rumbleReverb.mix;
    DEFAULT_GAIN * 0.2 => rumbleOsc.gain;
    
    // NEW: Setup rhythm echo system - Shakers for metallic percussion
    7 => rhythmShaker.which; // Cabasa - metallic shaker sound
    0.12 => rhythmReverb.mix;
    DEFAULT_GAIN * 0.8 => rhythmShaker.gain; // Loud and clear
    
    // Initialize rhythm array
    for(0 => int i; i < snareRhythms.size(); i++) {
        0.0 => snareRhythms[i];
    }
}

// ==================
// CONWAY'S GAME OF LIFE
// ==================

fun void initGrid() {
    // Clear grid
    for(0 => int y; y < GRID_HEIGHT; y++) {
        for(0 => int x; x < GRID_WIDTH; x++) {
            0 => grid[y][x];
        }
    }
    
    // Set initial pattern
    for(0 => int y; y < INITIAL_PATTERN.size() && y < GRID_HEIGHT; y++) {
        for(0 => int x; x < INITIAL_PATTERN[y].size() && x < GRID_WIDTH; x++) {
            INITIAL_PATTERN[y][x] => grid[y][x];
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

// Inject new life with section-dependent complexity
fun void injectLife() {
    // Section-dependent injection patterns
    if(currentSection == 0) {
        // Section A: Simple patterns only
        Math.random2(0, 1) => int patternType;
        injectSimplePattern(patternType);
    } else if(currentSection == 1) {
        // Section B: Mix of simple and medium patterns
        Math.random2(0, 2) => int patternType;
        if(patternType < 2) {
            injectSimplePattern(patternType);
        } else {
            injectMediumPattern();
        }
    } else if(currentSection == 2) {
        // Section C: Mostly complex patterns
        Math.random2(0, 3) => int patternType;
        if(patternType == 0) {
            injectSimplePattern(0);
        } else if(patternType == 1) {
            injectMediumPattern();
        } else {
            injectComplexPattern();
        }
    } else {
        // Section D: Multiple simultaneous injections
        Math.random2(1, 3) => int numInjections;
        for(0 => int i; i < numInjections; i++) {
            Math.random2(0, 2) => int patternType;
            if(patternType == 0) injectMediumPattern();
            else injectComplexPattern();
        }
    }
}

fun void injectSimplePattern(int type) {
    if(type == 0) {
        // Glider pattern
        Math.random2(0, GRID_HEIGHT - 3) => int startY;
        Math.random2(0, GRID_WIDTH - 3) => int startX;
        
        1 => grid[startY][startX + 1];
        1 => grid[startY + 1][startX + 2];
        1 => grid[startY + 2][startX];
        1 => grid[startY + 2][startX + 1];
        1 => grid[startY + 2][startX + 2];
    } else {
        // Simple beacon
        Math.random2(1, GRID_HEIGHT - 3) => int startY;
        Math.random2(1, GRID_WIDTH - 3) => int startX;
        
        1 => grid[startY][startX];
        1 => grid[startY][startX + 1];
        1 => grid[startY + 1][startX];
        1 => grid[startY + 1][startX + 1];
    }
}

fun void injectMediumPattern() {
    // Pentomino patterns
    Math.random2(1, GRID_HEIGHT - 4) => int startY;
    Math.random2(1, GRID_WIDTH - 4) => int startX;
    
    // R-pentomino
    1 => grid[startY][startX + 1];
    1 => grid[startY][startX + 2];
    1 => grid[startY + 1][startX];
    1 => grid[startY + 1][startX + 1];
    1 => grid[startY + 2][startX + 1];
}

fun void injectComplexPattern() {
    // Large oscillator patterns
    Math.random2(1, GRID_HEIGHT - 5) => int startY;
    Math.random2(1, GRID_WIDTH - 5) => int startX;
    
    // Pulsar pattern (partial)
    1 => grid[startY][startX + 2];
    1 => grid[startY][startX + 3];
    1 => grid[startY + 1][startX + 1];
    1 => grid[startY + 1][startX + 4];
    1 => grid[startY + 2][startX];
    1 => grid[startY + 2][startX + 5];
    1 => grid[startY + 3][startX + 2];
    1 => grid[startY + 3][startX + 3];
}

fun void nextGeneration() {
    // Calculate next state
    for(0 => int y; y < GRID_HEIGHT; y++) {
        for(0 => int x; x < GRID_WIDTH; x++) {
            countNeighbors(y, x) => int neighbors;
            
            if(grid[y][x] == 1) { // Living cell
                if(neighbors == 2 || neighbors == 3) {
                    1 => nextGrid[y][x]; // Survives
                } else {
                    0 => nextGrid[y][x]; // Dies
                }
            } else { // Dead cell
                if(neighbors == 3) {
                    1 => nextGrid[y][x]; // Born
                } else {
                    0 => nextGrid[y][x]; // Stays dead
                }
            }
        }
    }
    
    // Check if grid has changed
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
    
    // Copy to current state
    for(0 => int y; y < GRID_HEIGHT; y++) {
        for(0 => int x; x < GRID_WIDTH; x++) {
            nextGrid[y][x] => grid[y][x];
        }
    }
    
    generation++;
    totalGenerations++; // Track across all sections
    
    // Update composition section
    updateSection();
    
    // Track stability
    if(hasChanged == 1) {
        stableCount + 1 => stableCount;
    } else {
        0 => stableCount;
    }
    
    // Print current state and check for injection
    0 => int injected;
    if(stableCount >= 4) {
        injectLife();
        0 => stableCount;
        1 => injected;
    }
    
    printDiamondState(injected);
}

// Update composition section and evolution parameters
fun void updateSection() {
    totalGenerations / 45 => currentSection; // Switch every ~45 generations (much longer sections)
    Math.min(currentSection, 3) $ int => currentSection; // Cap at section 3
    
    // Section A (0-2min): Sparse, Simple
    if(currentSection == 0) {
        MIN_VOICES => activeVoices;
        8 => KICKS_TO_ADVANCE;
        0.03 => MASTER_REVERB;
        // Keep filters closed (200-500Hz range)
        for(0 => int i; i < MAX_VOICES; i++) {
            200.0 + (i * 50) => chordFilters[i].pfreq;
            0.03 => chordReverbs[i].mix;
        }
    }
    // Section B (2-5min): Building, More Voices  
    else if(currentSection == 1) {
        Math.min(MIN_VOICES + 3, MAX_VOICES) $ int => activeVoices;
        6 => KICKS_TO_ADVANCE; // Faster advancement
        0.04 => MASTER_REVERB; // Less drastic change (was 0.06)
        // Open filters more (200-1000Hz range)
        for(0 => int i; i < MAX_VOICES; i++) {
            200.0 + (i * 100) => chordFilters[i].pfreq;
            0.04 => chordReverbs[i].mix; // Less drastic change (was 0.06)
        }
    }
    // Section C (5-8min): Dense, Complex
    else if(currentSection == 2) {
        Math.min(MIN_VOICES + 6, MAX_VOICES) $ int => activeVoices;
        4 => KICKS_TO_ADVANCE; // Even faster
        0.06 => MASTER_REVERB; // Less drastic change (was 0.09)
        // Wide open filters (500-3000Hz range)
        for(0 => int i; i < MAX_VOICES; i++) {
            500.0 + (i * 200) => chordFilters[i].pfreq;
            0.06 => chordReverbs[i].mix; // Less drastic change (was 0.09)
        }
    }
    // Section D (8-12min): Resolution, Full Complexity
    else {
        MAX_VOICES => activeVoices;
        Math.random2(3, 7) => KICKS_TO_ADVANCE; // Syncopated advancement
        0.08 => MASTER_REVERB; // Less drastic change (was 0.12)
        // Full spectrum (1000-5000Hz range)
        for(0 => int i; i < MAX_VOICES; i++) {
            1000.0 + (i * 300) => chordFilters[i].pfreq;
            0.08 => chordReverbs[i].mix; // Less drastic change (was 0.12)
        }
    }
    
    // Update master reverb
    MASTER_REVERB => masterReverb.mix;
}

fun void updateChordDuration() {
    if(hasKickedOnce == 0) {
        // Haven't kicked yet, stay at short duration
        SHORT_DURATION => CHORD_DURATION;
    } else {
        // Have kicked before, check timeout
        if(now - lastKickTime >= TIMEOUT_DURATION::second) {
            // Timeout reached, revert to short duration
            SHORT_DURATION => CHORD_DURATION;
            0 => hasKickedOnce; // Reset for next time
        } else {
            // Still active, use long duration
            LONG_DURATION => CHORD_DURATION;
        }
    }
    
    // Update chord ADSR to match new duration
    for(0 => int i; i < MAX_VOICES; i++) {
        chordAdsrs[i].set(50::ms, 300::ms, 0.2, (CHORD_DURATION * 1000)::ms);
    }
}

// Store note in melodic memory for development
fun void addToMelodyMemory(int note) {
    note => melodicMemory[memoryIndex];
    (memoryIndex + 1) % melodicMemory.size() => memoryIndex;
}

// Get harmonically related note from memory  
fun int getRelatedNote(int currentNote) {
    // Look for notes that form consonant intervals
    for(0 => int i; i < melodicMemory.size(); i++) {
        melodicMemory[i] => int memNote;
        if(memNote > 0) {
            // Check for perfect fifth (3/2 ratio)
            if(Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.5) < 0.1) {
                return memNote;
            }
            // Check for perfect fourth (4/3 ratio)  
            if(Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.333) < 0.1) {
                return memNote;
            }
        }
    }
    return currentNote; // Fallback to current note
}

fun int[] getCurrentChord() {
    int livingCells[64]; // Max 64 cells in 8x8 grid
    0 => int count;
    
    // Collect living cells
    for(0 => int y; y < GRID_HEIGHT; y++) {
        for(0 => int x; x < GRID_WIDTH; x++) {
            if(grid[y][x] == 1) {
                y * GRID_WIDTH + x => int rawIndex;
                if(rawIndex < 64) { // Ensure within bounds
                    rawIndex => livingCells[count];
                    count++;
                }
            }
        }
    }
    
    // Return properly sized array
    int result[count];
    for(0 => int i; i < count; i++) {
        livingCells[i] => result[i];
    }
    return result;
}

// Print the current state of the diamond
fun void printDiamondState(int injected) {
    // Print visual grid only
    for(0 => int y; y < GRID_HEIGHT; y++) {
        "" => string row;
        for(0 => int x; x < GRID_WIDTH; x++) {
            if(grid[y][x] == 1) {
                row + "1 " => row;
            } else {
                row + "0 " => row;
            }
        }
        <<< row >>>;
    }
    
    if(injected == 1) {
        <<< "LIFE INJECTED" >>>;
    }
    <<< "-------" >>>; // Horizontal separator
}

// =================
// AUDIO PLAYBACK
// =================

fun void playChord() {
    // Immediately stop all current voices
    for(0 => int i; i < MAX_VOICES; i++) {
        chordAdsrs[i].keyOff();
    }
    
    getCurrentChord() @=> int livingCells[];
    
    if(livingCells.size() == 0) {
        playAmbient();
        return;
    }
    
    // Sort by frequency (lowest first)
    int sortedCells[livingCells.size()];
    for(0 => int i; i < livingCells.size(); i++) {
        livingCells[i] => sortedCells[i];
    }
    
    // Simple insertion sort
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
    
    // Use only activeVoices (evolves with sections)
    Math.min(Math.min(livingCells.size(), MAX_VOICES), activeVoices) $ int => int voicesToPlay;
    
    for(0 => int i; i < voicesToPlay; i++) {
        diamondFreqs[sortedCells[i]] => chordOscs[i].freq;
        chordAdsrs[i].keyOn();
    }
    
    spork ~ releaseChord();
}

fun void releaseChord() {
    (CHORD_DURATION * 1000 * 0.05)::ms => now;
    for(0 => int i; i < MAX_VOICES; i++) {
        chordAdsrs[i].keyOff();
    }
}

fun void playAmbient() {
    ambientAdsr.keyOff();
    5::ms => now;
    BASE_FREQ => ambientOsc.freq;
    ambientAdsr.keyOn();
    spork ~ releaseAmbient();
}

fun void releaseAmbient() {
    500::ms => now;
    ambientAdsr.keyOff();
}

fun void playSolo(int diamondIndex, int octaveOffset, float gainMultiplier) {
    soloAdsr.keyOff();
    2::ms => now;
    
    if(diamondIndex >= 0 && diamondIndex < diamondFreqs.size()) {
        diamondFreqs[diamondIndex] * Math.pow(2, octaveOffset) => soloOsc.freq;
        soloAdsr.keyOn();
        spork ~ releaseSolo();
    }
}

fun void releaseSolo() {
    100::ms => now;
    soloAdsr.keyOff();
}

fun void playSnare(int diamondIndex, int octaveOffset, float gainMultiplier) {
    snareAdsr.keyOff();
    2::ms => now;
    
    if(diamondIndex >= 0 && diamondIndex < diamondFreqs.size()) {
        diamondFreqs[diamondIndex] * Math.pow(2, octaveOffset) => snareOsc.freq;
        snareAdsr.keyOn();
        spork ~ releaseSnare();
    }
}

fun void releaseSnare() {
    80::ms => now;
    snareAdsr.keyOff();
}

fun void playTom(int diamondIndex, int octaveOffset, float gainMultiplier) {
    tomAdsr.keyOff();
    2::ms => now;
    
    if(diamondIndex >= 0 && diamondIndex < diamondFreqs.size()) {
        diamondFreqs[diamondIndex] * Math.pow(2, octaveOffset) => tomOsc.freq;
        tomAdsr.keyOn();
        spork ~ releaseTom();
    }
}

fun void releaseTom() {
    120::ms => now;
    tomAdsr.keyOff();
}

// NEW: Generative texture functions
fun void playRumble(float vel) {
    rumbleAdsr.keyOff();
    50::ms => now;
    
    // Set frequency based on current chord content
    getCurrentChord() @=> int livingCells[];
    if(livingCells.size() > 0) {
        diamondFreqs[livingCells[0]] * 0.25 => rumbleOsc.freq; // Very low
    } else {
        BASE_FREQ * 0.25 => rumbleOsc.freq;
    }
    
    rumbleAdsr.keyOn();
    spork ~ releaseRumble();
}

fun void releaseRumble() {
    Math.random2(800, 1500)::ms => now;
    rumbleAdsr.keyOff();
}

fun void playClick(float vel) {
    clickAdsr.keyOff();
    2::ms => now;
    
    // Random frequency for percussive click
    Math.random2f(3000, 8000) => clickFilter.freq;
    1.0 => clickOsc.next;
    clickAdsr.keyOn();
    spork ~ releaseClick();
}

fun void releaseClick() {
    15::ms => now;
    clickAdsr.keyOff();
}

fun void playTextureBurst(float vel) {
    textureAdsr.keyOff();
    10::ms => now;
    
    // Filter frequency based on tom activity and current section
    Math.random2f(500, 3000) + (tomActivity * 50) => textureFilter.freq;
    Math.random2f(2.0, 8.0) => textureFilter.Q;
    
    textureAdsr.keyOn();
    spork ~ releaseTexture();
}

fun void releaseTexture() {
    Math.random2(300, 800)::ms => now;
    textureAdsr.keyOff();
}

// NEW: Rhythm echo functions
fun void playRhythmEcho(float speed) {
    <<< "Total snare hits recorded so far:", rhythmIndex >>>;
    
    if(rhythmIndex < 2) {
        <<< "Need at least 2 snare hits, only have", rhythmIndex >>>;
        return;
    }
    
    // Use the last few snare hits (or all if we have less than 8)
    0 => int startIndex;
    rhythmIndex => int endIndex;
    
    if(rhythmIndex > 8) {
        rhythmIndex - 8 => startIndex;
    }
    
    endIndex - startIndex => int numHits;
    
    <<< "Using", numHits, "recent snare hits for rhythm echo" >>>;
    
    // Play back the recent rhythm pattern
    for(0 => int i; i < numHits - 1; i++) {
        startIndex + i => int tempIndex1;
        tempIndex1 % snareRhythms.size() => int currentIndex;
        
        startIndex + i + 1 => int tempIndex2;
        tempIndex2 % snareRhythms.size() => int nextIndex;
        
        // Calculate interval between consecutive hits
        snareRhythms[nextIndex] - snareRhythms[currentIndex] => float interval;
        
        if(interval > 0.05 && interval < 5.0) { // Reasonable interval
            <<< "Playing shaker hit", i, "with interval", interval >>>;
            
            // Trigger shaker
            Math.random2(5, 10) => rhythmShaker.which;
            Math.random2f(60, 120) => rhythmShaker.freq;
            Math.random2f(20, 80) => rhythmShaker.objects;
            rhythmShaker.noteOn(Math.random2f(5, 15));
            
            // Wait for the interval, adjusted by speed
            (interval / speed)::second => now;
        } else {
            <<< "Skipping interval", i, "- out of range:", interval >>>;
        }
    }
    <<< "Finished rhythm playback" >>>;
}

// ===============
// CHORD TIMING
// ===============

fun int shouldAdvance() {
    if(kickCount >= KICKS_TO_ADVANCE) return 1;
    if(now - chordStartTime >= CHORD_DURATION::second) return 1;
    return 0;
}

fun void resetTiming() {
    0 => kickCount;
    now => chordStartTime;
}

// =================
// MIDI HANDLING
// =================

fun void handleMidi(int midiNote, int velocity) {
    (velocity / 127.0) => float vel;
    
    if(midiNote == 0) { 
        // KICK - Advance generation and update timing
        kickCount++;
        kickActivity++; // Track kick activity for textures
        now => lastKickTime; // Update last kick time
        
        // Generative texture: rumble on heavy kicks
        if(velocity > 90) {
            spork ~ playRumble(vel);
        }
        
        // First kick switches to long duration
        if(hasKickedOnce == 0) {
            1 => hasKickedOnce;
            updateChordDuration();
        }
        
        if(shouldAdvance()) {
            nextGeneration();
            playChord();
            resetTiming();
        }
        
    } else if(midiNote == 1) { 
        // SNARE - Melodic development with memory
        snareActivity++; // Track snare activity for textures
        
        // NEW: Record snare rhythm timing
        if(hasFirstSnare == 0) {
            // First snare hit - set reference time
            now => firstSnareTime;
            1 => hasFirstSnare;
            0.0 => snareRhythms[rhythmIndex]; // First hit is at time 0
            <<< "First snare hit - setting reference time" >>>;
        } else {
            // Subsequent hits - calculate time since first snare
            (now - firstSnareTime) / 1::second => snareRhythms[rhythmIndex];
            <<< "Recording snare rhythm:", snareRhythms[rhythmIndex], "at index:", rhythmIndex >>>;
        }
        (rhythmIndex + 1) % snareRhythms.size() => rhythmIndex;
        
        getCurrentChord() @=> int livingCells[];
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIndex;
            livingCells[randomIndex] => int selectedNote;
            
            // Section-dependent behavior
            if(currentSection >= 2) {
                // Later sections: use melodic memory for development
                getRelatedNote(selectedNote) => selectedNote;
            }
            
            addToMelodyMemory(selectedNote);
            Math.random2(1, 3) => int octaveOffset;
            playSnare(selectedNote, octaveOffset, 1.8 * vel); // Increased from 1.5
        }
        
        // Generative texture: clicks on snare hits
        if(Math.random2(0, 2) == 0) {
            spork ~ playClick(vel);
        }
        
    } else if(midiNote == 2) { 
        // TOM - Call and response with snare in later sections
        tomActivity++; // Track tom activity for textures
        getCurrentChord() @=> int livingCells[];
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIndex;
            livingCells[randomIndex] => int selectedNote;
            
            // Section-dependent behavior
            if(currentSection >= 1) {
                // Later sections: respond to recent snare notes
                if(melodicMemory[memoryIndex] > 0) {
                    getRelatedNote(melodicMemory[memoryIndex]) => selectedNote;
                }
            }
            
            Math.random2(-1, 1) => int octaveOffset;
            playTom(selectedNote, octaveOffset, 0.5 * vel); // Reduced from 0.7
        }
        
        // Generative texture: filtered noise bursts on tom
        spork ~ playTextureBurst(vel);
        
    } else if(midiNote >= 54 && midiNote <= 62) { 
        // SPD PADS - Section-dependent complexity
        spdActivity++; // Track SPD activity for textures
        getCurrentChord() @=> int livingCells[];
        midiNote - 54 => int padIndex;
        
        if(livingCells.size() > 0) {
            padIndex % livingCells.size() => int chordNoteIndex;
            livingCells[chordNoteIndex] => int selectedNote;
            
            // Section-dependent octave ranges
            0 => int octaveOffset;
            if(currentSection == 0) {
                Math.random2(-1, 2) => octaveOffset; // Conservative range
            } else if(currentSection == 1) {
                Math.random2(-1, 3) => octaveOffset; // Medium range
            } else {
                Math.random2(-2, 4) => octaveOffset; // Wide range
            }
            
            // Add polyrhythmic patterns in later sections
            if(currentSection >= 3 && Math.random2(0, 2) == 0) {
                // Polyrhythmic echo
                playSolo(selectedNote, octaveOffset, 1.3 * vel); // Increased from 0.8
                100::ms => now;
                playSolo(selectedNote, octaveOffset + 1, 1.0 * vel); // Increased from 0.6
            } else {
                playSolo(selectedNote, octaveOffset, 1.6 * vel); // Increased from 1.2
            }
        } else {
            // Fallback to diamond ratios
            padIndex % 64 => int diamondIndex; // Ensure within 8x8 bounds
            Math.random2(0, 2) => int octaveOffset;
            playSolo(diamondIndex, octaveOffset, 1.6 * vel); // Increased from 1.2
        }
    }
}

// MIDI listener threads
3 => int numHandlers;
for(0 => int i; i < numHandlers; i++) {
    spork ~ midiListener();
}

fun void midiListener() {
    while(true) {
        min => now;
        while(min.recv(msg) && msg.data3 != 0) {
            handleMidi(msg.data2, msg.data3);
        }
    }
}

// Auto-advance thread
spork ~ autoAdvance();
fun void autoAdvance() {
    while(true) {
        100::ms => now;
        
        // Check for timeout and update chord duration
        updateChordDuration();
        
        if(shouldAdvance()) {
            nextGeneration();
            playChord();
            resetTiming();
        }
    }
}

// NEW: Generative texture thread - creates ambient textures based on playing activity
spork ~ generativeTextures();
fun void generativeTextures() {
    while(true) {
        3::second => now; // Check every 3 seconds
        
        // Calculate total activity in the last period
        kickActivity + snareActivity + tomActivity + spdActivity => int totalActivity;
        
        // Generate textures based on activity levels
        if(totalActivity > 8 && currentSection >= 1) {
            // High activity - create texture burst
            if(Math.random2(0, 3) == 0) {
                spork ~ playTextureBurst(0.6);
            }
        } else if(totalActivity > 4 && currentSection >= 2) {
            // Medium activity - occasional clicks
            if(Math.random2(0, 4) == 0) {
                spork ~ playClick(0.4);
            }
        }
        
        // Slow rumbles in later sections when there's any activity
        if(totalActivity > 2 && currentSection >= 3 && Math.random2(0, 5) == 0) {
            spork ~ playRumble(0.3);
        }
        
        // NEW: Rhythm echoes based on recorded snare patterns - FORCE TRIGGER FOR TESTING
        if(totalActivity > 0 && currentSection >= 0) { // Always try if any activity, any section
            <<< "===> RHYTHM ECHO ATTEMPT ===" >>>;
            <<< "Total activity:", totalActivity, "Section:", currentSection >>>;
            // Choose playback speed variation
            [1.0, 2.0, 0.5, 1.5] @=> float speeds[]; // normal, double, half, triplet-ish
            speeds[Math.random2(0, speeds.size() - 1)] => float chosenSpeed;
            <<< "Playing rhythm echo at speed:", chosenSpeed >>>; // Debug output
            spork ~ playRhythmEcho(chosenSpeed);
        }
        
        // Reset activity counters (decay over time)
        (kickActivity * 0.7) $ int => kickActivity;
        (snareActivity * 0.7) $ int => snareActivity;
        (tomActivity * 0.7) $ int => tomActivity;  
        (spdActivity * 0.7) $ int => spdActivity;
    }
}

// ============
// MAIN PROGRAM
// ============

fun void main() {
    setupMidi();
    calculateFrequencies();
    initGrid();
    initSynthesis();
    
    // Print initial state
    printDiamondState(0);
    
    playChord();
    resetTiming();
    
    while(true) {
        1::second => now;
    }
}

main(); 
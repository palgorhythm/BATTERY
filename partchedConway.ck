// Enhanced Conway's Game of Life on 13-Limit Tonality Diamond
// BATTERY Project - Interactive Performance for Solo Drums + Electronics
// Refactored for maintainability and clarity

// =====================
// CONFIGURATION
// =====================

// Audio Settings
64 => int MAX_VOICES;                    // Maximum simultaneous chord notes
0.8 => float DEFAULT_GAIN;              // Base gain level (increased)
1.0 => float MASTER_GAIN;               // Overall output level
0.05 => float MASTER_REVERB;            // Master reverb amount

// Timing Settings  
3.0 => float CHORD_DURATION;            // Seconds for chord decay (starts at 3, changes to 8 when kick hit)
8 => int KICKS_TO_ADVANCE;              // Kick hits needed to advance chord
3.0 => float SHORT_DURATION;            // Short chord duration
8.0 => float LONG_DURATION;             // Long chord duration
16.0 => float TIMEOUT_DURATION;         // Seconds without kick to revert to short duration

// Tuning Settings
180.0 => float BASE_FREQ;               // Base frequency in Hz

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

float diamondFreqs[64]; // 8x8 = 64 frequencies
int grid[GRID_HEIGHT][GRID_WIDTH];
int nextGrid[GRID_HEIGHT][GRID_WIDTH];
0 => int generation;
0 => int kickCount;
now => time chordStartTime;
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
Gain chordMaster => master;

// Solo synthesis
PulseOsc soloOsc => ADSR soloAdsr => Echo soloEcho => PRCRev soloReverb => master;

// Snare synthesis (separate from SPD pads)
SawOsc snareOsc => ADSR snareAdsr => BiQuad snareFilter => PRCRev snareReverb => master;

// Tom synthesis (separate from SPD pads)
TriOsc tomOsc => ADSR tomAdsr => LPF tomFilter => PRCRev tomReverb => master;

// Ambient layer
SinOsc ambientOsc => ADSR ambientAdsr => NRev ambientReverb => master;

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
    // Chord oscillators (louder)
    for(0 => int i; i < MAX_VOICES; i++) {
        chordOscs[i] => chordAdsrs[i] => chordReverbs[i] => chordMaster;
        
        chordAdsrs[i].set(100::ms, 100::ms, 0.4, (CHORD_DURATION * 1000)::ms);
        0.03 => chordReverbs[i].mix;
        DEFAULT_GAIN * (2.2 - (i * 0.08)) => chordOscs[i].gain; // Increased chord gain
    }
    DEFAULT_GAIN * 1.2 => chordMaster.gain; // Increased chord master gain
    
    // Solo oscillator (quieter relative to chords)
    soloAdsr.set(5::ms, 100::ms, 0.5, SOLO_DECAY_TIME);
    SOLO_ECHO_TIME => soloEcho.max => soloEcho.delay;
    SOLO_ECHO_MIX => soloEcho.mix;
    0.4 => soloEcho.gain;
    0.05 => soloReverb.mix;
    DEFAULT_GAIN * 0.6 => soloOsc.gain; // Increased from 0.4
    
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
    DEFAULT_GAIN * 0.7 => tomOsc.gain;
    
    // Ambient layer
    ambientAdsr.set(1000::ms, 2000::ms, 0.3, 3000::ms);
    0.2 => ambientReverb.mix;
    DEFAULT_GAIN * 0.4 => ambientOsc.gain;
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

// Inject new life when pattern becomes too sparse
fun void injectLife() {
    Math.random2(0, 1) => int patternType;
    
    if(patternType == 0) {
        // Glider pattern (active, travels) - ensure it fits in 8x8 grid
        Math.random2(0, GRID_HEIGHT - 3) => int startY;
        Math.random2(0, GRID_WIDTH - 3) => int startX;
        
        1 => grid[startY][startX + 1];
        1 => grid[startY + 1][startX + 2];
        1 => grid[startY + 2][startX];
        1 => grid[startY + 2][startX + 1];
        1 => grid[startY + 2][startX + 2];
    } else {
        // Consonant pattern - beacon oscillator (fits in 8x8)
        Math.random2(0, GRID_HEIGHT - 4) => int startY;
        Math.random2(0, GRID_WIDTH - 4) => int startX;
        
        // Ensure pattern fits within bounds
        if(startY + 3 < GRID_HEIGHT && startX + 3 < GRID_WIDTH) {
            1 => grid[startY][startX];
            1 => grid[startY][startX + 1];
            1 => grid[startY + 1][startX];
            1 => grid[startY + 2][startX + 2];
            1 => grid[startY + 2][startX + 3];
            1 => grid[startY + 3][startX + 2];
            1 => grid[startY + 3][startX + 3];
        } else {
            // Fallback to simple 3-cell pattern
            1 => grid[2][2];
            1 => grid[2][3];
            1 => grid[3][2];
        }
    }
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
        chordAdsrs[i].set(100::ms, 100::ms, 0.4, (CHORD_DURATION * 1000)::ms);
    }
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
    // No delay - immediately start new chord
    
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
    
    // Start voices immediately
    Math.min(livingCells.size(), MAX_VOICES) $ int => int voicesToPlay;
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
        now => lastKickTime; // Update last kick time
        
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
        // SNARE - Separate snare synth (higher octaves)
        getCurrentChord() @=> int livingCells[];
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIndex;
            Math.random2(1, 3) => int octaveOffset;
            playSnare(livingCells[randomIndex], octaveOffset, 1.5 * vel);
        }
        
    } else if(midiNote == 2) { 
        // TOM - Separate tom synth (lower octaves)
        getCurrentChord() @=> int livingCells[];
        if(livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIndex;
            Math.random2(-1, 1) => int octaveOffset;
            playTom(livingCells[randomIndex], octaveOffset, 1.3 * vel);
        }
        
    } else if(midiNote >= 54 && midiNote <= 62) { 
        // SPD PADS - Separate solo synth for specific chord notes
        getCurrentChord() @=> int livingCells[];
        midiNote - 54 => int padIndex;
        
        if(livingCells.size() > 0) {
            padIndex % livingCells.size() => int chordNoteIndex;
            Math.random2(-1, 3) => int octaveOffset;
            playSolo(livingCells[chordNoteIndex], octaveOffset, 1.2 * vel);
        } else {
            // Fallback to diamond ratios
            padIndex % 64 => int diamondIndex; // Ensure within 8x8 bounds
            Math.random2(0, 2) => int octaveOffset;
            playSolo(diamondIndex, octaveOffset, 1.2 * vel);
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
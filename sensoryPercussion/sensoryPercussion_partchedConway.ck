// ============================================================
// PARTCHED CONWAY - cellular automata meets just intonation
// Sensory Percussion via IAC Driver | Audio on channels 3 & 4
//
// STRUCTURE: Conway's Game of Life on 8x8 grid mapped to a
//   15-limit just intonation tonality diamond (Harry Partch).
//   Living cells sound their JI frequency. 5 sections (A-E)
//   with increasing voice counts (1->64) and decreasing kick
//   thresholds. Built-in fade-out. ~10 min performance arc.
// KICK: Advance Conway generation (after N kicks, varies by section)
// SNARE: Texture bursts from living cells
// FLOOR TOM: Record rhythm for echo playback
// CRASH: Solo from living cell frequencies
// ============================================================

// ============================================================
// MIDI SETUP - Sensory Percussion via IAC Driver
// ============================================================

MidiIn midiIn;
MidiMsg msg;
fun void setUpMidi() {
    for (0 => int i; i < 8; i++) {
        if (midiIn.open(i) && midiIn.name().find("IAC") > -1) {
            <<<"Opened IAC Driver on port", i>>>;
            return;
        }
    }
    <<<"ERROR: IAC Driver MIDI port not found.">>>;
    me.exit();
}
setUpMidi();

// ============================================================
// Sensory Percussion MIDI map:
// Drums: kick=0, snare=1, rack tom=2, floor tom=3
// Hi-hat zones:  4 (bow), 5 (edge), 6 (bell-shoulder), 7 (bell-tip), 8 (ping)
// Crash zones:   9 (bow), 10 (edge), 11 (bell-shoulder), 12 (bell-tip), 13 (ping)
// Ride zones:    14 (bow), 15 (edge), 16 (bell-shoulder), 17 (bell-tip), 18 (ping)
// ============================================================
0 => int KICK_NOTE;
1 => int SNARE_NOTE;
2 => int RACK_TOM_NOTE;
3 => int FLOOR_TOM_NOTE;
9 => int CRASH_MIN; 13 => int CRASH_MAX;

// ============================================================
// GLOBAL CONFIGURATION
// ============================================================

0.085 => float GAIN;

// Voice and timing constants
64 => int MAX_TOTAL_VOICES;
12 => int MAX_CHORD_VOICES;

// Fade out configuration
200 => int FADE_START_GENERATION;
250 => int FADE_END_GENERATION;

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
4 => int STABILITY_THRESHOLD;
0 => int START_SECTION;
0 => int START_GENERATION;

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

// ============================================================
// AUDIO ROUTING - channels 3 & 4
// ============================================================

Gain master => Gain fadeGain => Dyno limiter => JCRev masterReverb => dac.chan(2);
masterReverb => dac.chan(3);
GAIN => master.gain;
1.0 => fadeGain.gain;

// Limiter settings
limiter.limit();
0.6 => limiter.thresh;
0.08 => limiter.slopeAbove;
4::ms => limiter.attackTime;
180::ms => limiter.releaseTime;

// ============================================================
// INSTRUMENT CLASSES
// ============================================================

class BassSynth extends Chugraph {
    TriOsc osc => ADSR env => PRCRev rev => outlet;

    fun void init() {
        env.set(50::ms, 300::ms, 0.3, 3000::ms);
        0.03 => rev.mix;
        GAIN * 1.0 => osc.gain;
    }

    fun void play(float freq, dur duration, float velocity, int section) {
        if (section < 1) return;
        freq => osc.freq;
        env.set(50::ms, 300::ms, 0.3, duration);

        if (section >= 4) {
            GAIN * (1.0 + (3 * 0.08)) $ float => osc.gain;
        } else {
            GAIN * (1.0 + (section * 0.08)) $ float => osc.gain;
        }

        Math.min(section, 2) $ int => int cappedSection;
        (0.03 + (velocity * 0.03) + (cappedSection * 0.005)) $ float => rev.mix;

        env.keyOn();
        spork ~ releaseEnv();
    }

    fun void playMultiOctave(float freq, dur duration, float velocity, int section) {
        play(freq, duration, velocity, section);
        if (section >= 4) {
            spork ~ play(freq * 0.5, duration, velocity * 0.7, section);
        }
    }

    fun void releaseEnv() {
        150::ms => now;
        env.keyOff();
    }
}

class ChordSynth extends Chugraph {
    TriOsc oscs[MAX_CHORD_VOICES];
    ADSR envs[MAX_CHORD_VOICES];
    PRCRev revs[MAX_CHORD_VOICES];
    BiQuad filters[MAX_CHORD_VOICES];
    Pan2 pans[MAX_CHORD_VOICES];
    Gain chordMaster => outlet;

    float previousFreqs[MAX_CHORD_VOICES];
    int previousVoiceCount;

    fun void init() {
        for (0 => int i; i < MAX_CHORD_VOICES; i++) {
            oscs[i] => envs[i] => revs[i] => filters[i] => pans[i] => chordMaster;
            envs[i].set(50::ms, 300::ms, 0.2, 3000::ms);
            0.03 => revs[i].mix;
            GAIN * (1.8 - (i * 0.06)) * 0.6 => oscs[i].gain;

            if (i % 2 == 0) -0.7 => pans[i].pan;
            else 0.7 => pans[i].pan;

            0.97 => filters[i].prad;
            300.0 + (i * 150) => filters[i].pfreq;
            1 => filters[i].eqzs;
            GAIN * 0.8 => filters[i].gain;
            0.0 => previousFreqs[i];
        }
        GAIN * 0.7 => chordMaster.gain;
        0 => previousVoiceCount;
    }

    fun void play(float freqs[], int numVoices, dur duration, float velocity, float gridActivity, int section) {
        stop();
        Math.min(numVoices, MAX_CHORD_VOICES) $ int => int requestedVoices;

        float targetFreqs[requestedVoices];
        for (0 => int i; i < requestedVoices; i++) {
            freqs[i] => targetFreqs[i];
        }

        if (previousVoiceCount > 0) {
            applyVoiceLeading(targetFreqs, requestedVoices);
        }

        Math.min(requestedVoices, Math.max(1, (requestedVoices * velocity) $ int)) $ int => int actualVoices;

        for (0 => int i; i < actualVoices; i++) {
            targetFreqs[i] => oscs[i].freq;
            targetFreqs[i] => previousFreqs[i];
            envs[i].set(50::ms, 300::ms, 0.2, duration);

            if (section >= 4) {
                GAIN * (1.8 - (i * 0.06)) * (0.6 + (3 * 0.08)) $ float => oscs[i].gain;
            } else {
                GAIN * (1.8 - (i * 0.06)) * (0.6 + (section * 0.08)) $ float => oscs[i].gain;
            }

            Math.min(section, 2) $ int => int cappedSection;
            (0.03 + (velocity * 0.02) + (cappedSection * 0.008)) $ float => revs[i].mix;
            updateSpectralFilter(i, velocity, gridActivity, section);
            envs[i].keyOn();
        }

        actualVoices => previousVoiceCount;
        spork ~ releaseVoices(actualVoices);
    }

    fun void applyVoiceLeading(float targetFreqs[], int numVoices) {
        if (previousVoiceCount == 0) return;

        float sortedPrev[previousVoiceCount];
        float sortedTarget[numVoices];

        for (0 => int i; i < previousVoiceCount; i++) {
            previousFreqs[i] => sortedPrev[i];
        }
        for (0 => int i; i < numVoices; i++) {
            targetFreqs[i] => sortedTarget[i];
        }

        bubbleSort(sortedPrev, previousVoiceCount);
        bubbleSort(sortedTarget, numVoices);

        for (0 => int i; i < numVoices && i < previousVoiceCount; i++) {
            0 => int bestMatch;
            Math.fabs(sortedTarget[i] - sortedPrev[0]) => float minDist;

            for (0 => int j; j < previousVoiceCount; j++) {
                Math.fabs(sortedTarget[i] - sortedPrev[j]) => float dist;
                if (dist < minDist) {
                    dist => minDist;
                    j => bestMatch;
                }
            }

            if (minDist < (sortedTarget[i] * 0.12)) {
                sortedPrev[bestMatch] => targetFreqs[i];
            }
        }
    }

    fun void bubbleSort(float arr[], int size) {
        for (0 => int i; i < size - 1; i++) {
            for (0 => int j; j < size - 1 - i; j++) {
                if (arr[j] > arr[j + 1]) {
                    arr[j] => float temp;
                    arr[j + 1] => arr[j];
                    temp => arr[j + 1];
                }
            }
        }
    }

    fun void updateSpectralFilter(int voiceIdx, float velocity, float gridActivity, int section) {
        (300.0 + (section * 200.0)) $ float => float sectionBase;
        sectionBase + (velocity * 800.0) $ float => float baseFreq;
        baseFreq + (gridActivity * 600.0) $ float => float finalFreq;
        finalFreq + (voiceIdx * 80) $ float => float voiceFreq;
        Math.min(voiceFreq, 4000.0) $ float => filters[voiceIdx].pfreq;

        (0.95 + (velocity * 0.02) + (section * 0.004)) $ float => float resonance;
        Math.min(resonance, 0.98) $ float => filters[voiceIdx].prad;
    }

    fun void stop() {
        for (0 => int i; i < MAX_CHORD_VOICES; i++) {
            envs[i].keyOff();
        }
    }

    fun void releaseVoices(int numVoices) {
        150::ms => now;
        for (0 => int i; i < numVoices; i++) {
            envs[i].keyOff();
        }
    }
}

class SnareSynth extends Chugraph {
    TriOsc osc => ADSR env => BiQuad filter => PRCRev rev => outlet;

    fun void init() {
        env.set(5::ms, 150::ms, 0.3, 300::ms);
        0.95 => filter.prad;
        3500.0 => filter.pfreq;
        2 => filter.eqzs;
        0.08 => rev.mix;
        GAIN * 2.2 => osc.gain;
        GAIN * 1.5 => filter.gain;
    }

    fun void play(float freq, float velocity, int section) {
        freq => osc.freq;

        GAIN * (2.2 + (section * 0.15)) $ float => float gainVal;
        Math.min(gainVal, GAIN * 3.5) $ float => osc.gain;

        (3500.0 + (velocity * 3000.0) + (section * 400.0)) $ float => float filterFreq;
        Math.min(filterFreq, 8000.0) $ float => filter.pfreq;

        (0.08 + (velocity * 0.08) + (section * 0.01)) $ float => rev.mix;

        env.keyOn();
        spork ~ releaseEnv();
    }

    fun void releaseEnv() {
        120::ms => now;
        env.keyOff();
    }
}

class FloorTomSynth extends Chugraph {
    SawOsc osc => ADSR env => BiQuad filter => PRCRev rev => outlet;

    fun void init() {
        env.set(10::ms, 200::ms, 0.4, 500::ms);
        0.95 => filter.prad;
        900.0 => filter.pfreq;
        2 => filter.eqzs;
        0.05 => rev.mix;
        GAIN * 0.3 => osc.gain;
        GAIN * 0.4 => filter.gain;
    }

    fun void play(float freq, float velocity, int section) {
        freq => osc.freq;

        if (section >= 4) {
            GAIN * (0.3 + (3 * 0.05)) $ float => osc.gain;
        } else {
            GAIN * (0.3 + (section * 0.05)) $ float => osc.gain;
        }

        if (section >= 4) {
            (900.0 + (velocity * 1500.0) + (3 * 300.0)) $ float => filter.pfreq;
        } else {
            (900.0 + (velocity * 1500.0) + (section * 300.0)) $ float => filter.pfreq;
        }

        Math.min(section, 2) $ int => int cappedSection;
        (0.05 + (velocity * 0.05) + (cappedSection * 0.008)) $ float => rev.mix;

        env.keyOn();
        spork ~ releaseEnv();
    }

    fun void releaseEnv() {
        80::ms => now;
        env.keyOff();
    }
}

class CrashSynth extends Chugraph {
    PulseOsc osc => ADSR env => Echo echo => PRCRev rev => outlet;

    fun void init() {
        env.set(5::ms, 100::ms, 0.5, 400::ms);
        250::ms => echo.max => echo.delay;
        0.3 => echo.mix;
        0.4 => echo.gain;
        0.05 => rev.mix;
        GAIN * 0.5 => osc.gain;
    }

    fun void play(float freq, float velocity, int section) {
        freq => osc.freq;

        if (section >= 3) {
            GAIN * (0.5 + (1 * 0.04)) $ float => osc.gain;
        } else {
            GAIN * (0.5 + (section * 0.08)) $ float => osc.gain;
        }

        (0.4 + (velocity * 0.4) + (section * 0.1)) $ float => echo.gain;

        Math.min(section, 2) $ int => int cappedSection;
        if (section >= 4) {
            (0.05 + (velocity * 0.03) + (cappedSection * 0.005)) $ float => rev.mix;
        } else {
            (0.05 + (velocity * 0.06) + (cappedSection * 0.01)) $ float => rev.mix;
        }

        env.keyOn();
        spork ~ releaseEnv();
    }

    fun void playPolyrhythmic(float freq, float velocity, int section) {
        play(freq, velocity, section);

        if (section >= 4 && Math.random2(0, 3) == 0) {
            spork ~ delayedNote(freq * 1.5, velocity * 0.8, section, 50::ms);
            spork ~ delayedNote(freq * 0.75, velocity * 0.6, section, 100::ms);
            spork ~ delayedNote(freq * 2.0, velocity * 0.7, section, 150::ms);
        }
    }

    fun void delayedNote(float freq, float velocity, int section, dur delay) {
        delay => now;
        play(freq, velocity, section);
    }

    fun void releaseEnv() {
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
        1200.0 => filter.freq;
        3.0 => filter.Q;
        0.15 => rev.mix;
        GAIN * 0.08 => noise.gain;

        clickEnv.set(1::ms, 5::ms, 0.0, 10::ms);
        5500.0 => clickFilter.freq;
        2.0 => clickFilter.Q;
        GAIN * 0.4 => click.gain;

        rumbleEnv.set(500::ms, 1000::ms, 0.4, 2000::ms);
        85.0 => rumbleFilter.freq;
        1.0 => rumbleFilter.Q;
        GAIN * 0.15 => rumble.gain;
    }

    fun void burst(float velocity, int section) {
        Math.random2f(600, 3500) + (velocity * 1500.0) + (section * 300.0) $ float => float burstFreq;
        Math.min(burstFreq, 6000.0) $ float => filter.freq;
        Math.random2f(2.0, 6.0) + (velocity * 2.0) $ float => filter.Q;

        Math.min(section, 2) $ int => int cappedSection;
        (0.15 + (velocity * 0.06) + (cappedSection * 0.01)) $ float => rev.mix;
        GAIN * (0.08 + (section * 0.02)) $ float => noise.gain;

        env.keyOn();
        spork ~ releaseBurst();
    }

    fun void clickSound(float velocity, int section) {
        Math.random2f(4000, 8000) + (velocity * 1500.0) + (section * 300.0) $ float => float clickFreq;
        Math.min(clickFreq, 10000.0) $ float => clickFilter.freq;
        GAIN * (0.4 + (section * 0.05)) $ float => click.gain;

        1.0 => click.next;
        clickEnv.keyOn();
        spork ~ releaseClick();
    }

    fun void rumbleSound(float velocity, float baseFreq, int section) {
        baseFreq * 0.25 $ float => rumble.freq;
        GAIN * (0.15 + (section * 0.05)) $ float => rumble.gain;

        Math.min(section, 2) $ int => int cappedSection;
        (0.15 + (velocity * 0.06) + (cappedSection * 0.01)) $ float => rev.mix;

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

class RhythmEcho extends Chugraph {
    Shakers shaker => PRCRev rev => outlet;
    float rhythmTimes[32];
    0 => int rhythmIndex;
    now => time startTime;
    0 => int hasStarted;

    fun void init() {
        7 => shaker.which;
        0.12 => rev.mix;
        GAIN * 0.7 => shaker.gain;

        for (0 => int i; i < rhythmTimes.size(); i++) {
            0.0 => rhythmTimes[i];
        }
    }

    fun void recordHit() {
        if (hasStarted == 0) {
            now => startTime;
            1 => hasStarted;
            0.0 => rhythmTimes[rhythmIndex];
        } else {
            (now - startTime) / 1::second => rhythmTimes[rhythmIndex];
        }
        (rhythmIndex + 1) % rhythmTimes.size() => rhythmIndex;
    }

    fun void playback(float speed, int section) {
        if (rhythmIndex < 2) return;

        GAIN * (0.7 + (section * 0.05)) $ float => shaker.gain;

        0 => int startIdx;
        rhythmIndex => int endIdx;
        if (rhythmIndex > 8) rhythmIndex - 8 => startIdx;

        for (0 => int i; i < (endIdx - startIdx - 1); i++) {
            (startIdx + i) % rhythmTimes.size() => int curIdx;
            (startIdx + i + 1) % rhythmTimes.size() => int nextIdx;

            rhythmTimes[nextIdx] - rhythmTimes[curIdx] => float interval;

            if (interval > 0.04 && interval < 4.5) {
                Math.random2(5, 12) => shaker.which;
                Math.random2f(70, 140) + (section * 15) $ float => shaker.freq;
                Math.random2f(25, 90) + (section * 10) $ float => shaker.objects;
                shaker.noteOn(Math.random2f(8, 20) + (section * 3) $ float);
                (interval / speed)::second => now;
            }
        }
    }
}

// ============================================================
// CONWAY'S GAME OF LIFE ENGINE
// ============================================================

class ConwayEngine {
    int grid[GRID_HEIGHT][GRID_WIDTH];
    int nextGrid[GRID_HEIGHT][GRID_WIDTH];

    0 => int generation;
    0 => int stableCount;
    0 => int currentSection;
    0 => int totalGenerations;

    fun void init() {
        for (0 => int y; y < GRID_HEIGHT; y++) {
            for (0 => int x; x < GRID_WIDTH; x++) {
                INITIAL_PATTERN[y][x] => grid[y][x];
            }
        }

        if (START_GENERATION > 0) {
            START_GENERATION => totalGenerations;
            START_GENERATION / GENERATIONS_PER_SECTION => currentSection;
            START_GENERATION % GENERATIONS_PER_SECTION => generation;
        } else {
            START_SECTION => currentSection;
            START_SECTION * GENERATIONS_PER_SECTION => totalGenerations;
            0 => generation;
        }

        injectSimplePattern();

        if (START_GENERATION > 0 || START_SECTION > 0) {
            <<< "=== STARTING AT GENERATION", totalGenerations, "SECTION", currentSection, "===" >>>;
            printSectionChange();
        }
    }

    fun int countNeighbors(int y, int x) {
        0 => int count;
        for (-1 => int dy; dy <= 1; dy++) {
            for (-1 => int dx; dx <= 1; dx++) {
                if (dy == 0 && dx == 0) continue;
                (y + dy + GRID_HEIGHT) % GRID_HEIGHT => int ny;
                (x + dx + GRID_WIDTH) % GRID_WIDTH => int nx;
                count + grid[ny][nx] => count;
            }
        }
        return count;
    }

    fun float getGridActivity() {
        0 => int livingCells;
        for (0 => int y; y < GRID_HEIGHT; y++) {
            for (0 => int x; x < GRID_WIDTH; x++) {
                livingCells + grid[y][x] => livingCells;
            }
        }
        return livingCells / 64.0;
    }

    fun void nextGeneration() {
        for (0 => int y; y < GRID_HEIGHT; y++) {
            for (0 => int x; x < GRID_WIDTH; x++) {
                countNeighbors(y, x) => int neighbors;
                if (grid[y][x] == 1) {
                    if (neighbors == 2 || neighbors == 3) 1 => nextGrid[y][x];
                    else 0 => nextGrid[y][x];
                } else {
                    if (neighbors == 3) 1 => nextGrid[y][x];
                    else 0 => nextGrid[y][x];
                }
            }
        }

        1 => int hasChanged;
        for (0 => int y; y < GRID_HEIGHT; y++) {
            for (0 => int x; x < GRID_WIDTH; x++) {
                if (nextGrid[y][x] != grid[y][x]) {
                    0 => hasChanged;
                    break;
                }
            }
            if (hasChanged == 0) break;
        }

        for (0 => int y; y < GRID_HEIGHT; y++) {
            for (0 => int x; x < GRID_WIDTH; x++) {
                nextGrid[y][x] => grid[y][x];
            }
        }

        generation++;
        totalGenerations++;
        updateSection();

        if (hasChanged == 1) stableCount + 1 => stableCount;
        else 0 => stableCount;

        0 => int injected;
        getDynamicStabilityThreshold() => int threshold;
        if (stableCount >= threshold) {
            injectLife();
            0 => stableCount;
            1 => injected;
        }

        printGrid(injected);
    }

    fun void updateSection() {
        totalGenerations / GENERATIONS_PER_SECTION => int newSection;
        Math.min(newSection, 4) $ int => newSection;
        if (newSection != currentSection) {
            newSection => currentSection;
            printSectionChange();
        }
    }

    fun void printSectionChange() {
        if (currentSection == 0) <<< "=== SECTION A: Sparse Foundation (1-3 voices) ===" >>>;
        else if (currentSection == 1) <<< "=== SECTION B: Building Energy (3-8 voices) ===" >>>;
        else if (currentSection == 2) <<< "=== SECTION C: Dense Complexity (8-20 voices) ===" >>>;
        else if (currentSection == 3) <<< "=== SECTION D: Approaching Climax (20-40 voices) ===" >>>;
        else <<< "=== SECTION E: CLIMACTIC FINALE (40-64 voices) ===" >>>;
    }

    fun int getKicksToAdvance() {
        if (currentSection == 0) return 8;
        else if (currentSection == 1) return 6;
        else if (currentSection == 2) return 4;
        else if (currentSection == 3) return 2;
        else return 1;
    }

    fun int getDynamicStabilityThreshold() {
        (totalGenerations / 50) $ int => int reductionFactor;
        (STABILITY_THRESHOLD - reductionFactor) $ int => int dynThreshold;

        if (currentSection <= 1) dynThreshold => dynThreshold;
        else if (currentSection == 2) (dynThreshold - 1) $ int => dynThreshold;
        else (dynThreshold - 2) $ int => dynThreshold;

        Math.max(dynThreshold, 1) $ int => dynThreshold;
        return dynThreshold;
    }

    fun void injectLife() {
        totalGenerations / 30 => int densityLevel;

        if (currentSection == 0) {
            injectSimplePattern();
        } else if (currentSection == 1) {
            if (Math.random2(0, 1) == 0) injectSimplePattern();
            else injectMediumPattern();
        } else if (currentSection == 2) {
            if (Math.random2(0, 2) == 0) injectMediumPattern();
            else injectComplexPattern();
            if (densityLevel >= 3 && Math.random2(0, 3) == 0) {
                injectMediumPattern();
            }
        } else if (currentSection == 3) {
            for (0 => int i; i < Math.random2(1, 2 + densityLevel); i++) {
                if (Math.random2(0, 1) == 0) injectMediumPattern();
                else injectComplexPattern();
            }
        } else {
            for (0 => int i; i < Math.random2(2, 4 + densityLevel); i++) {
                if (Math.random2(0, 2) == 0) injectComplexPattern();
                else injectChaosPattern();
            }
            if (densityLevel >= 4) {
                for (0 => int i; i < Math.random2(1, 3); i++) {
                    injectChaosPattern();
                }
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
        1 => grid[startY + 3][startX + 1];
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

    fun void injectChaosPattern() {
        Math.random2(1, GRID_HEIGHT - 6) => int startY;
        Math.random2(1, GRID_WIDTH - 6) => int startX;
        for (0 => int dy; dy < 4; dy++) {
            for (0 => int dx; dx < 4; dx++) {
                if (Math.random2(0, 2) == 0) {
                    1 => grid[startY + dy][startX + dx];
                }
            }
        }
    }

    fun int[] getLivingCells() {
        int livingCells[64];
        0 => int count;
        for (0 => int y; y < GRID_HEIGHT; y++) {
            for (0 => int x; x < GRID_WIDTH; x++) {
                if (grid[y][x] == 1) {
                    y * GRID_WIDTH + x => livingCells[count];
                    count++;
                }
            }
        }
        int result[count];
        for (0 => int i; i < count; i++) {
            livingCells[i] => result[i];
        }
        return result;
    }

    fun void printGrid(int injected) {
        for (0 => int y; y < GRID_HEIGHT; y++) {
            "" => string row;
            for (0 => int x; x < GRID_WIDTH; x++) {
                if (grid[y][x] == 1) row + "1 " => row;
                else row + "0 " => row;
            }
            <<< row >>>;
        }
        if (injected == 1) <<< "*** LIFE INJECTED ***" >>>;
        <<< "Gen: " + generation + " | Total: " + totalGenerations + " | Section: " + currentSection + " | Living: " + getLivingCells().size() >>>;
        <<< "================================================" >>>;
    }
}

// ============================================================
// PERFORMANCE STATE
// ============================================================

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

// Activity tracking for generative textures
0 => int kickActivity;
0 => int snareActivity;
0 => int floorTomActivity;
0 => int crashActivity;

// ============================================================
// INSTRUMENT INSTANCES
// ============================================================

BassSynth bass;
ChordSynth chord;
SnareSynth snareSynth;
FloorTomSynth floorTomSynth;
CrashSynth crashSynth;
TextureGenerator texture;
RhythmEcho rhythmEcho;

bass => master;
chord => master;
snareSynth => master;
floorTomSynth => master;
crashSynth => master;
texture => master;
rhythmEcho => master;

// ============================================================
// FREQUENCY CALCULATION
// ============================================================

fun void calculateFrequencies() {
    for (0 => int i; i < 64; i++) {
        BASE_FREQ * DIAMOND_RATIOS[i][0] / DIAMOND_RATIOS[i][1] => diamondFreqs[i];
        while (diamondFreqs[i] < BASE_FREQ * 0.4) diamondFreqs[i] * 2.0 => diamondFreqs[i];
        while (diamondFreqs[i] > BASE_FREQ * 5.0) diamondFreqs[i] / 2.0 => diamondFreqs[i];
    }
    <<< "Tonality diamond frequencies calculated" >>>;
}

// ============================================================
// INITIALIZATION
// ============================================================

fun void init() {
    <<< "=== PARTCHED CONWAY: Cellular Automata + Just Intonation ===" >>>;
    if (START_GENERATION > 0) {
        <<< "Starting generation:", START_GENERATION >>>;
    } else {
        <<< "Starting section:", START_SECTION >>>;
    }

    calculateFrequencies();
    conway.init();

    bass.init();
    chord.init();
    snareSynth.init();
    floorTomSynth.init();
    crashSynth.init();
    texture.init();
    rhythmEcho.init();

    Math.max(1, START_SECTION + 1) $ int => activeVoices;
    SHORT_DURATION => chordDuration;

    for (0 => int i; i < melodicMemory.size(); i++) {
        0 => melodicMemory[i];
    }

    updateMasterReverb();
    updateActiveVoices();
    playCurrentChord(0.5);

    <<< "System initialized - ready for performance!" >>>;
}

// ============================================================
// FADE / REVERB / VOICE SCALING
// ============================================================

fun float getFadeMultiplier() {
    if (conway.totalGenerations < FADE_START_GENERATION) {
        return 1.0;
    } else if (conway.totalGenerations >= FADE_END_GENERATION) {
        return 0.0;
    } else {
        (FADE_END_GENERATION - conway.totalGenerations) / (FADE_END_GENERATION - FADE_START_GENERATION) $ float => float fadeMult;
        return fadeMult;
    }
}

fun void updateMasterReverb() {
    if (conway.currentSection == 0) 0.03 => masterReverb.mix;
    else if (conway.currentSection == 1) 0.05 => masterReverb.mix;
    else if (conway.currentSection == 2) 0.08 => masterReverb.mix;
    else if (conway.currentSection == 3) 0.12 => masterReverb.mix;
    else 0.16 => masterReverb.mix;
}

fun void updateActiveVoices() {
    1 + (conway.totalGenerations / 10) => activeVoices;
    if (activeVoices > 64) 64 => activeVoices;
    if (activeVoices < 1) 1 => activeVoices;
    updateMasterReverb();
}

fun int getChordVoiceCount(int livingCellCount) {
    1 + (conway.totalGenerations / 20) => int chordVoices;
    Math.min(chordVoices, livingCellCount) $ int => chordVoices;
    Math.min(chordVoices, MAX_CHORD_VOICES) $ int => chordVoices;
    Math.max(chordVoices, 1) $ int => chordVoices;
    return chordVoices;
}

// ============================================================
// CHORD PLAYBACK
// ============================================================

fun void playCurrentChord(float velocity) {
    conway.getLivingCells() @=> int livingCells[];
    conway.getGridActivity() => float gridActivity;

    if (livingCells.size() == 0) {
        bass.playMultiOctave(BASE_FREQ, chordDuration::second, velocity, conway.currentSection);
        return;
    }

    // Sort living cells by frequency for voice leading
    int sortedCells[livingCells.size()];
    for (0 => int i; i < livingCells.size(); i++) {
        livingCells[i] => sortedCells[i];
    }
    for (0 => int i; i < sortedCells.size(); i++) {
        sortedCells[i] => int key;
        diamondFreqs[key] => float keyFreq;
        i - 1 => int j;
        while (j >= 0 && diamondFreqs[sortedCells[j]] > keyFreq) {
            sortedCells[j] => sortedCells[j + 1];
            j--;
        }
        key => sortedCells[j + 1];
    }

    // Bass note
    if (sortedCells.size() > 0) {
        Math.random2(0, sortedCells.size() - 1) => int bassNoteIdx;
        Math.random2(1, 2) => int bassOctaveDown;
        diamondFreqs[sortedCells[bassNoteIdx]] / Math.pow(2, bassOctaveDown) => float bassFreq;
        bass.playMultiOctave(bassFreq, chordDuration::second, velocity, conway.currentSection);
    }

    // Chord voices
    getChordVoiceCount(sortedCells.size()) => int voicesToPlay;
    Math.max(voicesToPlay, 1) $ int => voicesToPlay;

    if (voicesToPlay <= 0) {
        <<< "WARNING: voicesToPlay is", voicesToPlay, "- skipping chord" >>>;
        return;
    }

    float chordFreqs[voicesToPlay];
    for (0 => int i; i < voicesToPlay; i++) {
        diamondFreqs[sortedCells[i]] => chordFreqs[i];
    }

    chord.play(chordFreqs, voicesToPlay, chordDuration::second, velocity, gridActivity, conway.currentSection);
}

// ============================================================
// TIMING / ADVANCE LOGIC
// ============================================================

fun int shouldAdvance() {
    if (kickCount >= conway.getKicksToAdvance()) return 1;
    if (now - chordStartTime >= chordDuration::second) return 1;
    return 0;
}

fun void resetTiming() {
    0 => kickCount;
    now => chordStartTime;
}

fun void updateChordDuration() {
    if (hasKickedOnce == 0) {
        SHORT_DURATION => chordDuration;
    } else {
        if (now - lastKickTime >= TIMEOUT_DURATION::second) {
            SHORT_DURATION => chordDuration;
            0 => hasKickedOnce;
        } else {
            LONG_DURATION => chordDuration;
        }
    }
}

// ============================================================
// MELODIC MEMORY
// ============================================================

fun void addToMelodyMemory(int note) {
    note => melodicMemory[memoryIndex];
    (memoryIndex + 1) % melodicMemory.size() => memoryIndex;
}

fun int getRelatedNote(int currentNote) {
    for (0 => int i; i < melodicMemory.size(); i++) {
        melodicMemory[i] => int memNote;
        if (memNote > 0) {
            if (Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.5) < 0.12) {
                return memNote;
            }
            if (Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 1.333) < 0.12) {
                return memNote;
            }
            if (Math.fabs((diamondFreqs[currentNote] / diamondFreqs[memNote]) - 2.0) < 0.12) {
                return memNote;
            }
        }
    }
    return currentNote;
}

// ============================================================
// MIDI HANDLER
// ============================================================

fun void handleMidi(int midiNote, int velocity) {
    (velocity / 127.0) => float vel;

    if (midiNote == KICK_NOTE) {
        // KICK - advances Conway and triggers chord
        kickCount++;
        kickActivity++;
        now => lastKickTime;

        if (velocity > 85) {
            conway.getLivingCells() @=> int livingCells[];
            if (livingCells.size() > 0) {
                texture.rumbleSound(vel, diamondFreqs[livingCells[0]], conway.currentSection);
            } else {
                texture.rumbleSound(vel, BASE_FREQ, conway.currentSection);
            }
        }

        if (hasKickedOnce == 0) {
            1 => hasKickedOnce;
            updateChordDuration();
        }

        if (shouldAdvance()) {
            conway.nextGeneration();
            updateActiveVoices();
            getFadeMultiplier() => fadeGain.gain;
            playCurrentChord(vel);
            resetTiming();
        }

    } else if (midiNote == SNARE_NOTE) {
        // SNARE - textural bursts with related harmonies
        snareActivity++;
        conway.getLivingCells() @=> int livingCells[];

        if (livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIdx;
            livingCells[randomIdx] => int selectedNote;

            if (conway.currentSection >= 1 && melodicMemory[memoryIndex] > 0) {
                getRelatedNote(melodicMemory[memoryIndex]) => selectedNote;
            }

            Math.random2(-1, 1 + conway.currentSection) => int octaveOffset;
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            snareSynth.play(freq, 2.8 * vel, conway.currentSection);
        }

        texture.burst(vel, conway.currentSection);
        if (Math.random2(0, 3 - conway.currentSection) == 0) {
            texture.clickSound(vel, conway.currentSection);
        }

    } else if (midiNote == FLOOR_TOM_NOTE) {
        // FLOOR TOM - melodic memory + rhythm echo recording
        floorTomActivity++;
        rhythmEcho.recordHit();

        conway.getLivingCells() @=> int livingCells[];
        if (livingCells.size() > 0) {
            Math.random2(0, livingCells.size() - 1) => int randomIdx;
            livingCells[randomIdx] => int selectedNote;

            if (conway.currentSection >= 2) {
                getRelatedNote(selectedNote) => selectedNote;
            }

            addToMelodyMemory(selectedNote);

            Math.random2(1, 2 + conway.currentSection) => int octaveOffset;
            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            floorTomSynth.play(freq, 1.6 * vel, conway.currentSection);
        }

        if (Math.random2(0, 2) == 0) {
            texture.clickSound(vel, conway.currentSection);
        }

    } else if (midiNote >= CRASH_MIN && midiNote <= CRASH_MAX) {
        // CRASH - polyrhythmic solo from living cells
        crashActivity++;
        conway.getLivingCells() @=> int livingCells[];
        midiNote - CRASH_MIN => int padIdx;

        if (livingCells.size() > 0) {
            padIdx % livingCells.size() => int chordNoteIdx;
            livingCells[chordNoteIdx] => int selectedNote;

            0 => int octaveOffset;
            if (conway.currentSection == 0) Math.random2(-1, 2) => octaveOffset;
            else if (conway.currentSection == 1) Math.random2(-1, 3) => octaveOffset;
            else if (conway.currentSection == 2) Math.random2(-2, 4) => octaveOffset;
            else Math.random2(-2, 5) => octaveOffset;

            diamondFreqs[selectedNote] * Math.pow(2, octaveOffset) => float freq;
            crashSynth.playPolyrhythmic(freq, 1.8 * vel, conway.currentSection);
        } else {
            padIdx % 64 => int diamondIdx;
            Math.random2(0, 2 + conway.currentSection) => int octaveOffset;
            diamondFreqs[diamondIdx] * Math.pow(2, octaveOffset) => float freq;
            crashSynth.playPolyrhythmic(freq, 1.8 * vel, conway.currentSection);
        }
    }
}

// ============================================================
// CONCURRENT THREADS
// ============================================================

fun void midiListener() {
    while (true) {
        midiIn => now;
        while (midiIn.recv(msg) && msg.data3 != 0) {
            handleMidi(msg.data2, msg.data3);
        }
    }
}

fun void autoAdvance() {
    while (true) {
        100::ms => now;
        updateChordDuration();

        if (shouldAdvance()) {
            conway.nextGeneration();
            updateActiveVoices();
            getFadeMultiplier() => fadeGain.gain;
            playCurrentChord(0.5);
            resetTiming();
        }
    }
}

fun void generativeTextures() {
    while (true) {
        (4.0 - (conway.currentSection * 0.5))::second => now;

        kickActivity + snareActivity + floorTomActivity + crashActivity => int totalActivity;

        int burstThreshold, clickThreshold, rumbleThreshold;

        if (conway.currentSection <= 1) {
            12 => burstThreshold;
            8 => clickThreshold;
            5 => rumbleThreshold;
        } else if (conway.currentSection == 2) {
            8 => burstThreshold;
            5 => clickThreshold;
            3 => rumbleThreshold;
        } else {
            5 => burstThreshold;
            3 => clickThreshold;
            2 => rumbleThreshold;
        }

        if (totalActivity > burstThreshold) {
            if (Math.random2(0, 3) == 0) texture.burst(0.7, conway.currentSection);
        }
        if (totalActivity > clickThreshold) {
            if (Math.random2(0, 4) == 0) texture.clickSound(0.5, conway.currentSection);
        }
        if (totalActivity > rumbleThreshold && conway.currentSection >= 2) {
            if (Math.random2(0, 5) == 0) texture.rumbleSound(0.4, BASE_FREQ, conway.currentSection);
        }

        if (totalActivity > 1) {
            [1.0, 1.5, 0.75, 2.0, 0.5] @=> float speeds[];
            speeds[Math.random2(0, speeds.size() - 1)] => float chosenSpeed;
            spork ~ rhythmEcho.playback(chosenSpeed, conway.currentSection);
        }

        (kickActivity * 0.65) $ int => kickActivity;
        (snareActivity * 0.65) $ int => snareActivity;
        (floorTomActivity * 0.65) $ int => floorTomActivity;
        (crashActivity * 0.65) $ int => crashActivity;
    }
}

// ============================================================
// MAIN
// ============================================================

fun void main() {
    init();

    spork ~ midiListener();
    10::ms => now;
    spork ~ midiListener();
    10::ms => now;
    spork ~ midiListener();
    10::ms => now;
    spork ~ autoAdvance();
    spork ~ generativeTextures();

    while (true) {
        1::second => now;
        if (conway.totalGenerations % 30 == 0 && conway.totalGenerations > 0) {
            <<< "Status - Section:", conway.currentSection,
            "| Voices:", activeVoices,
            "| Activity:", conway.getGridActivity() >>>;
        }
    }
}

main();

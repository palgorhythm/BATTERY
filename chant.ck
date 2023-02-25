// STK StifKarp

// patch
StifKarp m => NRev r => Chorus c => dac;
.9 => r.gain;
.05 => r.mix;

// our notes
[ 36 ] @=> int notes[];

// infinite time-loop
while( true )
{
    Math.random2f( 0.1, 1 ) => m.pickupPosition;
    Math.random2f( 0.1, 1 ) => m.sustain;
    Math.random2f( 0.1, 0.4 ) => m.stretch;
    
    <<< "---", "" >>>;
    <<< "pickup:", m.pickupPosition() >>>;
    <<< "sustain:", m.sustain() >>>;
    <<< "stretch:", m.stretch() >>>;
    
    // factor
    Math.random2f( 1, 4 ) => float factor;
    
    play( Math.random2(0,2)*12 + notes[i], Math.random2f( .6, .9 ) );
}


// fun void playNext() {
//    play( Math.random2(1,2)*12 + notes[i], Math.random2f( .6, .9 ) );
//    100::ms * factor => now;   
//}

// basic play function (add more arguments as needed)
fun void play( float note, float velocity )
{
    // start the note
    Std.mtof( note ) => m.freq;
    velocity => m.pluck;
}
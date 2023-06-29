MidiIn min;
MidiMsg msg;

OscOut osc; 
osc.dest("10.10.10.1",6969);
oscOut("/song",[3]);

0 => int device;
[0,0] @=> int bassindices[];
[0,0] @=> int melodyindices[];
int hitTom;
now + 1000::second => time tomTime;
int hitBass;
now + 1000::second => time bassTime;
int hitSnare;
now + 1000::second => time snareTime;

///NOTE MATRICES BEGIN///

16 => int seqWidth;
32 => int seqHeight;

//START BASS//
int bass[seqHeight][seqWidth];
36 => bass[0][0];
38 => bass[1][0];
33 => bass[2][0];
31 => bass[3][0];
40 => bass[4][0];
45 => bass[5][0];
43 => bass[6][0];
37 => bass[7][0];
36 => bass[8][0];
38 => bass[9][0];
33 => bass[10][0];
31 => bass[11][0];
45 => bass[12][0];
38 => bass[13][0];
44 => bass[14][0];
37 => bass[15][0];
42 => bass[16][0];
35 => bass[17][0];
38 => bass[18][0];
36 => bass[19][0];
39 => bass[20][0];
37 => bass[21][0];
33 => bass[22][0];
31 => bass[23][0];
36 => bass[24][0];
38 => bass[25][0];
33 => bass[26][0];
31 => bass[27][0];
40 => bass[28][0];
33 => bass[29][0];
31 => bass[30][0];
37 => bass[31][0];

for(int i; i<seqHeight; i++)
{
    for(int j; j<seqWidth; j++)
    {
        //bass[i][0] * ((j/2)+1) => bass[i][j];
        bass[i][0] => bass[i][j];
        //<<<bass[i][j]>>>;
        //Std.rand2f(50 + i*50.0, 50 + j*50.0) => freqs[i][j];
        //10 + i* Std.rand2f(-1,5) + j * Std.rand2f(-1,5) => freqs[i][j];
    }
}

//END BASS//

//START SNARE//
[[52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],[54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],
[48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],[50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
[50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],[48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],
[54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],[52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],
[52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],[54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],
[48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],[50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
[50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],[59,59,48,47,52,64,59,62,66,57,55,54,66,64,64,62],
[60,60,60,60,66,66,66,66,60,60,60,60,66,66,66,66],[65,65,65,65,71,71,71,71,65,65,65,65,71,71,71,71],
[70,68,66,68,63,73,61,71,70,68,66,68,63,73,61,71],[70,61,63,68,66,58,63,61,59,70,70,59,65,65,63,63],
[73,73,71,73,66,66,64,66,68,68,61,61,66,66,64,64],[62,62,69,69,64,64,71,71,75,71,66,64,62,64,66,76],
[74,84,79,74,69,67,67,77,74,72,74,74,67,67,65,67],[65,60,60,60,70,65,65,65,75,70,70,70,80,75,75,75],
[71,64,61,68,61,59,71,64,61,68,61,59,71,64,61,59],[57,64,53,59,62,53,57,64,53,59,62,53,61,59,57,50],
[52,55,50,59,57,64,64,62,83,86,86,81,76,78,78,71],[54,52,59,57,48,71,71,66,64,57,50,43,43,54,54,54],
[48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],[50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],
[50,54,47,59,57,52,52,54,69,64,59,54,54,50,50,52],[48,47,59,59,52,64,59,62,66,57,55,54,54,52,52,50],
[52,52,52,52,59,59,59,59,64,64,64,64,71,71,71,71],[76,76,76,76,83,83,83,83,88,88,88,88,95,95,95,95]] @=> int melody[][];
//END SNARE//

///NOTE MATRICES END///

PulseOsc sin => ADSR e1 => BiQuad f => PRCRev reverb1 => dac.left;
.97 => f.prad; 
2 => f.eqzs;
.05 => f.gain;

SawOsc saw => ADSR e2 => PRCRev reverb2 => dac.right;
0.7 => sin.gain;
1.2 => saw.gain;
.001 => reverb1.mix;
0 => reverb2.mix;

//MIDI port
0 => int port;
// open the port

if( !min.open(port))
{
    <<<"ERROR: midi port didn't open on port:", port>>>;
    me.exit();
}

spork ~ ddrumTrig();
5::ms => now;
//spork ~ ddrumTrig();
5::ms => now;
//spork ~ ddrumTrig();
5::ms => now;
spork ~ voiceGate();
5::ms => now;

oscOut("/songSection",[0]);

while(true)
{
    1::second => now;
}

fun void voiceGate()
{
    while(true)
    {
        if(hitTom==1 && (now > tomTime + 1000::ms) )
        {
            0 => hitTom;
        }
        if(hitBass==1 && (now > bassTime + 10::ms) )
        {
            0 => hitBass;
        }
        if(hitSnare==1 && (now > snareTime + 100::ms) )
        {
            0 => hitSnare;
        }
        5::ms => now;
    }
}


fun void ddrumTrig()
{
    while(true)
    {
        min => now;
        //<<<(msg.data3/90.0)>>>;
                
        while(min.recv(msg))
        {
            if(bassindices[0]>15 && bassindices[0]<24)
            {
                e1.set(10::ms, 30::ms, .5, 2500::ms );
                e2.set( 30::ms, 30::ms, .5, 2500::ms );
                .1 => reverb1.mix;
                .1 => reverb2.mix;
            }
            else if(bassindices[0] >= 30)
            {
                e1.set( 50::ms, 30::ms, .8, 2000::ms );
                e2.set( 50::ms, 30::ms, .8, 2000::ms );
                .1 => reverb1.mix;
                .1 => reverb2.mix;
            }
            else
            {
                e1.set( 15::ms, 5::ms, .5, 800::ms );
                e2.set( 15::ms, 6::ms, .5, 800::ms );
                .001 => reverb1.mix;
                .001 => reverb2.mix;
            }
            //<<< msg.data1, msg.data2, msg.data3 >>>;
            if( msg.data3!=0 && msg.data2 == 37 && hitBass == 0 ) //kick drum
            {
                //<<<hitBass>>>;
                1 => hitBass;
                now => bassTime;
                ///<<<now>>>;  
        
                oscOut("/bass",[bass[bassindices[0]][bassindices[1]]]); //OSC!
                
                
                //(msg.data3/90.0) => sin.gain;
                //<<<bass[bassindices[0]][bassindices[1]]>>>;
                setBassFreq() => sin.freq;  //set the frequency
                
                e1.keyOn();
                10::ms => now; 
                e1.keyOff();             
                

                (bassindices[1] + 1 ) % seqWidth => bassindices[1];  
                 
            }   
            else if(msg.data3!=0 && msg.data2 == 36 && hitSnare==0) //snare
            {
              
                1 => hitSnare;
                now => snareTime;
                //(msg.data3/25.0) => saw.gain;
                oscOut("/melody",[melody[melodyindices[0]][melodyindices[1]]]); //OSC!
                setMelodyFreq() => saw.freq;  //set the frequency
                e2.keyOn();
                10::ms => now;
                e2.keyOff();
                
                (melodyindices[1] + 1) % seqWidth => melodyindices[1];
            }
            else if(msg.data3!=0 && msg.data2 == 38 && hitTom == 0) //tom3: down a row
            {
                1 => hitTom;
                now => tomTime;   
                1 => hitBass;
                now => bassTime;
                1 => hitSnare;
                now => snareTime;
                //(msg.data3/25.0) => sin.gain;
                //(msg.data3/25.0) => saw.gain;
                
                if(melodyindices[0] == 16)
                {
                    oscOut("/songSection",[1]);
                }
                else if(melodyindices[0] == 8 || melodyindices[0] == 24)
                {
                    oscOut("/songSection",[0]);
                }
                
                0 => bassindices[1];
                0 => melodyindices[1];
                (bassindices[0] + 1 + seqHeight) % seqHeight => bassindices[0];
                (melodyindices[0] + 1 + seqHeight) % seqHeight => melodyindices[0];
                
                setBassFreq() => sin.freq;  //set the frequency
                setMelodyFreq() => saw.freq;  //set the frequency
                e1.keyOn();
                e2.keyOn();
                10::ms => now;
                e1.keyOff();
                e2.keyOff();
                
                1 => bassindices[1];
                1 => melodyindices[1]; 
            }
            else if(msg.data3!=0 && msg.data2 == 9999) //up a row: NOT USING RN
            {
                //(msg.data3/25.0) => sin.gain;
                //(msg.data3/25.0) => saw.gain;
                0 => bassindices[1];
                0 => melodyindices[1];
                (bassindices[0] - 1 + seqHeight) % seqHeight => bassindices[0];
                (melodyindices[0] - 1 + seqHeight) % seqHeight => melodyindices[0]; //add seqHeight because modulo gets sad when neg
                
                
                setBassFreq() => sin.freq;  //set the frequency
                e1.keyOn();
                setMelodyFreq() => saw.freq;  //set the frequency
                e2.keyOn();
                10::ms => now;
                e1.keyOff();
                e2.keyOff();
                
                1 => bassindices[1];
                1 => melodyindices[1];
            }
        }
    }    
}


fun float setBassFreq()
{
    return Std.mtof(bass[bassindices[0]][bassindices[1]]);   
}

fun float setMelodyFreq()
{
    return Std.mtof(melody[melodyindices[0]][melodyindices[1]]);
}

fun void oscOut(string addr, int val[]){
    osc.start(addr);
    
    for(0 => int i; i<val.size(); i++)
    {
        osc.add(val[i]);
    }
    osc.send();
}
~gladiolaLoadLfoSynthDef = {
    SynthDef(\gladiolaLFO, {
        arg out = 0, shape = 0, rate = 0.25, freeze = 0;
        var sine, square, tri, brown, random, sawUp, sawDown, sig, lfoOut;

        sine    = SinOsc.kr(rate);
        square  = LFPulse.kr(rate, 0, 0.5) * 2 - 1;
        tri     = LFTri.kr(rate);
        brown   = LFNoise2.kr(rate);
        random  = LFNoise0.kr(rate);
        sawUp   = LFSaw.kr(rate, 1);
        sawDown = LFSaw.kr(rate, 1).neg;

        sig = Select.kr(shape, [sine, square, tri, brown, random, sawUp, sawDown]);
        lfoOut = Select.kr(freeze, [sig, Latch.kr(sig, 1 - freeze)]);
        Out.kr(out, lfoOut);
    }).add;
};

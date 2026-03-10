~gladiolaLoadFxSynthDefs = {

    SynthDef(\gladiolaDelay, {
        arg fxSendBus = 0, delaytime = 0.5, feedback = 0.7, tone = 0, level = 0;
        var input, delayed, filtered, lpf, hpf;
        input = In.ar(fxSendBus, 2);
        delayed = CombC.ar(input, 2.0, Lag.kr(delaytime, 0.3), delaytime * 12 * Lag.kr(feedback, 0.1));
        lpf = LPF.ar(delayed, LinExp.kr(tone.linlin(-1, 0, 0, 1), 0, 1, 400, 20000));
        hpf = HPF.ar(delayed, LinExp.kr(tone.linlin(0, 1, 0, 1), 0, 1, 20, 8000));
        filtered = SelectX.ar(Lag.kr(tone, 0.1).linlin(-1, 1, 0, 2), [lpf, delayed, hpf]);
        Out.ar(0, filtered * Lag.kr(level, 0.05));
    }).add;

    SynthDef(\gladiolaGranular, {
        arg fxSendBus = 0, sizeMod = 0, posMod = 0, pitchRange = 0, level = 0;
        var input, sig, trig, stepTrig, posVal, sizeVal, densVal, pitchVal;
        var pitchOffsets = #[-0.396, -0.25, -0.146, 0, 0.146, 0.25, 0.396];
        var pitchIdx, densAvg, rvbVal, fbVal;
        input = In.ar(fxSendBus, 2) * 3;
        stepTrig = \t_trig.tr;
        posVal = 0.5 + (Latch.kr(WhiteNoise.kr, stepTrig) * Lag.kr(posMod, 0.1));
        sizeVal = 0.5 + (Latch.kr(WhiteNoise.kr, stepTrig) * Lag.kr(sizeMod, 0.1));
        densAvg = (Lag.kr(posMod, 0.1) + Lag.kr(sizeMod, 0.1)) * 0.5;
        densVal = 0.6 + (Latch.kr(WhiteNoise.kr, stepTrig) * densAvg);
        pitchIdx = (3 + (Latch.kr(WhiteNoise.kr, stepTrig) * Lag.kr(pitchRange, 0.1) * 3)).round.clip(0, 6);
        pitchVal = 0.5 + Select.kr(pitchIdx, pitchOffsets);
        rvbVal = Lag.kr(sizeMod, 0.1) * 0.5;
        fbVal = Lag.kr(posMod, 0.1) * 0.4;
        trig = Dust.kr(LFNoise1.kr(0.1).linlin(-1, 1, 4, 12));
        sig = MiClouds.ar(
            input[0], input[1],
            pit: pitchVal,
            pos: posVal,
            size: sizeVal,
            dens: densVal,
            tex: 0.5,
            rvb: rvbVal,
            fb: fbVal,
            freeze: 0,
            mode: 0,
            lofi: 0,
            trig: trig
        );
        Out.ar(0, sig * Lag.kr(level, 0.05));
    }).add;

    SynthDef(\gladiolaReverb, {
        arg fxSendBus = 0, size = 0.5, damping = 0.5, level = 0;
        var input, sig;
        input = HPF.ar(In.ar(fxSendBus, 2), 200);
        sig = Greyhole.ar(
            input,
            Lag.kr(size, 0.3).linlin(0, 1, 0.1, 10),
            Lag.kr(damping, 0.1),
            Lag.kr(size, 0.3),
            0.1,
            Lag.kr(size, 0.3).linlin(0, 1, 0.1, 0.5)
        );
        Out.ar(0, sig * Lag.kr(level, 0.05));
    }).add;

    SynthDef(\gladiolaSaturation, {
        arg depth = 0, type = 0, out = 0;
        var sig, dry, wet, dc;
        sig = In.ar(out, 2);
        dry = sig;
        dc = 0.05;
        sig = sig + dc;
        wet = Select.ar(Lag.kr(type, 0.1).round.clip(0, 6), [
            sig.fold2(1),
            sig.tanh,
            sig.softclip,
            sig.clip2(1),
            (sig.abs.pow(0.5) * sig.sign),
            sig.abs,
            (sig * 8).round / 8
        ]);
        wet = LeakDC.ar(wet);
        sig = SelectX.ar(Lag.kr(depth, 0.05), [dry, wet]);
        ReplaceOut.ar(out, sig);
    }).add;

    SynthDef(\gladiolaTilt, {
        arg tilt = 0, out = 0;
        var sig, tiltLag, lowGain, highGain;
        sig = In.ar(out, 2);
        tiltLag = Lag.kr(tilt, 0.1);
        lowGain = tiltLag.neg * 6;  // -6 to +6 dB
        highGain = tiltLag * 6;
        sig = BLowShelf.ar(sig, 300, 1.0, lowGain);
        sig = BHiShelf.ar(sig, 3000, 1.0, highGain);
        ReplaceOut.ar(out, sig);
    }).add;

    SynthDef(\gladiolaCompressor, {
        arg amount = 0, color = 0, out = 0;
        var sig, amtLag, colLag, thresh, ratio, atk, rel, compressed, makeup;
        sig = In.ar(out, 2);
        amtLag = Lag.kr(amount, 0.1);
        colLag = Lag.kr(color, 0.1);
        thresh = amtLag.linlin(0, 1, 1.0, 0.3);
        ratio = amtLag.linlin(0, 1, 1, 0.125);  // 1:1 to 8:1 (reciprocal for Compander)
        atk = colLag.linexp(0, 1, 0.005, 0.3);   // 5ms to 300ms
        rel = colLag.linexp(0, 1, 0.03, 1.5);     // 30ms to 1.5s
        compressed = Compander.ar(sig, sig, thresh, 1, ratio, atk, rel);
        makeup = thresh.reciprocal.pow(1 - ratio);
        compressed = compressed * makeup;
        sig = SelectX.ar(amtLag, [In.ar(out, 2), compressed]);
        ReplaceOut.ar(out, sig);
    }).add;

    SynthDef(\gladiolaLimiter, {
        arg out = 0;
        var sig;
        sig = In.ar(out, 2);
        sig = Limiter.ar(sig, 0.95);
        ReplaceOut.ar(out, sig);
    }).add;
};

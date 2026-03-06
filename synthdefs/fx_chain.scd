~gladiolaLoadFxSynthDefs = {

    SynthDef(\gladiolaDelay, {
        arg fxSendBus = 0, delaytime = 0.5, feedback = 0.7, tone = 0, level = 0, out = 0;
        var input, delayed, filtered, lpf, hpf;
        input = In.ar(fxSendBus, 2);
        delayed = CombC.ar(input, 2.0, Lag.kr(delaytime, 0.3), delaytime * 12 * Lag.kr(feedback, 0.1));
        lpf = LPF.ar(delayed, LinExp.kr(tone.linlin(-1, 0, 0, 1), 0, 1, 400, 20000));
        hpf = HPF.ar(delayed, LinExp.kr(tone.linlin(0, 1, 0, 1), 0, 1, 20, 8000));
        filtered = SelectX.ar(Lag.kr(tone, 0.1).linlin(-1, 1, 0, 2), [lpf, delayed, hpf]);
        Out.ar(out, filtered * Lag.kr(level, 0.05));
    }).add;

    SynthDef(\gladiolaGranular, {
        arg fxSendBus = 0, size = 0.5, position = 0.5, pitch = 0.5, level = 0,
            modDepth = 0, out = 0;
        var input, sig, trig, posLag, sizeLag, posMod, sizeMod, densMod, modLag;
        input = In.ar(fxSendBus, 2) * 1.5;
        modLag = Lag.kr(modDepth, 0.1);
        posLag = Lag.kr(position, 0.1);
        sizeLag = Lag.kr(size, 0.1);
        posMod = posLag + (Latch.kr(WhiteNoise.kr, \t_trig.tr) * modLag);
        sizeMod = sizeLag + (Latch.kr(WhiteNoise.kr, \t_trig.tr) * modLag);
        densMod = Latch.kr(WhiteNoise.kr, \t_trig.tr).linlin(-1, 1, 0.3, 0.9) * modLag + (0.6 * (1 - modLag));
        trig = Dust.kr(LFNoise1.kr(0.1).linlin(-1, 1, 4, 12));
        sig = MiClouds.ar(
            input[0], input[1],
            pit: Lag.kr(pitch, 0.1),
            pos: posMod,
            size: sizeMod,
            dens: densMod,
            tex: 0.5,
            rvb: 0,
            freeze: 0,
            mode: 0,
            lofi: 0,
            trig: trig
        );
        Out.ar(out, sig * Lag.kr(level, 0.05));
    }).add;

    SynthDef(\gladiolaReverb, {
        arg fxSendBus = 0, size = 0.5, damping = 0.5, level = 0, out = 0;
        var input, sig;
        input = HPF.ar(In.ar(fxSendBus, 2), 200);
        sig = Greyhole.ar(
            input,
            Lag.kr(size, 0.3).linlin(0, 1, 0.1, 10),
            Lag.kr(damping, 0.1),
            Lag.kr(size, 0.3),
            0.1,
            Lag.kr(size, 0.3).linlin(0, 1, 0.5, 2)
        );
        Out.ar(out, sig * Lag.kr(level, 0.05));
    }).add;

    SynthDef(\gladiolaSaturation, {
        arg depth = 0, type = 0, out = 0;
        var sig, softclipped, tanhed, folded, wet;
        sig = In.ar(out, 2);
        softclipped = (sig * 2).softclip;
        tanhed = (sig * 3).tanh;
        folded = sig.fold(-0.8, 0.8) * 1.25;
        // type: 0=softclip, 0.5=tanh, 1.0=fold
        wet = SelectX.ar(Lag.kr(type, 0.1) * 2, [softclipped, tanhed, folded]);
        sig = SelectX.ar(Lag.kr(depth, 0.05), [sig, wet]);
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
        var sig, amtLag, colLag, thresh, ratio, atk, rel, compressed;
        sig = In.ar(out, 2);
        amtLag = Lag.kr(amount, 0.1);
        colLag = Lag.kr(color, 0.1);
        thresh = amtLag.linlin(0, 1, 1.0, 0.1);
        ratio = amtLag.linlin(0, 1, 1, 0.25);  // 1:1 to 4:1 (reciprocal for Compander)
        atk = colLag.linexp(0, 1, 0.01, 0.1);   // fast to slow attack
        rel = colLag.linexp(0, 1, 0.05, 0.5);    // fast to slow release
        compressed = Compander.ar(sig, sig, thresh, 1, ratio, atk, rel);
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

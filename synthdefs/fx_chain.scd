~gladiolaLoadFxSynthDefs = {

    SynthDef(\gladiolaClouds, {
        arg fxSendBus = 0, inGain = 1.0, pit = 0.5, pos = 0.5, size = 0.25,
            dens = 0.4, tex = 0.5, spread = 0.5, fb = 0, rvb = 0,
            freeze = 0, mode = 0, lofi = 0, trigRate = 0,
            lfoBus = 0, lfoRate = 0.25,
            modInGain = 0, modPit = 0, modPos = 0, modSize = 0, modDens = 0,
            modTex = 0, modSpread = 0, modFb = 0, modRvb = 0,
            phaseInGain = 0, phasePit = 0, phasePos = 0, phaseSize = 0, phaseDens = 0,
            phaseTex = 0, phaseSpread = 0, phaseFb = 0, phaseRvb = 0;
        var lfo, safeLfoRate;
        var lfoInGain, lfoPit, lfoPos, lfoSize, lfoDens, lfoTex, lfoSpread, lfoFb, lfoRvb;
        var modGain, modPitVal, modPosVal, modSizeVal, modDensVal, modTexVal;
        var modSpreadVal, modFbVal, modRvbVal;
        var input, trig, sig;

        lfo = In.kr(lfoBus, 1);
        safeLfoRate = lfoRate.max(0.001);

        lfoInGain = DelayC.kr(lfo, 4.0, (1.0 - phaseInGain).mod(1.0) / safeLfoRate);
        lfoPit    = DelayC.kr(lfo, 4.0, (1.0 - phasePit).mod(1.0) / safeLfoRate);
        lfoPos    = DelayC.kr(lfo, 4.0, (1.0 - phasePos).mod(1.0) / safeLfoRate);
        lfoSize   = DelayC.kr(lfo, 4.0, (1.0 - phaseSize).mod(1.0) / safeLfoRate);
        lfoDens   = DelayC.kr(lfo, 4.0, (1.0 - phaseDens).mod(1.0) / safeLfoRate);
        lfoTex    = DelayC.kr(lfo, 4.0, (1.0 - phaseTex).mod(1.0) / safeLfoRate);
        lfoSpread = DelayC.kr(lfo, 4.0, (1.0 - phaseSpread).mod(1.0) / safeLfoRate);
        lfoFb     = DelayC.kr(lfo, 4.0, (1.0 - phaseFb).mod(1.0) / safeLfoRate);
        lfoRvb    = DelayC.kr(lfo, 4.0, (1.0 - phaseRvb).mod(1.0) / safeLfoRate);

        modGain     = (inGain + (lfoInGain * modInGain)).clip(0.25, 4.0);
        modPitVal   = pit + (lfoPit * modPit);
        modPosVal   = (pos + (lfoPos * modPos)).clip(0, 1);
        modSizeVal  = (size + (lfoSize * modSize)).clip(0, 1);
        modDensVal  = (dens + (lfoDens * modDens)).clip(0, 1);
        modTexVal   = (tex + (lfoTex * modTex)).clip(0, 1);
        modSpreadVal = (spread + (lfoSpread * modSpread)).clip(0, 1);
        modFbVal    = (fb + (lfoFb * modFb)).clip(0, 0.6);
        modRvbVal   = (rvb + (lfoRvb * modRvb)).clip(0, 1);

        input = In.ar(fxSendBus, 2) * Lag.kr(modGain, 0.05);
        trig = \t_trig.tr + Dust.kr(trigRate);

        sig = MiClouds.ar(
            input[0], input[1],
            pit:    Lag.kr(modPitVal,    0.05),
            pos:    Lag.kr(modPosVal,    0.05),
            size:   Lag.kr(modSizeVal,   0.05),
            dens:   Lag.kr(modDensVal,   0.05),
            tex:    Lag.kr(modTexVal,    0.05),
            spread: Lag.kr(modSpreadVal, 0.05),
            fb:     Lag.kr(modFbVal,     0.05),
            rvb:    Lag.kr(modRvbVal,    0.05),
            freeze: freeze,
            mode:   mode,
            lofi:   lofi,
            trig:   trig
        );

        Out.ar(0, sig);
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

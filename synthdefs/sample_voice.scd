~gladiolaLoadSynthDefs = {

    SynthDef(\gladiolaSample, {
        arg bufnum = 0,
            rate = 1.0,
            amp = 1.0,
            loopLength = 0.0,
            loopRegion = 0.0,
            ratchet = 1,
            stepDur = 0.125,
            t_trig = 0,
            out = 0,
            gateLength = 1.0,
            reverse = 0,
            filter = 0.0,
            pan = 0.0,
            delaySend = 0.0,
            bitcrush = 0.0,
            fxSendBus = 0,
            trackAmp = 1.0,
            attack = 0.002;

        var smoothRate, smoothAmp,
            clampedRatchet, safeStepDur, ratchetFreq, ratchetImpulse,
            count, latch, gatedPulse, combinedTrig,
            gateDur, holdDur, env,
            bufFrames, bufRate, startFrame, loopFrames, oneShot, loopEnd,
            phasorStart, phasorEnd, phasorResetPos, phasorRate, phasor,
            sig,
            crushed, filterFreq, filterSig, filterSelect, lpf, hpf,
            panned;

        smoothRate = Lag.kr(rate, 0.05);
        smoothAmp  = Lag.kr(amp,  0.05);

        clampedRatchet = ratchet.clip(1, 8).round(1);
        safeStepDur    = stepDur.max(ControlDur.ir);

        ratchetFreq    = clampedRatchet / safeStepDur;
        ratchetImpulse = Impulse.kr(ratchetFreq);

        count      = PulseCount.kr(ratchetImpulse, t_trig);
        latch      = (count < (clampedRatchet - 1));
        gatedPulse = ratchetImpulse * latch;

        combinedTrig = Trig1.kr(max(t_trig, gatedPulse), ControlDur.ir);

        gateDur = safeStepDur * gateLength.clip(0.01, 100.0) / clampedRatchet;
        holdDur = (gateDur - (attack + 0.01)).max(0.0);
        env = EnvGen.kr(
            Env.new([0, 1, 1, 0], [attack, holdDur, 0.01], [2, 0, -4]),
            gate: combinedTrig
        );

        bufFrames  = BufFrames.kr(bufnum);
        bufRate    = BufRateScale.kr(bufnum);
        startFrame = loopRegion * bufFrames;
        loopFrames = loopLength * stepDur * SampleRate.ir;

        oneShot = (loopLength <= 0);

        loopEnd = Select.kr(oneShot, [
            startFrame + loopFrames,
            bufFrames
        ]);

        phasorStart    = Select.kr(reverse, [startFrame, loopEnd]);
        phasorEnd      = Select.kr(reverse, [loopEnd, startFrame]);
        phasorResetPos = Select.kr(reverse, [startFrame, loopEnd]);
        phasorRate     = Select.kr(reverse, [bufRate * smoothRate, bufRate * smoothRate * -1]);

        phasor = Phasor.ar(
            trig:     combinedTrig,
            rate:     phasorRate,
            start:    phasorStart,
            end:      phasorEnd,
            resetPos: phasorResetPos
        );

        sig = BufRd.ar(
            numChannels:   1,
            bufnum:        bufnum,
            phase:         phasor,
            loop:          1 - oneShot,
            interpolation: 4
        );

        sig = sig * env * smoothAmp * Lag.kr(trackAmp, 0.05);

        crushed = Decimator.ar(sig, 44100 * (1 - (bitcrush * 0.9)), 24 - (bitcrush * 20));
        sig = SelectX.ar(bitcrush, [sig, crushed]);

        lpf          = RLPF.ar(sig, LinExp.kr(filter.neg.clip(0, 1), 0, 1, 20000, 60), 0.4);
        hpf          = RHPF.ar(sig, LinExp.kr(filter.clip(0, 1), 0, 1, 20, 12000), 0.4);
        filterSelect = K2A.ar(filter > 0);
        filterSig    = SelectX.ar(filterSelect, [lpf, hpf]);
        sig          = SelectX.ar(filter.abs, [sig, filterSig]);

        panned = Pan2.ar(sig, pan);

        Out.ar(fxSendBus, panned * delaySend);
        Out.ar(out, panned);
    }).add;

};

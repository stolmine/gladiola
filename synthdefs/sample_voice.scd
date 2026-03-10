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
            attack = 0.002,
            sliceMode = 0,
            sliceIdx = 0,
            lfoBus = 0,
            modPitch = 0, modVelocity = 0, modGateLength = 0, modFilter = 0,
            modPan = 0, modDelaySend = 0, modAttack = 0, modReverse = 0,
            modLoopLength = 0, modLoopRegion = 0, modRatchet = 0, modBitcrush = 0,
            lfoRate = 1,
            phasePitch = 0, phaseVelocity = 0, phaseGateLength = 0, phaseFilter = 0,
            phasePan = 0, phaseDelaySend = 0, phaseAttack = 0, phaseReverse = 0,
            phaseLoopLength = 0, phaseLoopRegion = 0, phaseRatchet = 0, phaseBitcrush = 0;

        var smoothRate, smoothAmp,
            clampedRatchet, safeStepDur, ratchetFreq, ratchetImpulse,
            count, latch, gatedPulse, combinedTrig,
            gateDur, holdDur, env,
            bufFrames, bufRate, startFrame, loopFrames, oneShot, loopEnd,
            phasorStart, phasorEnd, phasorResetPos, phasorRate, phasor,
            sig,
            crushed, filterFreq, filterSig, filterSelect, lpf, hpf,
            panned,
            lfo, lfoLatched,
            lfoPitch, lfoVelocity, lfoGateLength, lfoFilter, lfoPan, lfoDelaySend,
            lfoAttack, lfoReverse, lfoLoopLength, lfoLoopRegion, lfoRatchet, lfoBitcrush,
            safeLfoRate,
            sliceStartFrame, sliceEndFrame, slicePhasor, sliceSig;

        lfo = In.kr(lfoBus, 1);
        safeLfoRate = lfoRate.max(0.01);

        // Per-destination phase-shifted LFO signals via DelayC
        lfoPitch      = DelayC.kr(lfo, 1.0, (1.0 - phasePitch).mod(1.0) / safeLfoRate);
        lfoVelocity   = DelayC.kr(lfo, 1.0, (1.0 - phaseVelocity).mod(1.0) / safeLfoRate);
        lfoGateLength = DelayC.kr(lfo, 1.0, (1.0 - phaseGateLength).mod(1.0) / safeLfoRate);
        lfoFilter     = DelayC.kr(lfo, 1.0, (1.0 - phaseFilter).mod(1.0) / safeLfoRate);
        lfoPan        = DelayC.kr(lfo, 1.0, (1.0 - phasePan).mod(1.0) / safeLfoRate);
        lfoDelaySend  = DelayC.kr(lfo, 1.0, (1.0 - phaseDelaySend).mod(1.0) / safeLfoRate);
        lfoAttack     = DelayC.kr(lfo, 1.0, (1.0 - phaseAttack).mod(1.0) / safeLfoRate);
        lfoReverse    = DelayC.kr(lfo, 1.0, (1.0 - phaseReverse).mod(1.0) / safeLfoRate);
        lfoLoopLength = DelayC.kr(lfo, 1.0, (1.0 - phaseLoopLength).mod(1.0) / safeLfoRate);
        lfoLoopRegion = DelayC.kr(lfo, 1.0, (1.0 - phaseLoopRegion).mod(1.0) / safeLfoRate);
        lfoRatchet    = DelayC.kr(lfo, 1.0, (1.0 - phaseRatchet).mod(1.0) / safeLfoRate);
        lfoBitcrush   = DelayC.kr(lfo, 1.0, (1.0 - phaseBitcrush).mod(1.0) / safeLfoRate);

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

        lfoLatched = Latch.kr(lfo, combinedTrig);

        // Apply LFO modulation (per-destination phase-shifted signals)
        smoothRate = smoothRate * (2 ** (lfoPitch * modPitch));
        smoothAmp = (smoothAmp + (lfoVelocity * modVelocity * 0.5)).clip(0, 2);
        gateLength = (gateLength * (1 + (lfoGateLength * modGateLength))).clip(0.01, 100);
        filter = (filter + (lfoFilter * modFilter)).clip(-1, 1);
        pan = (pan + (lfoPan * modPan)).clip(-1, 1);
        delaySend = (delaySend + (lfoDelaySend * modDelaySend)).clip(0, 1);
        attack = (attack * (1 + (lfoAttack * modAttack * 4))).clip(0.002, 0.5);
        reverse = Select.kr((Latch.kr(lfoReverse, combinedTrig) * modReverse).abs > 0.5, [reverse, 1 - reverse]);
        loopLength = (loopLength + (lfoLoopLength * modLoopLength * 4)).clip(0, 8);
        loopRegion = (loopRegion + (lfoLoopRegion * modLoopRegion)).clip(0, 1);
        ratchet = (ratchet + (Latch.kr(lfoRatchet, combinedTrig) * modRatchet * 7)).round.clip(1, 8);
        bitcrush = (bitcrush + (lfoBitcrush * modBitcrush)).clip(0, 1);

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

        // One-shot: silence after first pass through buffer to prevent looping
        {
            var playLen = (loopEnd - startFrame).abs.max(1);
            var sweepSamples = Sweep.ar(combinedTrig, SampleRate.ir * bufRate * smoothRate.abs);
            sig = sig * (1 - (oneShot * (sweepSamples >= playLen)));
        }.value;

        // Slice path — 16 equal divisions of buffer, simple repitch
        sliceStartFrame = (sliceIdx / 16) * bufFrames;
        sliceEndFrame   = ((sliceIdx + 1) / 16) * bufFrames;

        slicePhasor = Phasor.ar(
            trig:     combinedTrig,
            rate:     Select.kr(reverse, [bufRate * smoothRate, bufRate * smoothRate * -1]),
            start:    Select.kr(reverse, [sliceStartFrame, sliceEndFrame]),
            end:      Select.kr(reverse, [sliceEndFrame, sliceStartFrame]),
            resetPos: Select.kr(reverse, [sliceStartFrame, sliceEndFrame])
        );

        sliceSig = BufRd.ar(1, bufnum, slicePhasor, loop: 0, interpolation: 4);

        // Slice one-shot: silence after first pass through slice region
        {
            var sliceLen = (sliceEndFrame - sliceStartFrame).abs.max(1);
            var sweepSamples = Sweep.ar(combinedTrig, SampleRate.ir * bufRate * smoothRate.abs);
            sliceSig = sliceSig * (1 - (sweepSamples >= sliceLen));
        }.value;

        sig = Select.ar(sliceMode, [sig, sliceSig]);

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

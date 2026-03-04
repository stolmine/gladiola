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
            out = 0;

        var smoothRate = Lag.kr(rate, 0.05);
        var smoothAmp  = Lag.kr(amp,  0.05);

        // Ratchet: t_trig is pulse 0 (immediate); Impulse supplies pulses 1..N-1.
        // PulseCount resets to 0 on t_trig, so the latch opens for counts 0..(N-2),
        // producing exactly N-1 extra pulses — N total including the original t_trig.
        // stepDur is guarded against zero to prevent Impulse.kr(inf).

        var clampedRatchet = ratchet.clip(1, 8).round(1);
        var safeStepDur    = stepDur.max(ControlDur.ir);

        var ratchetFreq    = clampedRatchet / safeStepDur;
        var ratchetImpulse = Impulse.kr(ratchetFreq);

        var count      = PulseCount.kr(ratchetImpulse, t_trig);
        var latch      = (count < (clampedRatchet - 1));
        var gatedPulse = ratchetImpulse * latch;

        var combinedTrig = Trig1.kr(max(t_trig, gatedPulse), ControlDur.ir);

        // Gate envelope: sustains at full level for step duration, short release to avoid clicks.
        // stepDur divided by ratchet count so each ratchet hit gets its own gate.
        var gateDur = safeStepDur / clampedRatchet;
        var env = EnvGen.kr(
            Env.new([0, 1, 1, 0], [0.002, gateDur - 0.012, 0.01], [2, 0, -4]),
            gate: combinedTrig
        );

        var bufFrames  = BufFrames.kr(bufnum);
        var bufRate    = BufRateScale.kr(bufnum);
        var startFrame = loopRegion * bufFrames;
        var loopFrames = loopLength * bufFrames;

        // loopLength == 0 → one-shot: phasor runs from loopRegion to end of buffer.
        // loopLength >  0 → loop: phasor wraps within [loopRegion, loopRegion + loopLength].
        // loopRegion and loopLength are not lagged: changes take effect on the next trigger
        // rather than drifting mid-playback, which would cause transient zero-length loops.
        var oneShot = (loopLength <= 0);

        var loopEnd = Select.kr(oneShot, [
            startFrame + loopFrames,
            bufFrames
        ]);

        // Phasor resets to startFrame on each combinedTrig.
        // BufRd loop=0 in one-shot mode holds final sample when phasor exceeds bufFrames;
        // BufRd loop=1 in loop mode wraps within the Phasor-defined region.
        var phasor = Phasor.ar(
            trig:     combinedTrig,
            rate:     bufRate * smoothRate,
            start:    startFrame,
            end:      loopEnd,
            resetPos: startFrame
        );

        var sig = BufRd.ar(
            numChannels:   1,
            bufnum:        bufnum,
            phase:         phasor,
            loop:          1 - oneShot,
            interpolation: 4
        );

        sig = sig * env * smoothAmp;

        Out.ar(out, Pan2.ar(sig, 0.0));
    }).add;

};

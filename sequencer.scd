(
var defaultStep = {
    Dictionary.newFrom([
        \on,          false,
        \bank,        0,
        \sample,      0,
        \pitch,       1.0,
        \velocity,    1.0,
        \loopLength,  0.0,
        \loopRegion,  0.0,
        \ratchet,     1,
        \attack,      0.002,
        \gateLength,  1.0,
        \reverse,     false,
        \filter,      0.0,
        \pan,         0.0,
        \probability, 1.0,
        \delaySend,   0.0,
        \bitcrush,    0.0,
        \sliceIdx,    0,
        \condMode,    false,
        \condN,       1,
        \condM,       2,
        \condCount,   0,
        \subSteps,    Array.fill(9, { nil }),
        \subActive,   Array.fill(9, { |i| i == 0 }),
        \subIdx,      0
    ])
};

~numTracks     = 7;
~stepsPerTrack = 16;
~bpm           = 120;
~fxParams = Dictionary.newFrom([
    \satDepth, 0, \satType, 0, \tilt, 0, \compAmount, 0, \compColor, 0
]);
~fxParamDefaults = ~fxParams.copy;
~fxCloudsParams = Dictionary.newFrom([
    \inGain, 1.0, \pit, 0, \pos, 0.5, \size, 0.25,
    \dens, 0.4, \tex, 0.5, \spread, 0.5, \fb, 0, \rvb, 0,
    \freeze, 0, \mode, 0, \lofi, 0, \trigRate, 0
]);
~fxCloudsDefaults = ~fxCloudsParams.copy;
~fxModSettings = Dictionary[\shape -> 0, \rate16ths -> 16,
    \depths -> Array.fill(12, { 0.0 }), \polarities -> Array.fill(12, { 1 }),
    \phases -> Array.fill(12, { 0.0 })];
~playing       = false;
~transpose     = 1.0;
~globalReverse = false;
~presets       = Array.fill(49, { nil });
~presetSlotMap = [0, 1, 2, 3];
~presetSelectedSlot = nil;
~presetConfirmMode = true;
~presetQuantized = false;
~pendingPresetRecall = nil;
~pendingPresetButton = nil;
~activePresetButton = nil;
~clipboard     = nil;
~seqClock      = nil;
~swing         = 50;
~anchorTempo   = 120;
~trackVolumes  = Array.fill(7, { 1.0 });
~mixerVolumes  = [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0.05, 0];

~mixerPosForVolume = { |vol|
    var best = 0;
    ~mixerVolumes.do { |v, i| if((vol - v).abs < (vol - ~mixerVolumes[best]).abs) { best = i } };
    best
};

~mixerFineValue = { |pos127| pos127 / 126.0 };
~mixerFinePosition = { |vol| (vol * 126.0).round.asInteger.clip(0, 126) };

~lfoRateHz = { |sixteenths| ~bpm / (60 * sixteenths * 0.25) };

~updateLfoRate = { |trackIdx|
    if(~lfoSynths.notNil) { if(~lfoSynths[trackIdx].notNil) {
        var hz = ~lfoRateHz.(~trackModSettings[trackIdx][\rate16ths]);
        ~lfoSynths[trackIdx].set(\rate, hz);
        if(~tracks[trackIdx][\voice].notNil) {
            ~tracks[trackIdx][\voice].set(\lfoRate, hz);
        };
    } }
};
~updateAllLfoRates = { ~numTracks.do { |i| ~updateLfoRate.(i) } };

~debugLfo = { |trackIdx|
    var synth = ~lfoSynths[trackIdx];
    var busIdx = ~lfoBus.index + trackIdx;
    var ms = ~trackModSettings[trackIdx];
    "[Gladiola] === LFO DEBUG track % ===".format(trackIdx).postln;
    "[Gladiola]   synth: %, nodeID: %".format(synth, if(synth.notNil) { synth.nodeID } { "nil" }).postln;
    "[Gladiola]   bus index: %, getSynchronous: %".format(busIdx, s.getControlBusValue(~lfoBus.index + trackIdx)).postln;
    "[Gladiola]   rate16ths: %, hz: %".format(ms[\rate16ths], ~lfoRateHz.(ms[\rate16ths]).round(0.001)).postln;
    "[Gladiola]   shape: %".format(ms[\shape]).postln;
    // Query the server for the node
    s.sendMsg('/n_query', synth.nodeID);
};

~setModDepth = { |trackIdx, destIdx, depth, polarity|
    ~trackModSettings[trackIdx][\depths][destIdx] = depth;
    ~trackModSettings[trackIdx][\polarities][destIdx] = polarity;
    if(~modArgNames[destIdx].notNil) {
        if(~tracks[trackIdx][\voice].notNil) {
            ~tracks[trackIdx][\voice].set(~modArgNames[destIdx], depth * polarity)
        }
    }
};
~setModPhase = { |trackIdx, destIdx, phase|
    ~trackModSettings[trackIdx][\phases][destIdx] = phase;
    if(~phaseArgNames[destIdx].notNil) {
        if(~tracks[trackIdx][\voice].notNil) {
            ~tracks[trackIdx][\voice].set(~phaseArgNames[destIdx], phase)
        }
    }
};
~setModShape = { |trackIdx, shape|
    shape = shape.asInteger;
    ~trackModSettings[trackIdx][\shape] = shape;
    if(~lfoSynths.notNil) { if(~lfoSynths[trackIdx].notNil) {
        ~lfoSynths[trackIdx].set(\shape, shape)
    } }
};
~setModRate = { |trackIdx, rate16ths|
    ~trackModSettings[trackIdx][\rate16ths] = rate16ths.clip(1, 128);
    ~updateLfoRate.(trackIdx)
};
~applyModDepths = { |trackIdx|
    var ms = ~trackModSettings[trackIdx];
    var voice = ~tracks[trackIdx][\voice];
    if(voice.notNil) {
        14.do { |i|
            if(~modArgNames[i].notNil) {
                voice.set(~modArgNames[i], ms[\depths][i] * ms[\polarities][i])
            };
            if(~phaseArgNames[i].notNil) {
                voice.set(~phaseArgNames[i], ms[\phases][i])
            }
        };
        voice.set(\lfoRate, ~lfoRateHz.(ms[\rate16ths]))
    }
};
~resetModSettings = { |trackIdx|
    ~trackModSettings[trackIdx] = Dictionary[\shape -> 0, \rate16ths -> 16,
        \depths -> Array.fill(14, { 0.0 }), \polarities -> Array.fill(14, { 1 }),
        \phases -> Array.fill(14, { 0.0 })];
    ~setModShape.(trackIdx, 0);
    ~updateLfoRate.(trackIdx);
    ~applyModDepths.(trackIdx)
};

~updateFxLfoRate = {
    if(~fxLfoSynth.notNil) {
        var hz = ~lfoRateHz.(~fxModSettings[\rate16ths]);
        ~fxLfoSynth.set(\rate, hz);
        if(~cloudsSynth.notNil) { ~cloudsSynth.set(\lfoRate, hz) };
    }
};
~setFxModDepth = { |destIdx, depth, polarity|
    ~fxModSettings[\depths][destIdx] = depth;
    ~fxModSettings[\polarities][destIdx] = polarity;
    if(~fxModArgNames[destIdx].notNil) {
        if(~cloudsSynth.notNil) {
            ~cloudsSynth.set(~fxModArgNames[destIdx], depth * polarity)
        }
    }
};
~setFxModPhase = { |destIdx, phase|
    ~fxModSettings[\phases][destIdx] = phase;
    if(~fxModPhaseArgNames[destIdx].notNil) {
        if(~cloudsSynth.notNil) {
            ~cloudsSynth.set(~fxModPhaseArgNames[destIdx], phase)
        }
    }
};
~setFxModShape = { |shape|
    shape = shape.asInteger;
    ~fxModSettings[\shape] = shape;
    if(~fxLfoSynth.notNil) { ~fxLfoSynth.set(\shape, shape) }
};
~setFxModRate = { |rate16ths|
    ~fxModSettings[\rate16ths] = rate16ths.clip(1, 128);
    ~updateFxLfoRate.()
};
~applyFxModDepths = {
    var ms = ~fxModSettings;
    if(~cloudsSynth.notNil) {
        9.do { |i|
            if(~fxModArgNames[i].notNil) {
                ~cloudsSynth.set(~fxModArgNames[i], ms[\depths][i] * ms[\polarities][i])
            };
            if(~fxModPhaseArgNames[i].notNil) {
                ~cloudsSynth.set(~fxModPhaseArgNames[i], ms[\phases][i])
            }
        };
        ~cloudsSynth.set(\lfoRate, ~lfoRateHz.(ms[\rate16ths]))
    }
};
~resetFxModSettings = {
    ~fxModSettings = Dictionary[\shape -> 0, \rate16ths -> 16,
        \depths -> Array.fill(12, { 0.0 }), \polarities -> Array.fill(12, { 1 }),
        \phases -> Array.fill(12, { 0.0 })];
    ~setFxModShape.(0);
    ~updateFxLfoRate.();
    ~applyFxModDepths.()
};
~setFxCloudsParam = { |key, value|
    ~fxCloudsParams[key] = value;
    if(~cloudsSynth.notNil) {
        ~cloudsSynth.set(key, value)
    }
};

~setTrackVolume = { |trackIdx, vol|
    ~trackVolumes[trackIdx] = vol;
    if(~tracks[trackIdx][\voice].notNil) { ~tracks[trackIdx][\voice].set(\trackAmp, vol) };
};

~voiceGroup    = nil;
~satGroup      = nil;
~fxGroup       = nil;
~masterGroup   = nil;
~fxSendBus     = nil;
~cloudsSynth   = nil;
~fxLfoBus      = nil;
~fxLfoSynth    = nil;
~satSynth      = nil;
~tiltSynth     = nil;
~compSynth     = nil;
~limiterSynth  = nil;

~tracks = nil;

~stepPosInRange = { |step, startStep, endStep|
    if(startStep <= endStep) { step - startStep }
    { if(step >= startStep) { step - startStep } { (~stepsPerTrack - startStep) + step } }
};

~stepInRange = { |step, startStep, endStep|
    if(startStep <= endStep) {
        (step >= startStep) && (step <= endStep)
    } {
        (step >= startStep) || (step <= endStep)
    }
};

~longestPatternTrack = {
    var longest = 0;
    var longestDur = 0;
    ~numTracks.do { |i|
        var t = ~tracks[i];
        var len, dur;
        if(t[\muted].not) {
            len = if(t[\startStep] <= t[\endStep]) {
                t[\endStep] - t[\startStep] + 1
            } {
                (~stepsPerTrack - t[\startStep]) + t[\endStep] + 1
            };
            dur = len * t[\clockDiv];
            if(dur > longestDur) { longestDur = dur; longest = i };
        };
    };
    longest
};

~initSequencer = {
    ~tracks = Array.fill(~numTracks, {
        Dictionary[\steps -> Array.fill(~stepsPerTrack, { defaultStep.value }),
            \startStep -> 0,
            \endStep -> 15,
            \currentStep -> 0,
            \muted -> false,
            \voice -> nil,
            \clockDiv -> 0.25,
            \sliceMode -> false]
    });

    ~voiceGroup  = Group.new(s);
    ~satGroup    = Group.after(~voiceGroup);
    ~fxGroup     = Group.after(~satGroup);
    ~masterGroup = Group.after(~fxGroup);

    ~fxSendBus = Bus.audio(s, 2);

    ~lfoBus = Bus.control(s, ~numTracks);
    ~trackModSettings = Array.fill(~numTracks, {
        Dictionary[\shape -> 0, \rate16ths -> 16,
            \depths -> Array.fill(14, { 0.0 }), \polarities -> Array.fill(14, { 1 }),
            \phases -> Array.fill(14, { 0.0 })]
    });
    ~lfoGroup = Group.before(~voiceGroup);
    ~lfoSynths = Array.fill(~numTracks, { |i|
        Synth(\gladiolaLFO, [\out, ~lfoBus.index + i, \shape, 0,
            \rate, ~lfoRateHz.(16), \freeze, 0], ~lfoGroup)
    });

    ~numTracks.do { |i|
        ~tracks[i][\voice] = Synth(\gladiolaSample, [
            \fxSendBus, ~fxSendBus.index,
            \trackAmp, ~trackVolumes[i],
            \lfoBus, ~lfoBus.index + i,
            \lfoRate, ~lfoRateHz.(16)
        ], ~voiceGroup);
    };

    ~fxLfoBus = Bus.control(s, 1);
    ~fxLfoSynth = Synth(\gladiolaLFO, [\out, ~fxLfoBus.index, \shape, 0,
        \rate, ~lfoRateHz.(16), \freeze, 0], ~lfoGroup);

    ~cloudsSynth = Synth(\gladiolaClouds, [
        \fxSendBus, ~fxSendBus.index,
        \inGain, ~fxCloudsParams[\inGain],
        \pit, ~fxCloudsParams[\pit],
        \pos, ~fxCloudsParams[\pos],
        \size, ~fxCloudsParams[\size],
        \dens, ~fxCloudsParams[\dens],
        \tex, ~fxCloudsParams[\tex],
        \spread, ~fxCloudsParams[\spread],
        \fb, ~fxCloudsParams[\fb],
        \rvb, ~fxCloudsParams[\rvb],
        \freeze, ~fxCloudsParams[\freeze],
        \mode, ~fxCloudsParams[\mode],
        \lofi, ~fxCloudsParams[\lofi],
        \trigRate, ~fxCloudsParams[\trigRate],
        \lfoBus, ~fxLfoBus.index,
        \lfoRate, ~lfoRateHz.(~fxModSettings[\rate16ths])
    ], ~fxGroup);

    ~satSynth = Synth(\gladiolaSaturation, [
        \depth, ~fxParams[\satDepth],
        \type, ~fxParams[\satType]
    ], ~satGroup);

    ~tiltSynth = Synth(\gladiolaTilt, [
        \tilt, ~fxParams[\tilt]
    ], ~masterGroup);

    ~compSynth = Synth(\gladiolaCompressor, [
        \amount, ~fxParams[\compAmount],
        \color, ~fxParams[\compColor]
    ], ~masterGroup);

    ~limiterSynth = Synth(\gladiolaLimiter, [], ~masterGroup);

    ~meterBus = Bus.control(s, 2);
    ~meterSynth = SynthDef(\gladiolaMeter, {
        var sig = In.ar(0, 2);
        var amp = Amplitude.kr(sig, 0.01, 0.1);
        Out.kr(\out.kr(0), amp);
    }).play(s, [\out, ~meterBus], addAction: \addToTail);
    ~meterLevel = [0, 0];
    ~recordStartTime = nil;
    ~meterUpdateRoutine = Routine({
        loop {
            if(~meterBus.isNil) { nil.yield }; // exit if bus freed
            ~meterBus.getn(2, { |vals|
                ~meterLevel = [
                    vals[0].ampdb.linlin(-40, 0, 0, 1).clip(0, 1),
                    vals[1].ampdb.linlin(-40, 0, 0, 1).clip(0, 1)
                ];
            });
            0.05.wait;
        }
    }).play(AppClock);

    "[Gladiola] Sequencer initialized. % tracks × % steps.".format(~numTracks, ~stepsPerTrack).postln;
};

~startTransport = {
    if(~playing) {
        "[Gladiola] Transport already running.".postln;
    } {
        ~playing = true;
        ~numTracks.do { |i| ~tracks[i][\currentStep] = ~tracks[i][\startStep] };
        ~seqClock = TempoClock.new(~bpm / 60);

        ~numTracks.do { |trackIdx|
            ~seqClock.schedAbs(~seqClock.beats, {
                if(~playing) {
                    var track     = ~tracks[trackIdx];
                    var playedStep = track[\currentStep];
                    var step      = track[\steps][playedStep];
                    var voice     = track[\voice];
                    var buf, stepDur, numBanks, nextStep;

                    if(track[\muted].not && step[\on] && {
                        var probPass = {
                            var lfoVal = s.getControlBusValue(~lfoBus.index + trackIdx);
                            var ms = ~trackModSettings[trackIdx];
                            var modProb = ms[\depths][12] * ms[\polarities][12];
                            var probLfo = if(modProb != 0 && { ms[\phases][12] != 0 } && { [3, 4].includes(ms[\shape]).not }) {
                                var lfoHz = ~lfoRateHz.(ms[\rate16ths]);
                                var cyclePos = (Main.elapsedTime * lfoHz + ms[\phases][12]).mod(1.0);
                                ~lfoValueAtPhase.(ms[\shape], cyclePos)
                            } { lfoVal };
                            var effectiveProb = if(modProb != 0) {
                                (step[\probability] + (probLfo * modProb)).clip(0, 1)
                            } { step[\probability] };
                            effectiveProb.coin
                        }.value;
                        var condPass = if(step[\condMode] == true) {
                            step[\condCount] = step[\condCount] + 1;
                            if(step[\condCount] > step[\condM]) { step[\condCount] = 1 };
                            step[\condCount] == step[\condN]
                        } { true };
                        probPass && condPass
                    }.value) {
                        var activeSubs, lastActive, subLen, curSub;
                        var bank, sample, pitch, velocity, loopLength, loopRegion, ratchet;
                        var resolvedGateLength, resolvedReverse, resolvedFilter;
                        var resolvedPan, resolvedDelaySend, resolvedBitcrush, resolvedAttack;

                        lastActive = 0;
                        step[\subActive].do { |active, i| if(active) { lastActive = i } };
                        subLen = lastActive + 1;
                        curSub = step[\subIdx] % subLen;

                        bank       = ~resolveSubStepParam.(step, curSub, \bank);
                        sample     = ~resolveSubStepParam.(step, curSub, \sample);

                        if(track[\sliceMode] == true) {
                            var refStep = track[\steps].detect { |s| s[\on] };
                            bank = if(refStep.notNil) { refStep[\bank] } { 0 };
                            sample = if(refStep.notNil) { refStep[\sample] } { 0 };
                        };
                        pitch      = ~resolveSubStepParam.(step, curSub, \pitch);
                        velocity   = ~resolveSubStepParam.(step, curSub, \velocity);
                        loopLength = ~resolveSubStepParam.(step, curSub, \loopLength);
                        loopRegion = ~resolveSubStepParam.(step, curSub, \loopRegion);
                        ratchet    = ~resolveSubStepParam.(step, curSub, \ratchet);
                        resolvedGateLength = ~resolveSubStepParam.(step, curSub, \gateLength);
                        resolvedReverse    = ~resolveSubStepParam.(step, curSub, \reverse);
                        resolvedFilter     = ~resolveSubStepParam.(step, curSub, \filter);
                        resolvedPan        = ~resolveSubStepParam.(step, curSub, \pan);
                        resolvedDelaySend  = ~resolveSubStepParam.(step, curSub, \delaySend);
                        resolvedBitcrush   = ~resolveSubStepParam.(step, curSub, \bitcrush);
                        resolvedAttack     = ~resolveSubStepParam.(step, curSub, \attack);

                        step[\subIdx] = step[\subIdx] + 1;

                        // LFO sample/slice modulation (sclang-side, phase-aware)
                        {
                            var lfoVal = s.getControlBusValue(~lfoBus.index + trackIdx);
                            var ms = ~trackModSettings[trackIdx];
                            var modSample = ms[\depths][0] * ms[\polarities][0];
                            var sampleLfo = if(modSample != 0 && { ms[\phases][0] != 0 } && { [3, 4].includes(ms[\shape]).not }) {
                                var lfoHz = ~lfoRateHz.(ms[\rate16ths]);
                                var cyclePos = (Main.elapsedTime * lfoHz + ms[\phases][0]).mod(1.0);
                                ~lfoValueAtPhase.(ms[\shape], cyclePos)
                            } { lfoVal };
                            if(modSample != 0) {
                                if(track[\sliceMode] == true) {
                                    var baseSlice = ~resolveSubStepParam.(step, curSub, \sliceIdx);
                                    ~lfoResolvedSlice = (baseSlice + (sampleLfo * modSample * 16)).round.asInteger.wrap(0, 15);
                                } {
                                    var bankSize = ~samplesInBank.(bank).max(1);
                                    sample = (sample + (sampleLfo * modSample * bankSize)).round.asInteger.wrap(0, bankSize - 1);
                                };
                            } {
                                ~lfoResolvedSlice = nil;
                            };
                        }.value;

                        buf = ~getSample.(bank, sample);

                        if(buf.notNil) {
                            var resolvedSlice = ~lfoResolvedSlice ?? { ~resolveSubStepParam.(step, curSub, \sliceIdx) };
                            stepDur = track[\clockDiv] / ~seqClock.tempo;

                            voice.set(
                                \bufnum,     buf.bufnum,
                                \rate,       pitch * ~transpose,
                                \amp,        velocity,
                                \loopLength, loopLength,
                                \loopRegion, loopRegion,
                                \ratchet,    ratchet,
                                \stepDur,    stepDur,
                                \gateLength, resolvedGateLength,
                                \reverse,    (resolvedReverse.asBoolean xor: ~globalReverse).asInteger,
                                \filter,     resolvedFilter,
                                \pan,        resolvedPan,
                                \delaySend,  resolvedDelaySend,
                                \bitcrush,   resolvedBitcrush,
                                \attack,     resolvedAttack,
                                \sliceMode,  track[\sliceMode].asInteger,
                                \sliceIdx,   resolvedSlice,
                                \t_trig,     1
                            );
                            if(resolvedDelaySend > 0) {
                                if(~cloudsSynth.notNil) {
                                    ~cloudsSynth.set(\t_trig, 1);
                                    {
                                        var fxLfoVal = ~fxLfoBus.getSynchronous;
                                        var ms = ~fxModSettings;
                                        if(ms[\depths][9] > 0) {
                                            var modVal = fxLfoVal * ms[\depths][9] * ms[\polarities][9];
                                            ~cloudsSynth.set(\freeze, if(modVal > 0) { 1 } { 0 });
                                        };
                                        if(ms[\depths][10] > 0) {
                                            var modVal = ((fxLfoVal + 1) * 0.5 * ms[\depths][10]).clip(0, 1);
                                            ~cloudsSynth.set(\mode, (modVal * 3).round.asInteger.clip(0, 3));
                                        };
                                        if(ms[\depths][11] > 0) {
                                            var modVal = fxLfoVal * ms[\depths][11] * ms[\polarities][11];
                                            ~cloudsSynth.set(\lofi, if(modVal > 0) { 1 } { 0 });
                                        };
                                    }.value;
                                };
                            };
                        };
                    };

                    nextStep = (track[\currentStep] + 1) % ~stepsPerTrack;
                    if(~stepInRange.(nextStep, track[\startStep], track[\endStep]).not) {
                        nextStep = track[\startStep];
                    };
                    if(nextStep == track[\startStep] && ~pendingPresetRecall.notNil && (trackIdx == ~longestPatternTrack.())) {
                        var recallSlot = ~pendingPresetRecall;
                        var recallBtn = ~pendingPresetButton;
                        var handoffDelay = track[\clockDiv] - 0.001;
                        ~pendingPresetRecall = nil;
                        ~pendingPresetButton = nil;
                        ~seqClock.schedAbs(~seqClock.beats + handoffDelay, {
                            ~recallPreset.(recallSlot);
                            ~numTracks.do { |i| ~tracks[i][\currentStep] = ~tracks[i][\startStep] };
                            if(recallBtn.notNil) { ~activePresetButton = recallBtn };
                            nil;
                        });
                    };
                    track[\currentStep] = nextStep;

                    { ~updateGridLEDs.() }.defer;

                    {
                        var stepPos = ~stepPosInRange.(playedStep, track[\startStep], track[\endStep]);
                        var swingMul = if(stepPos.even) { 2 * (~swing / 100) } { 2 * (1 - (~swing / 100)) };
                        track[\clockDiv] * swingMul
                    }.value
                } {
                    nil
                }
            });
        };

        "[Gladiola] Transport started at % BPM.".format(~bpm).postln;
    };
};

~stopTransport = {
    ~playing = false;

    if(~seqClock.notNil) {
        ~seqClock.stop;
        ~seqClock = nil;
    };

    "[Gladiola] Transport stopped.".postln;
};

~panicVoices = {
    ~numTracks.do { |i|
        if(~tracks[i][\voice].notNil) {
            ~tracks[i][\voice].set(\amp, 0, \t_trig, 0);
        };
    };
    "[Gladiola] All voices silenced.".postln;
};

~killFxTails = {
    if(~cloudsSynth.notNil) { ~cloudsSynth.free };
    ~cloudsSynth = Synth(\gladiolaClouds, [
        \fxSendBus, ~fxSendBus.index,
        \inGain, ~fxCloudsParams[\inGain],
        \pit, ~fxCloudsParams[\pit],
        \pos, ~fxCloudsParams[\pos],
        \size, ~fxCloudsParams[\size],
        \dens, ~fxCloudsParams[\dens],
        \tex, ~fxCloudsParams[\tex],
        \spread, ~fxCloudsParams[\spread],
        \fb, ~fxCloudsParams[\fb],
        \rvb, ~fxCloudsParams[\rvb],
        \freeze, ~fxCloudsParams[\freeze],
        \mode, ~fxCloudsParams[\mode],
        \lofi, ~fxCloudsParams[\lofi],
        \trigRate, ~fxCloudsParams[\trigRate],
        \lfoBus, ~fxLfoBus.index,
        \lfoRate, ~lfoRateHz.(~fxModSettings[\rate16ths])
    ], ~fxGroup);
    ~applyFxModDepths.();
    "[Gladiola] FX tails killed.".postln;
};

~previewStep = { |trackIdx, stepIdx, forceSliceOff|
    var track = ~tracks[trackIdx];
    var step = track[\steps][stepIdx];
    var voice = track[\voice];
    var subIdx = if(~subStepEditing && ~subStepEditIdx.notNil) { ~subStepEditIdx } { nil };
    var r = { |param| if(subIdx.notNil) { ~resolveSubStepParam.(step, subIdx, param) } { step[param] } };
    var buf = ~getSample.(r.(\bank), r.(\sample));
    var useSlice = if(forceSliceOff == true) { 0 } { ~tracks[trackIdx][\sliceMode].asInteger };

    if(buf.notNil && voice.notNil) {
        voice.set(
            \bufnum,     buf.bufnum,
            \rate,       r.(\pitch) * ~transpose,
            \amp,        r.(\velocity),
            \loopLength, r.(\loopLength),
            \loopRegion, r.(\loopRegion),
            \ratchet,    r.(\ratchet),
            \stepDur,    track[\clockDiv] * 60 / ~bpm,
            \gateLength, r.(\gateLength),
            \reverse,    (r.(\reverse).asBoolean xor: ~globalReverse).asInteger,
            \filter,     r.(\filter),
            \pan,        r.(\pan),
            \delaySend,  r.(\delaySend),
            \bitcrush,   r.(\bitcrush),
            \attack,     r.(\attack),
            \sliceMode,  useSlice,
            \sliceIdx,   r.(\sliceIdx),
            \t_trig,     1
        );
    };
};

~setTrackStart = { |trackIdx, step|
    if((trackIdx >= 0) && (trackIdx < ~numTracks)) {
        ~tracks[trackIdx][\startStep] = step.clip(0, ~stepsPerTrack - 1).asInteger;
        if(~stepInRange.(~tracks[trackIdx][\currentStep], ~tracks[trackIdx][\startStep], ~tracks[trackIdx][\endStep]).not) {
            ~tracks[trackIdx][\currentStep] = ~tracks[trackIdx][\startStep];
        };
        "[Gladiola] Track %: start -> %".format(trackIdx, ~tracks[trackIdx][\startStep]).postln;
    };
};

~setTrackEnd = { |trackIdx, step|
    if((trackIdx >= 0) && (trackIdx < ~numTracks)) {
        ~tracks[trackIdx][\endStep] = step.clip(0, ~stepsPerTrack - 1).asInteger;
        if(~stepInRange.(~tracks[trackIdx][\currentStep], ~tracks[trackIdx][\startStep], ~tracks[trackIdx][\endStep]).not) {
            ~tracks[trackIdx][\currentStep] = ~tracks[trackIdx][\startStep];
        };
        "[Gladiola] Track %: end -> %".format(trackIdx, ~tracks[trackIdx][\endStep]).postln;
    };
};

~muteTrack = { |idx|
    if((idx >= 0) && (idx < ~numTracks)) {
        ~tracks[idx][\muted] = true;
        if(~tracks[idx][\voice].notNil) {
            ~tracks[idx][\voice].set(\amp, 0, \t_trig, 0);
        };
        "[Gladiola] Track % muted.".format(idx).postln;
    };
};

~unmuteTrack = { |idx|
    if((idx >= 0) && (idx < ~numTracks)) {
        ~tracks[idx][\muted] = false;
        "[Gladiola] Track % unmuted.".format(idx).postln;
    };
};

~toggleMuteTrack = { |idx|
    if((idx >= 0) && (idx < ~numTracks)) {
        ~tracks[idx][\muted] = ~tracks[idx][\muted].not;
        if(~tracks[idx][\muted] && ~tracks[idx][\voice].notNil) {
            ~tracks[idx][\voice].set(\amp, 0, \t_trig, 0);
        };
        "[Gladiola] Track %: muted -> %".format(idx, ~tracks[idx][\muted]).postln;
    };
};

~setStep = { |trackIdx, stepIdx, key, value|
    if((trackIdx >= 0) && (trackIdx < ~numTracks) &&
        (stepIdx >= 0) && (stepIdx < ~stepsPerTrack)) {
        ~tracks[trackIdx][\steps][stepIdx][key] = value;
    };
};

~setTrackClockDiv = { |trackIdx, div|
    if((trackIdx >= 0) && (trackIdx < ~numTracks)) {
        ~tracks[trackIdx][\clockDiv] = div.clip(0.0625, 4.0);
        "[Gladiola] Track % clock div set to %.".format(trackIdx, ~tracks[trackIdx][\clockDiv]).postln;
    };
};

~setFxParam = { |key, value|
    ~fxParams[key] = value;
    switch(key)
    { \satDepth }    { if(~satSynth.notNil) { ~satSynth.set(\depth, value) } }
    { \satType }     { if(~satSynth.notNil) { ~satSynth.set(\type, value) } }
    { \tilt }        { if(~tiltSynth.notNil) { ~tiltSynth.set(\tilt, value) } }
    { \compAmount }  { if(~compSynth.notNil) { ~compSynth.set(\amount, value) } }
    { \compColor }   { if(~compSynth.notNil) { ~compSynth.set(\color, value) } };
};

~setTempo = { |bpm|
    ~bpm = bpm.clip(20, 300);
    if(~seqClock.notNil) {
        ~seqClock.tempo = ~bpm / 60;
    };
    ~updateAllLfoRates.();
    ~updateFxLfoRate.();
    "[Gladiola] Tempo set to % BPM.".format(~bpm).postln;
};

~setSwing = { |pct|
    ~swing = pct.clip(50, 100).asInteger;
    "[Gladiola] Swing set to %%".format(~swing, "%").postln;
};

~clearPattern = {
    ~numTracks.do { |i|
        ~tracks[i][\steps] = Array.fill(~stepsPerTrack, { defaultStep.value });
        ~tracks[i][\currentStep] = 0;
        ~tracks[i][\startStep] = 0;
        ~tracks[i][\endStep] = 15;
        ~tracks[i][\clockDiv] = 0.25;
        ~tracks[i][\sliceMode] = false;
    };
    ~fxParamDefaults.keysValuesDo { |key, val|
        ~setFxParam.(key, val);
    };
    ~fxCloudsDefaults.keysValuesDo { |key, val|
        ~setFxCloudsParam.(key, val);
    };
    ~resetFxModSettings.();
    ~numTracks.do { |i| ~resetModSettings.(i) };
    "[Gladiola] All patterns cleared.".postln;
};

~savePreset = { |slot|
    var snapshot = Dictionary.new;
    snapshot[\tracks] = ~numTracks.collect { |i|
        var t = ~tracks[i];
        Dictionary[
            \steps -> t[\steps].collect { |s| ~deepCopyStep.(s) },
            \startStep -> t[\startStep],
            \endStep -> t[\endStep],
            \muted -> t[\muted],
            \clockDiv -> t[\clockDiv],
            \sliceMode -> t[\sliceMode]
        ]
    };
    snapshot[\fxParams] = ~fxParams.copy;
    snapshot[\transpose] = ~transpose;
    snapshot[\globalReverse] = ~globalReverse;
    snapshot[\swing] = ~swing;
    snapshot[\trackVolumes] = ~trackVolumes.copy;
    snapshot[\trackModSettings] = ~numTracks.collect { |i|
        var ms = ~trackModSettings[i];
        Dictionary[\shape -> ms[\shape], \rate16ths -> ms[\rate16ths],
            \depths -> ms[\depths].copy, \polarities -> ms[\polarities].copy,
            \phases -> ms[\phases].copy]
    };
    snapshot[\fxCloudsParams] = ~fxCloudsParams.copy;
    snapshot[\fxModSettings] = Dictionary[\shape -> ~fxModSettings[\shape],
        \rate16ths -> ~fxModSettings[\rate16ths],
        \depths -> ~fxModSettings[\depths].copy,
        \polarities -> ~fxModSettings[\polarities].copy,
        \phases -> ~fxModSettings[\phases].copy];
    ~presets[slot] = snapshot;
    "[Gladiola] Preset % saved.".format(slot + 1).postln;
};

~recallPreset = { |slot|
    var snapshot = ~presets[slot];
    if(snapshot.notNil) {
        ~numTracks.do { |i|
            var saved = snapshot[\tracks][i];
            saved[\steps].do { |step|
                if(step[\subSteps].isNil) {
                    step[\subSteps] = Array.fill(9, { nil });
                    step[\subActive] = Array.fill(9, { |i| i == 0 });
                    step[\subIdx] = 0;
                };
                if(step[\attack].isNil) { step[\attack] = 0.002 };
                if(step[\sliceIdx].isNil) { step[\sliceIdx] = 0 };
                if(step[\condMode].isNil) { step[\condMode] = false };
                if(step[\condN].isNil) { step[\condN] = 1 };
                if(step[\condM].isNil) { step[\condM] = 2 };
                if(step[\condCount].isNil) { step[\condCount] = 0 };
            };
            ~tracks[i][\steps] = saved[\steps].collect { |s| ~deepCopyStep.(s) };
            ~tracks[i][\startStep] = saved[\startStep];
            ~tracks[i][\endStep] = saved[\endStep];
            ~tracks[i][\muted] = saved[\muted];
            if(saved[\clockDiv].notNil) {
                ~tracks[i][\clockDiv] = saved[\clockDiv];
            } {
                ~tracks[i][\clockDiv] = 0.25;
            };
            ~tracks[i][\sliceMode] = saved[\sliceMode] ?? { false };
            if(~tracks[i][\voice].notNil) {
                ~tracks[i][\voice].set(\sliceMode, ~tracks[i][\sliceMode].asInteger);
            };
        };
        if(snapshot[\fxParams].notNil) {
            snapshot[\fxParams].keysValuesDo { |key, val|
                ~setFxParam.(key, val);
            };
        } {
            ~fxParamDefaults.keysValuesDo { |key, val|
                ~setFxParam.(key, val);
            };
        };
        if(snapshot[\fxCloudsParams].notNil) {
            snapshot[\fxCloudsParams].keysValuesDo { |key, val|
                ~setFxCloudsParam.(key, val);
            };
        } {
            ~fxCloudsDefaults.keysValuesDo { |key, val|
                ~setFxCloudsParam.(key, val);
            };
        };
        if(snapshot[\fxModSettings].notNil) {
            var saved = snapshot[\fxModSettings];
            ~fxModSettings = Dictionary[\shape -> saved[\shape], \rate16ths -> saved[\rate16ths],
                \depths -> saved[\depths].copy, \polarities -> saved[\polarities].copy,
                \phases -> (saved[\phases] ?? { Array.fill(12, { 0.0 }) }).copy];
            ~setFxModShape.(saved[\shape]); ~updateFxLfoRate.(); ~applyFxModDepths.();
        } { ~resetFxModSettings.() };
        ~transpose = snapshot[\transpose];
        ~globalReverse = snapshot[\globalReverse] ? false;
        ~swing = snapshot[\swing] ?? { 50 };
        ~trackVolumes = snapshot[\trackVolumes] ?? { Array.fill(7, { 1.0 }) };
        ~numTracks.do { |i|
            if(~tracks[i][\voice].notNil) { ~tracks[i][\voice].set(\trackAmp, ~trackVolumes[i]) };
        };
        if(snapshot[\trackModSettings].notNil) {
            ~numTracks.do { |i|
                var saved = snapshot[\trackModSettings][i];
                ~trackModSettings[i] = Dictionary[\shape -> saved[\shape], \rate16ths -> saved[\rate16ths],
                    \depths -> saved[\depths].copy, \polarities -> saved[\polarities].copy,
                    \phases -> (saved[\phases] ?? { Array.fill(14, { 0.0 }) }).copy];
                ~setModShape.(i, saved[\shape]); ~updateLfoRate.(i); ~applyModDepths.(i);
            };
        } { ~numTracks.do { |i| ~resetModSettings.(i) } };
        "[Gladiola] Preset % recalled.".format(slot + 1).postln;
    } {
        "[Gladiola] Preset % is empty.".format(slot + 1).postln;
    };
};

~clearPreset = { |slot|
    ~presets[slot] = nil;
    "[Gladiola] Preset % cleared.".format(slot + 1).postln;
};

"[Gladiola] sequencer.scd loaded.".postln;
)

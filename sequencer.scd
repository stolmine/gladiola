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
        \randomness,  0.0,
        \gateLength,  1.0,
        \reverse,     false,
        \filter,      0.0,
        \pan,         0.0,
        \probability, 1.0,
        \delaySend,   0.0,
        \bitcrush,    0.0
    ])
};

~numTracks     = 7;
~stepsPerTrack = 16;
~bpm           = 120;
~fxParams = Dictionary.newFrom([
    \delayDiv, 0.25, \delayFeedback, 0, \delayTone, 0, \delayLevel, 0,
    \granSize, 0, \granPosition, 0, \granPitch, 0, \granLevel, 0, \granModDepth, 0,
    \reverbSize, 0.5, \reverbDamp, 0.5, \reverbLevel, 0,
    \satDepth, 0, \satType, 0, \tilt, 0, \compAmount, 0, \compColor, 0
]);
~fxParamDefaults = ~fxParams.copy;
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
~lastRecalledSlot = [nil, nil, nil, nil];
~clipboard     = nil;
~seqClock      = nil;

~voiceGroup    = nil;
~satGroup      = nil;
~fxGroup       = nil;
~masterGroup   = nil;
~fxSendBus     = nil;
~delaySynth    = nil;
~granularSynth = nil;
~reverbSynth   = nil;
~satSynth      = nil;
~tiltSynth     = nil;
~compSynth     = nil;
~limiterSynth  = nil;

~tracks = nil;

~stepInRange = { |step, startStep, endStep|
    if(startStep <= endStep) {
        (step >= startStep) && (step <= endStep)
    } {
        (step >= startStep) || (step <= endStep)
    }
};

~longestPatternTrack = {
    var longest = 0;
    var longestLen = 0;
    ~numTracks.do { |i|
        var t = ~tracks[i];
        var len;
        if(t[\muted].not) {
            len = if(t[\startStep] <= t[\endStep]) {
                t[\endStep] - t[\startStep] + 1
            } {
                (~stepsPerTrack - t[\startStep]) + t[\endStep] + 1
            };
            if(len > longestLen) { longestLen = len; longest = i };
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
            \clockDiv -> 0.25]
    });

    ~voiceGroup  = Group.new(s);
    ~satGroup    = Group.after(~voiceGroup);
    ~fxGroup     = Group.after(~satGroup);
    ~masterGroup = Group.after(~fxGroup);

    ~fxSendBus = Bus.audio(s, 2);

    ~numTracks.do { |i|
        ~tracks[i][\voice] = Synth(\gladiolaSample, [
            \fxSendBus, ~fxSendBus.index
        ], ~voiceGroup);
    };

    ~delaySynth = Synth(\gladiolaDelay, [
        \fxSendBus, ~fxSendBus.index,
        \delaytime, ~fxParams[\delayDiv] * 60 / ~bpm,
        \feedback, ~fxParams[\delayFeedback],
        \tone, ~fxParams[\delayTone],
        \level, ~fxParams[\delayLevel]
    ], ~fxGroup);

    ~granularSynth = Synth(\gladiolaGranular, [
        \fxSendBus, ~fxSendBus.index,
        \size, ~fxParams[\granSize],
        \position, ~fxParams[\granPosition],
        \pitch, ~fxParams[\granPitch],
        \level, ~fxParams[\granLevel],
        \modDepth, ~fxParams[\granModDepth]
    ], ~fxGroup);

    ~reverbSynth = Synth(\gladiolaReverb, [
        \fxSendBus, ~fxSendBus.index,
        \size, ~fxParams[\reverbSize],
        \damping, ~fxParams[\reverbDamp],
        \level, ~fxParams[\reverbLevel]
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
                    var step      = track[\steps][track[\currentStep]];
                    var voice     = track[\voice];
                    var buf, stepDur, numBanks, nextStep;

                    if(track[\muted].not && step[\on] && step[\probability].coin) {
                        var rand       = step[\randomness];
                        var bank       = step[\bank];
                        var sample     = step[\sample];
                        var pitch      = step[\pitch];
                        var velocity   = step[\velocity];
                        var loopLength = step[\loopLength];
                        var loopRegion = step[\loopRegion];
                        var ratchet    = step[\ratchet];

                        if(rand > 0) {
                            pitch      = pitch * rrand(1 - (rand * 0.5), 1 + (rand * 0.5));
                            velocity   = (velocity * rrand(1 - (rand * 0.3), 1 + (rand * 0.3))).clip(0.0, 1.0);
                            loopLength = (loopLength + (rrand(-0.2, 0.2) * rand)).clip(0.0, 8.0);
                            loopRegion = (loopRegion + (rrand(-0.2, 0.2) * rand)).clip(0.0, 1.0);
                            ratchet    = (ratchet + rrand(-2, 2)).clip(1, 8);

                            if((rand * 0.3).coin) {
                                numBanks = (~numBanks ?? { 0 }).max(1);
                                bank     = rrand(0, numBanks - 1);
                                sample   = rrand(0, (~sampleBanks !? { |sb| sb[bank].select(_.notNil).size } ?? { 1 }).max(1) - 1);
                            };
                        };

                        buf = ~getSample.(bank, sample);

                        if(buf.notNil) {
                            stepDur = track[\clockDiv] / ~seqClock.tempo;

                            voice.set(
                                \bufnum,     buf.bufnum,
                                \rate,       pitch * ~transpose,
                                \amp,        velocity,
                                \loopLength, loopLength,
                                \loopRegion, loopRegion,
                                \ratchet,    ratchet,
                                \stepDur,    stepDur,
                                \gateLength, step[\gateLength],
                                \reverse,    (step[\reverse].asBoolean xor: ~globalReverse).asInteger,
                                \filter,     step[\filter],
                                \pan,        step[\pan],
                                \delaySend,  step[\delaySend],
                                \bitcrush,   step[\bitcrush],
                                \t_trig,     1
                            );
                            if(step[\delaySend] > 0 && ~granularSynth.notNil) {
                                ~granularSynth.set(\t_trig, 1);
                            };
                        };
                    };

                    nextStep = (track[\currentStep] + 1) % ~stepsPerTrack;
                    if(~stepInRange.(nextStep, track[\startStep], track[\endStep]).not) {
                        nextStep = track[\startStep];
                        if(~pendingPresetRecall.notNil && (trackIdx == ~longestPatternTrack.())) {
                            var recallSlot = ~pendingPresetRecall;
                            var recallBtn = ~pendingPresetButton;
                            ~pendingPresetRecall = nil;
                            ~pendingPresetButton = nil;
                            ~recallPreset.(recallSlot);
                            if(recallBtn.notNil) {
                                ~lastRecalledSlot[recallBtn] = recallSlot;
                            };
                        };
                    };
                    track[\currentStep] = nextStep;

                    { ~updateGridLEDs.() }.defer;

                    track[\clockDiv]
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
    if(~delaySynth.notNil) { ~delaySynth.free };
    ~delaySynth = Synth(\gladiolaDelay, [
        \fxSendBus, ~fxSendBus.index,
        \delaytime, ~fxParams[\delayDiv] * 60 / ~bpm,
        \feedback, ~fxParams[\delayFeedback],
        \tone, ~fxParams[\delayTone],
        \level, ~fxParams[\delayLevel]
    ], ~fxGroup);

    if(~granularSynth.notNil) { ~granularSynth.free };
    ~granularSynth = Synth(\gladiolaGranular, [
        \fxSendBus, ~fxSendBus.index,
        \size, ~fxParams[\granSize],
        \position, ~fxParams[\granPosition],
        \pitch, ~fxParams[\granPitch],
        \level, ~fxParams[\granLevel],
        \modDepth, ~fxParams[\granModDepth]
    ], ~fxGroup);

    if(~reverbSynth.notNil) { ~reverbSynth.free };
    ~reverbSynth = Synth(\gladiolaReverb, [
        \fxSendBus, ~fxSendBus.index,
        \size, ~fxParams[\reverbSize],
        \damping, ~fxParams[\reverbDamp],
        \level, ~fxParams[\reverbLevel]
    ], ~fxGroup);

    "[Gladiola] FX tails killed.".postln;
};

~previewStep = { |trackIdx, stepIdx|
    var track = ~tracks[trackIdx];
    var step = track[\steps][stepIdx];
    var voice = track[\voice];
    var buf = ~getSample.(step[\bank], step[\sample]);

    if(buf.notNil && voice.notNil) {
        voice.set(
            \bufnum,     buf.bufnum,
            \rate,       step[\pitch] * ~transpose,
            \amp,        step[\velocity],
            \loopLength, step[\loopLength],
            \loopRegion, step[\loopRegion],
            \ratchet,    step[\ratchet],
            \stepDur,    track[\clockDiv] * 60 / ~bpm,
            \gateLength, step[\gateLength],
            \reverse,    (step[\reverse].asBoolean xor: ~globalReverse).asInteger,
            \filter,     step[\filter],
            \pan,        step[\pan],
            \delaySend,  step[\delaySend],
            \bitcrush,   step[\bitcrush],
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

~setDelayDiv = { |div|
    ~setFxParam.(\delayDiv, div.clip(0.0625, 4.0));
    "[Gladiola] Delay division set to %.".format(~fxParams[\delayDiv]).postln;
};

~updateDelayTime = {
    if(~delaySynth.notNil) {
        ~delaySynth.set(\delaytime, ~fxParams[\delayDiv] * 60 / ~bpm);
    };
};

~setFxParam = { |key, value|
    ~fxParams[key] = value;
    switch(key)
    { \delayDiv }      { ~updateDelayTime.() }
    { \delayFeedback } { if(~delaySynth.notNil) { ~delaySynth.set(\feedback, value) } }
    { \delayTone }     { if(~delaySynth.notNil) { ~delaySynth.set(\tone, value) } }
    { \delayLevel }    { if(~delaySynth.notNil) { ~delaySynth.set(\level, value) } }
    { \granSize }      { if(~granularSynth.notNil) { ~granularSynth.set(\size, value) } }
    { \granPosition }  { if(~granularSynth.notNil) { ~granularSynth.set(\position, value) } }
    { \granPitch }     { if(~granularSynth.notNil) { ~granularSynth.set(\pitch, value) } }
    { \granLevel }     { if(~granularSynth.notNil) { ~granularSynth.set(\level, value) } }
    { \granModDepth }  { if(~granularSynth.notNil) { ~granularSynth.set(\modDepth, value) } }
    { \reverbSize }    { if(~reverbSynth.notNil) { ~reverbSynth.set(\size, value) } }
    { \reverbDamp }    { if(~reverbSynth.notNil) { ~reverbSynth.set(\damping, value) } }
    { \reverbLevel }   { if(~reverbSynth.notNil) { ~reverbSynth.set(\level, value) } }
    { \satDepth }      { if(~satSynth.notNil) { ~satSynth.set(\depth, value) } }
    { \satType }       { if(~satSynth.notNil) { ~satSynth.set(\type, value) } }
    { \tilt }          { if(~tiltSynth.notNil) { ~tiltSynth.set(\tilt, value) } }
    { \compAmount }    { if(~compSynth.notNil) { ~compSynth.set(\amount, value) } }
    { \compColor }     { if(~compSynth.notNil) { ~compSynth.set(\color, value) } };
};

~setTempo = { |bpm|
    ~bpm = bpm.clip(20, 300);
    if(~seqClock.notNil) {
        ~seqClock.tempo = ~bpm / 60;
    };
    ~updateDelayTime.();
    "[Gladiola] Tempo set to % BPM.".format(~bpm).postln;
};

~clearPattern = {
    ~numTracks.do { |i|
        ~tracks[i][\steps] = Array.fill(~stepsPerTrack, { defaultStep.value });
        ~tracks[i][\currentStep] = 0;
        ~tracks[i][\startStep] = 0;
        ~tracks[i][\endStep] = 15;
        ~tracks[i][\clockDiv] = 0.25;
    };
    ~fxParamDefaults.keysValuesDo { |key, val|
        ~setFxParam.(key, val);
    };
    "[Gladiola] All patterns cleared.".postln;
};

~savePreset = { |slot|
    var snapshot = Dictionary.new;
    snapshot[\tracks] = ~numTracks.collect { |i|
        var t = ~tracks[i];
        Dictionary[
            \steps -> t[\steps].collect { |s| s.copy },
            \startStep -> t[\startStep],
            \endStep -> t[\endStep],
            \muted -> t[\muted],
            \clockDiv -> t[\clockDiv]
        ]
    };
    snapshot[\fxParams] = ~fxParams.copy;
    snapshot[\transpose] = ~transpose;
    snapshot[\globalReverse] = ~globalReverse;
    ~presets[slot] = snapshot;
    "[Gladiola] Preset % saved.".format(slot + 1).postln;
};

~recallPreset = { |slot|
    var snapshot = ~presets[slot];
    if(snapshot.notNil) {
        ~numTracks.do { |i|
            var saved = snapshot[\tracks][i];
            ~tracks[i][\steps] = saved[\steps].collect { |s| s.copy };
            ~tracks[i][\startStep] = saved[\startStep];
            ~tracks[i][\endStep] = saved[\endStep];
            ~tracks[i][\muted] = saved[\muted];
            if(saved[\clockDiv].notNil) {
                ~tracks[i][\clockDiv] = saved[\clockDiv];
            } {
                ~tracks[i][\clockDiv] = 0.25;
            };
        };
        if(snapshot[\fxParams].notNil) {
            snapshot[\fxParams].keysValuesDo { |key, val|
                ~setFxParam.(key, val);
            };
        } {
            // legacy preset: reset fx to defaults then apply delayDiv if present
            ~fxParamDefaults.keysValuesDo { |key, val|
                ~setFxParam.(key, val);
            };
            if(snapshot[\delayDiv].notNil) {
                ~setFxParam.(\delayDiv, snapshot[\delayDiv]);
            };
        };
        ~transpose = snapshot[\transpose];
        ~globalReverse = snapshot[\globalReverse] ? false;
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

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
~delayDiv      = 0.25;
~playing       = false;
~transpose     = 1.0;
~globalReverse = false;
~presets       = Array.fill(4, { nil });
~clipboard     = nil;
~seqClock      = nil;

~voiceGroup    = nil;
~fxGroup       = nil;
~delayBus      = nil;
~delaySynth    = nil;

~tracks = nil;

~stepInRange = { |step, startStep, endStep|
    if(startStep <= endStep) {
        (step >= startStep) && (step <= endStep)
    } {
        (step >= startStep) || (step <= endStep)
    }
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

    ~voiceGroup = Group.new(s);
    ~fxGroup = Group.after(~voiceGroup);

    ~delayBus = Bus.audio(s, 2);

    ~numTracks.do { |i|
        ~tracks[i][\voice] = Synth(\gladiolaSample, [
            \delayBus, ~delayBus.index
        ], ~voiceGroup);
    };

    ~delaySynth = Synth(\gladiolaDelay, [
        \delayBus, ~delayBus.index,
        \delaytime, ~delayDiv * 60 / ~bpm,
        \feedback, 0.7,
        \mix, 0.5
    ], ~fxGroup);

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
                    var track, step, voice, rand, bank, sample, pitch, velocity;
                    var loopLength, loopRegion, ratchet, buf, stepDur, numBanks, nextStep;

                    track = ~tracks[trackIdx];
                    step  = track[\steps][track[\currentStep]];
                    voice = track[\voice];

                    if(track[\muted].not && step[\on] && step[\probability].coin) {
                        rand       = step[\randomness];
                        bank       = step[\bank];
                        sample     = step[\sample];
                        pitch      = step[\pitch];
                        velocity   = step[\velocity];
                        loopLength = step[\loopLength];
                        loopRegion = step[\loopRegion];
                        ratchet    = step[\ratchet];

                        if(rand > 0) {
                            pitch      = pitch * rrand(1 - (rand * 0.5), 1 + (rand * 0.5));
                            velocity   = (velocity * rrand(1 - (rand * 0.3), 1 + (rand * 0.3))).clip(0.0, 1.0);
                            loopLength = (loopLength + (rrand(-0.2, 0.2) * rand)).clip(0.0, 1.0);
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
                        };
                    };

                    nextStep = (track[\currentStep] + 1) % ~stepsPerTrack;
                    if(~stepInRange.(nextStep, track[\startStep], track[\endStep]).not) {
                        nextStep = track[\startStep];
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
    ~delayDiv = div.clip(0.0625, 4.0);
    ~updateDelayTime.();
    "[Gladiola] Delay division set to %.".format(~delayDiv).postln;
};

~updateDelayTime = {
    if(~delaySynth.notNil) {
        ~delaySynth.set(\delaytime, ~delayDiv * 60 / ~bpm);
    };
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
    snapshot[\delayDiv] = ~delayDiv;
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
        ~setDelayDiv.(snapshot[\delayDiv]);
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

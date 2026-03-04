(
var defaultStep = {
    Dictionary.newFrom([
        \on,         false,
        \bank,       0,
        \sample,     0,
        \pitch,      1.0,
        \velocity,   1.0,
        \loopLength, 0.0,
        \loopRegion, 0.0,
        \ratchet,    1,
        \randomness, 0.0
    ])
};

~stepCount    = 128;
~patternLength = 128;
~currentStep  = 0;
~bpm          = 120;
~clockDiv     = 0.25;
~playing      = false;
~playheadStep = 0;
~voice        = nil;
~seqClock     = nil;

~steps = nil;

~initSequencer = {
    ~steps = Array.fill(~stepCount, { defaultStep.value });

    ~voice = Synth(\gladiolaSample);

    "[Gladiola] Sequencer initialized. % steps, voice synth created.".format(~stepCount).postln;
};

~startTransport = {
    if(~playing) {
        "[Gladiola] Transport already running.".postln;
    } {
        ~playing = true;
        ~currentStep = 0;

        ~seqClock = TempoClock.new(~bpm / 60);

        ~seqClock.schedAbs(~seqClock.beats, {
            var step, bank, sample, buf;
            var pitch, velocity, loopLength, loopRegion, ratchet;
            var rand, stepDur;

            if(~playing) {
                step = ~steps[~currentStep];

                if(step[\on]) {
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
                            var numBanks = (~numBanks ?? { 0 }).max(1);
                            bank   = rrand(0, numBanks - 1);
                            sample = rrand(0, (~sampleBanks !? { |sb| sb[bank].select(_.notNil).size } ?? { 1 }).max(1) - 1);
                        };
                    };

                    buf = ~getSample.(bank, sample);

                    if(buf.notNil) {
                        stepDur = ~clockDiv / ~seqClock.tempo;

                        ~voice.set(
                            \bufnum,     buf.bufnum,
                            \rate,       pitch,
                            \amp,        velocity,
                            \loopLength, loopLength,
                            \loopRegion, loopRegion,
                            \ratchet,    ratchet,
                            \stepDur,    stepDur,
                            \t_trig,     1
                        );
                    } {
                        "[Gladiola] No buffer at bank %, sample %.".format(bank, sample).postln;
                    };
                };

                ~playheadStep = ~currentStep;
                ~currentStep = (~currentStep + 1) % ~patternLength;

                { ~updateGridLEDs.() }.defer;

                ~clockDiv
            } {
                nil
            }
        });

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

~setPatternLength = { |length|
    ~patternLength = length.clip(1, ~stepCount).asInteger;

    if(~currentStep >= ~patternLength) {
        ~currentStep = 0;
    };

    "[Gladiola] Pattern length set to %.".format(~patternLength).postln;
};

~setStep = { |index, key, value|
    if((index >= 0) && (index < ~stepCount)) {
        ~steps[index][key] = value;
    } {
        "[Gladiola] setStep: index % out of range.".format(index).postln;
    };
};

~setClockDiv = { |div|
    ~clockDiv = div.clip(0.0625, 4.0);
    "[Gladiola] Clock division set to %.".format(~clockDiv).postln;
};

~setTempo = { |bpm|
    ~bpm = bpm.clip(20, 300);
    if(~seqClock.notNil) {
        ~seqClock.tempo = ~bpm / 60;
    };
    "[Gladiola] Tempo set to % BPM.".format(~bpm).postln;
};

~clearPattern = {
    ~steps = Array.fill(~stepCount, { defaultStep.value });
    "[Gladiola] Pattern cleared.".postln;
};

~stepToXY = { |step|
    [step % 16, step.div(16)]
};

~xyToStep = { |x, y|
    (y * 16) + x
};

"[Gladiola] sequencer.scd loaded.".postln;
)

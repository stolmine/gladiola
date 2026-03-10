(
~modDepthValues = [1.0, 0.7, 0.45, 0.25, 0.12, 0.05, 0];
~modShapeNames = [\sine, \square, \triangle, \brownian, \random, \sawUp, \sawDown];
~modRateNudges = [16, 4, 1, 0, -1, -4, -16];

~modDestKeys = [\sample, \pitch, \velocity, \gateLength, \filter, \pan, \delaySend,
    \attack, \reverse, \loopLength, \loopRegion, \ratchet, \probability, \bitcrush];
~modArgNames = [nil, \modPitch, \modVelocity, \modGateLength, \modFilter, \modPan, \modDelaySend,
    \modAttack, \modReverse, \modLoopLength, \modLoopRegion, \modRatchet, nil, \modBitcrush];

~modDepthForRow = { |row| ~modDepthValues[row.clip(0, 6)] };
~modRowForDepth = { |depth|
    var best = 6;
    ~modDepthValues.do { |v, i| if((depth - v).abs < (depth - ~modDepthValues[best]).abs) { best = i } };
    best
};
~trackHasModulation = { |trackIdx|
    ~trackModSettings[trackIdx][\depths].any { |d| d > 0 }
};

~modDepthFineValue = { |pos127| pos127 / 126.0 };
~modDepthFinePosition = { |depth| (depth * 126.0).round.asInteger.clip(0, 126) };

// Phase offset helpers
// Row 0-6 mapping: -180, -120, -60, 0, +60, +120, +180 degrees → normalized 0.0-1.0
~phaseValues = [0.5, 0.667, 0.833, 0.0, 0.167, 0.333, 0.5];

~phaseRowForValue = { |phase|
    var best = 3;
    ~phaseValues.do { |v, i|
        if((phase - v).abs < (phase - ~phaseValues[best]).abs) { best = i }
    };
    best
};

~phaseArgNames = [nil, \phasePitch, \phaseVelocity, \phaseGateLength, \phaseFilter, \phasePan, \phaseDelaySend,
    \phaseAttack, \phaseReverse, \phaseLoopLength, \phaseLoopRegion, \phaseRatchet, nil, \phaseBitcrush];

~destHasPhase = { |destIdx| true };

~phaseFineValue = { |pos127| pos127 / 126.0 };
~phaseFinePosition = { |phase| (phase * 126.0).round.asInteger.clip(0, 126) };

~lfoValueAtPhase = { |shape, phase01|
    // Returns -1 to 1 for deterministic shapes; phase01 is 0.0-1.0 cycle position
    case
    { shape == 0 } { sin(phase01 * 2pi) }           // sine
    { shape == 1 } { if(phase01 < 0.5) { 1 } { -1 } } // square
    { shape == 2 } {                                  // triangle
        if(phase01 < 0.25) { phase01 * 4 }
        { if(phase01 < 0.75) { 2 - (phase01 * 4) } { (phase01 * 4) - 4 } }
    }
    { shape == 5 } { (phase01 * 2) - 1 }             // saw up
    { shape == 6 } { 1 - (phase01 * 2) }             // saw down
    { true } { 0 }                                    // brownian/random: no shift
};

"[Gladiola] lfo_params.scd loaded.".postln;
)

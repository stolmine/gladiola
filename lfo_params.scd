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

"[Gladiola] lfo_params.scd loaded.".postln;
)

(
~fxParamKeys = [\lfoControl, \inGain, \pit, \pos, \size, \dens, \tex, \spread, \fb, \rvb, \toggles, \satDepth, \satType, \tilt, \compAmount, \compColor];

~fxCloudsKeys = [\inGain, \pit, \pos, \size, \dens, \tex, \spread, \fb, \rvb];

~fxCloudsValues = Dictionary.newFrom([
    \inGain,  [4.0, 2.5, 1.5, 1.0, 0.7, 0.45, 0.25],
    \pit,     [24, 16, 8, 0, -8, -16, -24],
    \pos,     [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0.0],
    \size,    [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0.0],
    \dens,    [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0.0],
    \tex,     [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0.0],
    \spread,  [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0.0],
    \fb,      [0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0],
    \rvb,     [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0.0]
]);

// ~fxCloudsDefaults is defined in sequencer.scd as ~fxCloudsParams.copy

~fxCloudsPositionForValue = { |key, value|
    var values = ~fxCloudsValues[key];
    var best = 0;
    values.do { |v, i| if((value - v).abs < (value - values[best]).abs) { best = i } };
    best
};

~fxCloudsValueForPosition = { |key, row|
    ~fxCloudsValues[key][row.clip(0, 6)]
};

~fxCloudsCenterPos = { |key|
    if([\inGain, \pit, \dens].includes(key)) { 3 } { nil }
};

~fxMasterKeys = [\satDepth, \satType, \tilt, \compAmount, \compColor];
~fxMasterValues = Dictionary.newFrom([
    \satDepth,   [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0],
    \satType,    [6, 5, 4, 3, 2, 1, 0],
    \tilt,       [1, 0.67, 0.33, 0, -0.33, -0.67, -1],
    \compAmount, [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0],
    \compColor,  [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0]
]);
~fxMasterPositionForValue = { |key, value|
    var values = ~fxMasterValues[key];
    var best = 0;
    values.do { |v, i| if((value - v).abs < (value - values[best]).abs) { best = i } };
    best
};
~fxMasterValueForPosition = { |key, row|
    ~fxMasterValues[key][row.clip(0, 6)]
};
~fxMasterCenterPos = { |key|
    if(key == \tilt) { 3 } { nil }
};

~fxCloudsFineRanges = Dictionary.newFrom([
    \inGain, [0.25, 4.0],
    \pit,    [-48, 48],
    \pos,    [0.0, 1.0],
    \size,   [0.0, 1.0],
    \dens,   [0.0, 1.0],
    \tex,    [0.0, 1.0],
    \spread, [0.0, 1.0],
    \fb,     [0.0, 0.6],
    \rvb,    [0.0, 1.0]
]);
~fxCloudsFineValueForPosition = { |key, pos127|
    var range = ~fxCloudsFineRanges[key];
    range[0] + (pos127 / 126.0 * (range[1] - range[0]))
};
~fxCloudsFinePositionForValue = { |key, value|
    var range = ~fxCloudsFineRanges[key];
    ((value - range[0]) / (range[1] - range[0]) * 126.0).round.asInteger.clip(0, 126)
};
~fxCloudsFineCenterPos = { |key|
    if([\inGain, \pit, \dens].includes(key)) { 63 } { nil }
};

~fxMasterFineRanges = Dictionary.newFrom([
    \satDepth,   [0.0, 1.0],
    \satType,    nil,
    \tilt,       [-1.0, 1.0],
    \compAmount, [0.0, 1.0],
    \compColor,  [0.0, 1.0]
]);
~fxMasterHasFine = { |key| key != \satType };
~fxMasterFineValueForPosition = { |key, pos127|
    var range = ~fxMasterFineRanges[key];
    range[0] + (pos127 / 126.0 * (range[1] - range[0]))
};
~fxMasterFinePositionForValue = { |key, value|
    var range = ~fxMasterFineRanges[key];
    ((value - range[0]) / (range[1] - range[0]) * 126.0).round.asInteger.clip(0, 126)
};
~fxMasterFineCenterPos = { |key|
    if(key == \tilt) { 63 } { nil }
};

~fxTrigRateValues = [30, 20, 12, 6, 3, 1, 0];
~fxTrigRateForRow = { |row| ~fxTrigRateValues[row.clip(0, 6)] };
~fxTrigRateRowForValue = { |rate|
    var best = 6;
    ~fxTrigRateValues.do { |v, i| if((rate - v).abs < (rate - ~fxTrigRateValues[best]).abs) { best = i } };
    best
};

~fxModDestKeys = [\inGain, \pit, \pos, \size, \dens, \tex, \spread, \fb, \rvb, \freeze, \mode, \lofi];
~fxModArgNames = [\modInGain, \modPit, \modPos, \modSize, \modDens, \modTex, \modSpread, \modFb, \modRvb, nil, nil, nil];
~fxModPhaseArgNames = [\phaseInGain, \phasePit, \phasePos, \phaseSize, \phaseDens, \phaseTex, \phaseSpread, \phaseFb, \phaseRvb, nil, nil, nil];

~fxHasNonDefault = {
    var nonDefault = false;
    ~fxCloudsKeys.do { |key|
        if(~fxCloudsParams[key] != ~fxCloudsDefaults[key]) { nonDefault = true }
    };
    [\freeze, \mode, \lofi].do { |key|
        if(~fxCloudsParams[key] != ~fxCloudsDefaults[key]) { nonDefault = true }
    };
    if(~fxParams[\satDepth] != 0) { nonDefault = true };
    if(~fxParams[\satType] != 0) { nonDefault = true };
    if(~fxParams[\tilt] != 0) { nonDefault = true };
    if(~fxParams[\compAmount] != 0) { nonDefault = true };
    if(~fxParams[\compColor] != 0) { nonDefault = true };
    nonDefault
};

"[Gladiola] fx_params.scd loaded.".postln;
)

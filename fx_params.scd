(
~fxParamKeys = [
    \delayDiv, \delayFeedback, \delayTone, \delayLevel,
    \granSizeMod, \granPosMod, \granPitchRange, \granLevel,
    \reverbSize, \reverbDamp, \reverbLevel,
    \satDepth, \satType,
    \tilt,
    \compAmount, \compColor
];

~fxParamValues = Dictionary.newFrom([
    \delayDiv,       [1.0, 0.5, 0.25, 0.1875, 0.125, 0.09375, 0.0625],
    \delayFeedback,  [0.95, 0.9, 0.8, 0.6, 0.4, 0.2, 0],
    \delayTone,      [1, 0.67, 0.33, 0, -0.33, -0.67, -1],
    \delayLevel,     [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0],
    \granSizeMod,    [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0],
    \granPosMod,     [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0],
    \granPitchRange, [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0],
    \granLevel,      [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0],
    \reverbSize,     [1.0, 0.85, 0.7, 0.55, 0.4, 0.25, 0.1],
    \reverbDamp,     [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0],
    \reverbLevel,    [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0],
    \satDepth,       [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0],
    \satType,        [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0],
    \tilt,           [1, 0.67, 0.33, 0, -0.33, -0.67, -1],
    \compAmount,     [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0],
    \compColor,      [1.0, 0.83, 0.67, 0.5, 0.33, 0.17, 0],
    \granModDepth,   [0.8, 0.4, 0.2, 0.1, 0.05, 0.02, 0]  // legacy, kept for old session compat
]);

~fxValueForPosition = { |col, row|
    var key = ~fxParamKeys[col];
    ~fxParamValues[key][row.clip(0, 6)]
};

~fxPositionForValue = { |col, value|
    var key = ~fxParamKeys[col];
    var values = ~fxParamValues[key];
    var bestIdx = 0;
    values.do { |v, i|
        if((value - v).abs < (value - values[bestIdx]).abs) { bestIdx = i }
    };
    bestIdx
};

~fxHasNonDefault = {
    var nonDefault = false;
    ~fxParamKeys.do { |key|
        if(~fxParams[key] != ~fxParamDefaults[key]) { nonDefault = true }
    };
    nonDefault
};

"[Gladiola] fx_params.scd loaded.".postln;
)

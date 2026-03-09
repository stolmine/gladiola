(
var pitchValues = [0.125, 0.25, 0.33, 0.5, 0.66, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0];
var loopLengthValues = [0, 1/16, 1/8, 1/4, 3/8, 1/2, 5/8, 3/4, 7/8, 1.0, 2.0, 4.0, 8.0, 8.0, 8.0];
// 1/16 step → 16 steps (full pattern cycle)
var gateLengthValues = [0.0625, 0.125, 0.1875, 0.25, 0.375, 0.5, 0.625, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0, 16];
var bitcrushValues = [0, 0.08, 0.15, 0.23, 0.32, 0.42, 0.52, 0.62, 0.72, 0.8, 0.86, 0.91, 0.95, 0.98, 1.0];
var attackValues = [0.002, 0.005, 0.01, 0.015, 0.025, 0.04, 0.06, 0.09, 0.13, 0.18, 0.25, 0.32, 0.4, 0.45, 0.5];

~paramNamesPage1 = [\bank, \pitch, \velocity, \gateLength, \filter, \pan, \delaySend];
~paramNamesPage2 = [\attack, \reverse, \loopLength, \loopRegion, \ratchet, \probability, \bitcrush];
~paramPage = 0;

~samplesInBank = { |bank|
    if(~sampleBanks.notNil && (bank >= 0) && (bank < ~sampleBanks.size)) {
        ~sampleBanks[bank].select(_.notNil).size
    } { 0 }
};

~currentParamNames = {
    if(~paramPage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 }
};

~valueForPosition = { |paramPage, paramIdx, pos|
    if(paramPage == 0) {
        switch(paramIdx)
        { 0 } { pos }
        { 1 } { pitchValues[pos] }
        { 2 } { (pos + 1) / 15.0 }
        { 3 } { gateLengthValues[pos] }
        { 4 } { (pos - 7) / 7.0 }
        { 5 } { (pos - 7) / 7.0 }
        { 6 } { pos / 14.0 }
    } {
        switch(paramIdx)
        { 0 } { attackValues[pos] }
        { 1 } { pos }
        { 2 } { loopLengthValues[pos] }
        { 3 } { pos / 14.0 }
        { 4 } { pos + 1 }
        { 5 } { (pos + 1) / 15.0 }
        { 6 } { bitcrushValues[pos] }
    }
};

~positionForValue = { |paramPage, paramIdx, val|
    if(paramPage == 0) {
        switch(paramIdx)
        { 0 } { val.asInteger }
        { 1 } { pitchValues.indexOf(val) ?? { 3 } }
        { 2 } { ((val * 15.0) - 1).round.asInteger.clip(0, 14) }
        { 3 } {
            var best = 0;
            gateLengthValues.do { |gv, i|
                if((val - gv).abs < (val - gateLengthValues[best]).abs) { best = i }
            };
            best
        }
        { 4 } { ((val * 7.0) + 7).round.asInteger.clip(0, 14) }
        { 5 } { ((val * 7.0) + 7).round.asInteger.clip(0, 14) }
        { 6 } { (val * 14.0).round.asInteger.clip(0, 14) }
    } {
        switch(paramIdx)
        { 0 } {
            var best = 0;
            attackValues.do { |av, i|
                if((val - av).abs < (val - attackValues[best]).abs) { best = i }
            };
            best
        }
        { 1 } { val.asInteger.clip(0, 1) }
        { 2 } {
            var best = 0;
            loopLengthValues.do { |lv, i|
                if((val - lv).abs < (val - loopLengthValues[best]).abs) { best = i }
            };
            best
        }
        { 3 } { (val * 14.0).round.asInteger.clip(0, 14) }
        { 4 } { (val - 1).asInteger.clip(0, 7) }
        { 5 } { ((val * 15.0) - 1).round.asInteger.clip(0, 14) }
        { 6 } {
            var best = 0;
            bitcrushValues.do { |bv, i|
                if((val - bv).abs < (val - bitcrushValues[best]).abs) { best = i }
            };
            best
        }
    }
};

~numValidPositions = { |paramPage, paramIdx, trackIdx, stepIdx|
    if(paramPage == 0) {
        switch(paramIdx)
        { 0 } {
            if(trackIdx.notNil) {
                if(~tracks[trackIdx][\sliceMode] == true) { 16 } {
                    var bank = if(stepIdx.notNil) { ~tracks[trackIdx][\steps][stepIdx][\bank] } { 0 };
                    ~samplesInBank.(bank).max(1)
                }
            } {
                ~samplesInBank.(0).max(1)
            }
        }
        { 1 } { 15 }
        { 2 } { 15 }
        { 3 } { 15 }
        { 4 } { 15 }
        { 5 } { 15 }
        { 6 } { 15 }
    } {
        switch(paramIdx)
        { 0 } { 15 }
        { 1 } { 2 }
        { 2 } { 15 }
        { 3 } { 15 }
        { 4 } { 8 }
        { 5 } { 15 }
        { 6 } { 15 }
    }
};

// Center position for bipolar params (nil = no center)
~paramCenterPos = { |paramPage, paramIdx|
    if(paramPage == 0) {
        if(paramIdx == 1) { 6 } {
            if((paramIdx == 4) || (paramIdx == 5)) { 7 } { nil }
        }
    } { nil }
};

// Fine fader: 127-position precision control
~paramHasFine = { |paramPage, paramIdx|
    if(paramPage == 0) { paramIdx >= 1 } {
        [0, 2, 3, 5, 6].includes(paramIdx)
    }
};

~fineParamRanges = Dictionary[
    'p0i1' -> [0.125, 4.0],   'p0i2' -> [0.067, 1.0],
    'p0i3' -> [0.0625, 16.0], 'p0i4' -> [-1.0, 1.0],
    'p0i5' -> [-1.0, 1.0],    'p0i6' -> [0.0, 1.0],
    'p1i0' -> [0.002, 0.5],   'p1i2' -> [0.0, 8.0],
    'p1i3' -> [0.0, 1.0],     'p1i5' -> [0.067, 1.0],
    'p1i6' -> [0.0, 1.0],
];

~fineValueForPosition = { |paramPage, paramIdx, pos127|
    var key = ("p" ++ paramPage ++ "i" ++ paramIdx).asSymbol;
    var range = ~fineParamRanges[key];
    range[0] + (pos127 / 126.0 * (range[1] - range[0]))
};

~finePositionForValue = { |paramPage, paramIdx, value|
    var key = ("p" ++ paramPage ++ "i" ++ paramIdx).asSymbol;
    var range = ~fineParamRanges[key];
    ((value - range[0]) / (range[1] - range[0]) * 126.0).round.asInteger.clip(0, 126)
};

~fineCenterPos = { |paramPage, paramIdx|
    if(paramPage == 0) {
        if(paramIdx == 1) { 28 } {
            if((paramIdx == 4) || (paramIdx == 5)) { 63 } { nil }
        }
    } { nil }
};

~fineSampleList = {
    var count = 0, boundaries = List.new;
    ~numBanks.do { |b|
        var bankSize = ~samplesInBank.(b);
        if(count < 127) { boundaries.add(count) };
        count = count + bankSize;
    };
    Dictionary[\count -> count.min(127), \bankBoundaries -> boundaries.asArray]
};

~fineSampleToBank = { |flatIdx|
    var remaining = flatIdx, result = [0, 0];
    block { |break|
        ~numBanks.do { |b|
            var bankSize = ~samplesInBank.(b);
            if(remaining < bankSize) { result = [b, remaining]; break.() };
            remaining = remaining - bankSize;
        };
    };
    result
};

~fineBankToFlat = { |bank, sample|
    var flat = 0;
    bank.do { |b| flat = flat + ~samplesInBank.(b) };
    flat + sample
};

~resolveSubStepParam = { |step, subIdx, paramName|
    if(step[\subActive][subIdx]) {
        var sub = step[\subSteps][subIdx];
        if(sub.notNil) {
            if(sub[paramName].notNil) { sub[paramName] } { step[paramName] }
        } { step[paramName] }
    } { step[paramName] }
};

~subSeqLength = { |step|
    var last = 0;
    step[\subActive].do { |active, i| if(active) { last = i } };
    last + 1
};

~deepCopyStep = { |step| step.deepCopy };

~clipboardMatchesStep = { |step|
    if(~clipboard.isNil) { false } {
        var match = true;
        ~clipboard.keysValuesDo { |key, val|
            if(val.isKindOf(Array).not) {
                if(step[key] != val) { match = false };
            };
        };
        match
    }
};

"[Gladiola] grid_params.scd loaded.".postln;
)

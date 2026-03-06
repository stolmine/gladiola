(
var pitchValues = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0, 0.125, 0.33, 0.66];
var loopLengthValues = [0.0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.75, 0.875, 0.9375, 1.0];
// 1/16 step → full sustain (100 = sentinel for "no gate")
var gateLengthValues = [0.0625, 0.125, 0.1875, 0.25, 0.375, 0.5, 0.625, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0, 100];

~paramNamesPage1 = [\bank, \pitch, \velocity, \loopLength, \loopRegion, \ratchet, \randomness];
~paramNamesPage2 = [\gateLength, \reverse, \filter, \pan, \probability, \delaySend, \bitcrush];
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
        { 3 } { loopLengthValues[pos] }
        { 4 } { pos / 14.0 }
        { 5 } { pos + 1 }
        { 6 } { pos / 14.0 }
    } {
        switch(paramIdx)
        { 0 } { gateLengthValues[pos] }
        { 1 } { pos }
        { 2 } { (pos - 7) / 7.0 }
        { 3 } { (pos - 7) / 7.0 }
        { 4 } { (pos + 1) / 15.0 }
        { 5 } { pos / 14.0 }
        { 6 } { pos / 14.0 }
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
            loopLengthValues.do { |lv, i|
                if((val - lv).abs < (val - loopLengthValues[best]).abs) { best = i }
            };
            best
        }
        { 4 } { (val * 14.0).round.asInteger.clip(0, 14) }
        { 5 } { (val - 1).asInteger.clip(0, 7) }
        { 6 } { (val * 14.0).round.asInteger.clip(0, 14) }
    } {
        switch(paramIdx)
        { 0 } {
            var best = 0;
            gateLengthValues.do { |gv, i|
                if((val - gv).abs < (val - gateLengthValues[best]).abs) { best = i }
            };
            best
        }
        { 1 } { val.asInteger.clip(0, 1) }
        { 2 } { ((val * 7.0) + 7).round.asInteger.clip(0, 14) }
        { 3 } { ((val * 7.0) + 7).round.asInteger.clip(0, 14) }
        { 4 } { ((val * 15.0) - 1).round.asInteger.clip(0, 14) }
        { 5 } { (val * 14.0).round.asInteger.clip(0, 14) }
        { 6 } { (val * 14.0).round.asInteger.clip(0, 14) }
    }
};

~numValidPositions = { |paramPage, paramIdx, trackIdx, stepIdx|
    if(paramPage == 0) {
        switch(paramIdx)
        { 0 } {
            var bank = if(trackIdx.notNil && stepIdx.notNil) { ~tracks[trackIdx][\steps][stepIdx][\bank] } { 0 };
            ~samplesInBank.(bank).max(1)
        }
        { 1 } { 15 }
        { 2 } { 15 }
        { 3 } { 15 }
        { 4 } { 15 }
        { 5 } { 8 }
        { 6 } { 15 }
    } {
        switch(paramIdx)
        { 0 } { 15 }
        { 1 } { 2 }
        { 2 } { 15 }
        { 3 } { 15 }
        { 4 } { 15 }
        { 5 } { 15 }
        { 6 } { 15 }
    }
};

// Center position for bipolar params (nil = no center)
// Page 2 idx 2 = filter, idx 3 = pan; both centered at position 7
~paramCenterPos = { |paramPage, paramIdx|
    if(paramPage == 1 && ((paramIdx == 2) || (paramIdx == 3))) { 7 } { nil }
};

"[Gladiola] grid_params.scd loaded.".postln;
)

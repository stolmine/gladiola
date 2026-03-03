(
var pitchValues = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0, 0.125, 0.33, 0.66];
var loopLengthValues = [0.0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.75, 0.875, 0.9375, 1.0];
// param 0 is special: column cycles bank, row selects sample within bank
var paramNames = [\bank, \pitch, \velocity, \loopLength, \loopRegion, \ratchet, \randomness];

~heldStep = nil;
~heldXY = nil;
~lengthModalActive = false;
~paramMenuActive = false;
~selectedParam = 0;
~pendingToggle = nil;

~otherRowsForY = { |heldY|
    (0..7).reject { |row| row == heldY }
};

~otherColsForX = { |heldX|
    (0..15).reject { |col| col == heldX }
};

~samplesInBank = { |bank|
    if(~sampleBanks.notNil && (bank >= 0) && (bank < ~sampleBanks.size)) {
        ~sampleBanks[bank].select(_.notNil).size
    } { 0 }
};

~valueForPosition = { |paramIdx, pos|
    switch(paramIdx)
    { 0 } { pos }  // sample index within bank
    { 1 } { pitchValues[pos] }
    { 2 } { (pos + 1) / 15.0 }
    { 3 } { loopLengthValues[pos] }
    { 4 } { pos / 14.0 }
    { 5 } { pos + 1 }
    { 6 } { pos / 14.0 }
};

~positionForValue = { |paramIdx, val|
    switch(paramIdx)
    { 0 } { val.asInteger }  // sample index
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
};

~numValidPositions = { |paramIdx, step|
    switch(paramIdx)
    { 0 } {
        // row shows samples in current bank — limit to populated slots
        var bank = if(step.notNil) { ~steps[step][\bank] } { 0 };
        ~samplesInBank.(bank).max(1)
    }
    { 1 } { 15 }
    { 2 } { 15 }
    { 3 } { 15 }
    { 4 } { 15 }
    { 5 } { 8 }
    { 6 } { 15 }
};

~updateGridLEDs = {
    if(~lengthModalActive) {
        var lenPos, lenXY;
        ~grid.ledAll(GridInterface.ledDim);
        lenPos = ~patternLength - 1;
        lenXY = ~stepToXY.(lenPos);
        ~grid.led(lenXY[0], lenXY[1], GridInterface.ledFull);
    } {
        if(~paramMenuActive && ~heldStep.notNil) {
            var hxy, hx, hy, step, paramRows, valueRow, valueCols;
            var curVal, curPos, numValid;
            hxy = ~stepToXY.(~heldStep);
            hx = hxy[0];
            hy = hxy[1];
            step = ~steps[~heldStep];
            paramRows = ~otherRowsForY.(hy);
            valueRow = paramRows[~selectedParam];

            ~grid.clear;

            // held step
            ~grid.led(hx, hy, GridInterface.ledFull);

            // param column: highlight selected, show bank brightness for slot 0
            paramRows.do { |row, idx|
                var brightness;
                if(idx == ~selectedParam) {
                    brightness = GridInterface.ledBright;
                } {
                    if(idx == 0) {
                        // bank slot: brightness indicates current bank
                        var bankVal = step[\bank];
                        var numBanks = (~numBanks ? 1).max(1);
                        brightness = (GridInterface.ledDim + (bankVal / numBanks.max(1) * (GridInterface.ledFull - GridInterface.ledDim))).round.asInteger.clip(GridInterface.ledDim, GridInterface.ledFull);
                    } {
                        brightness = GridInterface.ledDim;
                    };
                };
                ~grid.led(hx, row, brightness);
            };

            // value row on selected param's row
            valueCols = ~otherColsForX.(hx);

            if(~selectedParam == 0) {
                // param 0: row shows samples in current bank
                curVal = step[\sample];
                curPos = curVal.asInteger;
                numValid = ~numValidPositions.(0, ~heldStep);
            } {
                curVal = step[paramNames[~selectedParam]];
                curPos = ~positionForValue.(~selectedParam, curVal);
                numValid = ~numValidPositions.(~selectedParam, ~heldStep);
            };

            valueCols.do { |col, idx|
                if(idx < numValid) {
                    var brightness = if(idx == curPos) {
                        GridInterface.ledFull
                    } {
                        GridInterface.ledDim
                    };
                    ~grid.led(col, valueRow, brightness);
                };
            };
        } {
            // normal sequencer view
            ~grid.clear;
            128.do { |i|
                if(i < ~patternLength) {
                    var xy = ~stepToXY.(i);
                    var brightness;

                    if(~playing && (i == ~playheadStep)) {
                        brightness = GridInterface.ledFull;
                    } {
                        if(~steps[i][\on]) {
                            var vel = ~steps[i][\velocity];
                            brightness = (GridInterface.ledDim + (vel * (GridInterface.ledBright - GridInterface.ledDim))).round.asInteger;
                        } {
                            brightness = GridInterface.ledOff;
                        }
                    };

                    ~grid.led(xy[0], xy[1], brightness);
                };
            };
        };
    };
};

~initGridHandler = {
    ~grid.key({ |x, y, state|
        if(state == 1) {
            if(~lengthModalActive) {
                var step = ~xyToStep.(x, y);
                ~setPatternLength.(step + 1);
                ~lengthModalActive = false;
                ~updateGridLEDs.();
            } {
                if(~paramMenuActive && ~heldStep.notNil) {
                    var hxy, hx, hy, paramRows, valueRow;
                    hxy = ~stepToXY.(~heldStep);
                    hx = hxy[0];
                    hy = hxy[1];
                    paramRows = ~otherRowsForY.(hy);
                    valueRow = paramRows[~selectedParam];

                    if(x == hx && (y != hy)) {
                        // tap in held column
                        var paramIdx = paramRows.indexOf(y);
                        if(paramIdx.notNil) {
                            if(paramIdx == 0 && (~selectedParam == 0)) {
                                // already on bank param: cycle bank forward
                                var numBanks = (~numBanks ? 1).max(1);
                                var curBank = ~steps[~heldStep][\bank];
                                var newBank = (curBank + 1) % numBanks;
                                var newBankSize;
                                ~steps[~heldStep][\bank] = newBank;
                                newBankSize = ~samplesInBank.(newBank);
                                if(~steps[~heldStep][\sample] >= newBankSize) {
                                    ~steps[~heldStep][\sample] = 0;
                                };
                            } {
                                ~selectedParam = paramIdx;
                            };
                            ~updateGridLEDs.();
                        };
                    } {
                        if(y == valueRow && (x != hx)) {
                            // tap in value row
                            var valueCols = ~otherColsForX.(hx);
                            var slotIdx = valueCols.indexOf(x);
                            if(slotIdx.notNil) {
                                var numValid = ~numValidPositions.(~selectedParam, ~heldStep);
                                if(slotIdx < numValid) {
                                    if(~selectedParam == 0) {
                                        // param 0: row sets sample index
                                        ~steps[~heldStep][\sample] = slotIdx;
                                    } {
                                        var val = ~valueForPosition.(~selectedParam, slotIdx);
                                        ~steps[~heldStep][paramNames[~selectedParam]] = val;
                                    };
                                    ~updateGridLEDs.();
                                };
                            };
                        };
                    };
                } {
                    var step = ~xyToStep.(x, y);
                    if(step < ~patternLength) {
                        ~pendingToggle = step;
                    };
                };
            };
        };
    });

    ~grid.hold({ |x, y|
        var step = ~xyToStep.(x, y);
        if(step < ~patternLength) {
            ~pendingToggle = nil;
            ~heldStep = step;
            ~heldXY = [x, y];
            ~paramMenuActive = true;
            ~selectedParam = 0;
            ~updateGridLEDs.();
        };
    });

    ~grid.release({ |x, y|
        if(~paramMenuActive) {
            if(~heldXY.notNil && (x == ~heldXY[0]) && (y == ~heldXY[1])) {
                ~paramMenuActive = false;
                ~heldStep = nil;
                ~heldXY = nil;
                ~updateGridLEDs.();
            };
        } {
            if(~pendingToggle.notNil) {
                var step = ~pendingToggle;
                ~pendingToggle = nil;
                ~steps[step][\on] = ~steps[step][\on].not;
                ~updateGridLEDs.();
            };
        };
    });

    ~grid.doubleTap({ |x, y|
        if(x == 0 && y == 0) {
            ~pendingToggle = nil;
            ~paramMenuActive = false;
            ~heldStep = nil;
            ~heldXY = nil;
            ~lengthModalActive = true;
            ~updateGridLEDs.();
        };
    });

    "[Gladiola] Grid handler initialized.".postln;
};

"[Gladiola] grid_handler.scd loaded.".postln;
)

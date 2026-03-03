(
var pitchValues = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0, 0.125, 0.33, 0.66];
var loopLengthValues = [0.0, 0.0625, 0.125, 0.1875, 0.25, 0.3125, 0.375, 0.4375, 0.5, 0.5625, 0.625, 0.75, 0.875, 0.9375, 1.0];
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

~valueForPosition = { |paramIdx, pos|
    switch(paramIdx)
    { 0 } { pos }
    { 1 } { pitchValues[pos] }
    { 2 } { (pos + 1) / 15.0 }
    { 3 } { loopLengthValues[pos] }
    { 4 } { pos / 14.0 }
    { 5 } { pos + 1 }
    { 6 } { pos / 14.0 }
};

~positionForValue = { |paramIdx, val|
    switch(paramIdx)
    { 0 } { val.asInteger }
    { 1 } { pitchValues.indexOf(val) ?? { 3 } }
    { 2 } { ((val * 15.0) - 1).round.asInteger.clip(0, 14) }
    { 3 } { loopLengthValues.indexOf(val) ?? { 14 } }
    { 4 } { (val * 14.0).round.asInteger.clip(0, 14) }
    { 5 } { (val - 1).asInteger.clip(0, 7) }
    { 6 } { (val * 14.0).round.asInteger.clip(0, 14) }
};

~numValidPositions = { |paramIdx|
    switch(paramIdx)
    { 0 } { 15 }
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
            var hxy, hx, hy, step, paramRows, valueCols, curVal, curPos, numValid;
            hxy = ~stepToXY.(~heldStep);
            hx = hxy[0];
            hy = hxy[1];
            step = ~steps[~heldStep];

            ~grid.clear;
            ~grid.led(hx, hy, GridInterface.ledFull);

            paramRows = ~otherRowsForY.(hy);
            paramRows.do { |row, idx|
                var brightness = if(idx == ~selectedParam) {
                    GridInterface.ledBright
                } {
                    GridInterface.ledDim
                };
                ~grid.led(hx, row, brightness);
            };

            valueCols = ~otherColsForX.(hx);
            curVal = step[paramNames[~selectedParam]];
            curPos = ~positionForValue.(~selectedParam, curVal);
            numValid = ~numValidPositions.(~selectedParam);

            valueCols.do { |col, idx|
                if(idx < numValid) {
                    var brightness = if(idx == curPos) {
                        GridInterface.ledBright
                    } {
                        GridInterface.ledDim
                    };
                    ~grid.led(col, hy, brightness);
                };
            };
        } {
            ~grid.clear;
            128.do { |i|
                var xy, brightness;
                if(i < ~patternLength) {
                    xy = ~stepToXY.(i);
                    brightness = if(i == ~currentStep) {
                        GridInterface.ledFull
                    } {
                        if(~steps[i][\on]) {
                            GridInterface.ledMedium
                        } {
                            GridInterface.ledOff
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
                    var hxy, hx, hy;
                    hxy = ~stepToXY.(~heldStep);
                    hx = hxy[0];
                    hy = hxy[1];

                    if(x == hx && (y != hy)) {
                        var paramRows = ~otherRowsForY.(hy);
                        var paramIdx = paramRows.indexOf(y);
                        if(paramIdx.notNil) {
                            ~selectedParam = paramIdx;
                            ~updateGridLEDs.();
                        };
                    } {
                        if(y == hy && (x != hx)) {
                            var valueCols = ~otherColsForX.(hx);
                            var slotIdx = valueCols.indexOf(x);
                            if(slotIdx.notNil) {
                                var numValid = ~numValidPositions.(~selectedParam);
                                if(slotIdx < numValid) {
                                    var val = ~valueForPosition.(~selectedParam, slotIdx);
                                    ~steps[~heldStep][paramNames[~selectedParam]] = val;
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

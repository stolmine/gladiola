(
~updateGridLEDs = {
    if(~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil) {
        var track = ~tracks[~heldTrack];
        var step = track[\steps][~heldStepIdx];
        var paramNames = ~currentParamNames.();
        var numParams = paramNames.size;

        ~grid.clear;

        // Held step bright
        ~grid.led(~heldStepIdx, ~heldTrack, GridInterface.ledFull);

        // Param column: rows 0-7 except heldTrack (7 params = 6 track rows + row 7)
        8.do { |row|
            if(row != ~heldTrack) {
                var paramIdx = ~paramIndexForRow.(row, ~heldTrack);
                if(paramIdx.notNil && (paramIdx < numParams)) {
                    var brightness;
                    if(paramIdx == 0 && (~paramPage == 0)) {
                        var bankVal = step[\bank];
                        var numBanks = (~numBanks ? 1).max(1);
                        brightness = (GridInterface.ledDim + ((bankVal + 1) / numBanks * (GridInterface.ledFull - GridInterface.ledDim))).round.asInteger.clip(GridInterface.ledDim, GridInterface.ledFull);
                    } {
                        brightness = if(paramIdx == ~selectedParam) {
                            GridInterface.ledBright
                        } {
                            GridInterface.ledDim
                        };
                    };
                    ~grid.led(~heldStepIdx, row, brightness);
                };
            };
        };

        // Value row for selected param
        {
            var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
            var curVal, curPos, numValid;

            if(~selectedParam == 0 && (~paramPage == 0)) {
                curVal = step[\sample];
                curPos = curVal.asInteger;
                numValid = ~numValidPositions.(0, 0, ~heldTrack, ~heldStepIdx);
            } {
                curVal = step[paramNames[~selectedParam]];
                curPos = ~positionForValue.(~paramPage, ~selectedParam, curVal);
                numValid = ~numValidPositions.(~paramPage, ~selectedParam, ~heldTrack, ~heldStepIdx);
            };

            16.do { |col|
                if(col != ~heldStepIdx) {
                    var valIdx = if(col < ~heldStepIdx) { col } { col - 1 };
                    if(valIdx < numValid) {
                        var brightness = if(valIdx == curPos) {
                            GridInterface.ledFull
                        } {
                            GridInterface.ledDim
                        };
                        ~grid.led(col, valueRow, brightness);
                    };
                };
            };
        }.();

        // Page toggle: shifts to col 4 when held step is col 3
        {
            var pageToggleCol = if(~heldStepIdx == 3) { 4 } { 3 };
            ~grid.led(pageToggleCol, 7, if(~paramPage == 1) { GridInterface.ledFull } { GridInterface.ledMedium });
        }.();

    } {
        if(~utilityOverlayActive) {
            var col = switch(~utilityOverlayType)
                { \clockDiv } { 1 }
                { \delayDiv } { 2 }
                { \transpose } { 4 };

            ~grid.clear;

            if(~utilityOverlayType == \transpose) {
                var transposeValues = [0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0];
                transposeValues.do { |val, i|
                    var brightness = if(val == ~transpose) {
                        GridInterface.ledFull
                    } {
                        GridInterface.ledDim
                    };
                    ~grid.led(col, i, brightness);
                };
            } {
                var divValues = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0];
                var currentDiv = if(~utilityOverlayType == \clockDiv) { ~clockDiv } { ~delayDiv };
                divValues.do { |div, i|
                    var brightness = if(div == currentDiv) {
                        GridInterface.ledFull
                    } {
                        GridInterface.ledDim
                    };
                    ~grid.led(col, i, brightness);
                };
            };
        } {
            if(~lengthModalTrack.notNil) {
                var track = ~tracks[~lengthModalTrack];
                var row = ~lengthModalTrack;
                var startS = track[\startStep];
                var endS = track[\endStep];

                ~grid.clear;

                16.do { |col|
                    var brightness;
                    if(~stepInRange.(col, startS, endS)) {
                        brightness = GridInterface.ledDim;
                    } {
                        brightness = GridInterface.ledOff;
                    };
                    ~grid.led(col, row, brightness);
                };

                if(~lengthModalMode == \setEnd) {
                    ~grid.led(startS, row, GridInterface.ledFull);
                } {
                    ~grid.led(endS, row, GridInterface.ledFull);
                };

                ~numTracks.do { |trackIdx|
                    if(trackIdx != ~lengthModalTrack) {
                        var t = ~tracks[trackIdx];
                        ~stepsPerTrack.do { |stepIdx|
                            if(~stepInRange.(stepIdx, t[\startStep], t[\endStep])) {
                                if(t[\steps][stepIdx][\on]) {
                                    var vel = t[\steps][stepIdx][\velocity];
                                    ~grid.led(stepIdx, trackIdx,
                                        (GridInterface.ledDim + (vel * (GridInterface.ledMedium - GridInterface.ledDim))).round.asInteger
                                    );
                                };
                            };
                        };
                    };
                };
            } {
                // Normal view
                ~grid.clear;

                ~numTracks.do { |trackIdx|
                    var track = ~tracks[trackIdx];
                    ~stepsPerTrack.do { |stepIdx|
                        var brightness;
                        if(~stepInRange.(stepIdx, track[\startStep], track[\endStep])) {
                            if(~playing && (stepIdx == ((track[\currentStep] - 1) % ~stepsPerTrack))) {
                                brightness = GridInterface.ledFull;
                            } {
                                if(track[\muted]) {
                                    brightness = if(track[\steps][stepIdx][\on]) {
                                        GridInterface.ledDim
                                    } {
                                        GridInterface.ledOff
                                    };
                                } {
                                    if(track[\steps][stepIdx][\on]) {
                                        var vel = track[\steps][stepIdx][\velocity];
                                        brightness = (GridInterface.ledDim + (vel * (GridInterface.ledMedium - GridInterface.ledDim))).round.asInteger;
                                    } {
                                        brightness = GridInterface.ledOff;
                                    };
                                };
                            };
                            ~grid.led(stepIdx, trackIdx, brightness);
                        };
                    };
                };

                // Row 7: utility
                ~grid.led(0, 7, if(~playing) { GridInterface.ledFull } { GridInterface.ledDim });
                ~grid.led(1, 7, GridInterface.ledDim);
                ~grid.led(2, 7, GridInterface.ledDim);
                ~grid.led(3, 7, if(~globalReverse) { GridInterface.ledFull } { GridInterface.ledDim });
                ~grid.led(4, 7, if(~transpose != 1.0) { GridInterface.ledFull } { GridInterface.ledDim });
                4.do { |i|
                    ~grid.led(5 + i, 7, if(~presets[i].notNil) { GridInterface.ledFull } { GridInterface.ledOff });
                };
                ~numTracks.do { |i|
                    ~grid.led(9 + i, 7, if(~tracks[i][\muted]) { GridInterface.ledFull } { GridInterface.ledDim });
                };
            };
        };
    };
};

"[Gladiola] grid_leds.scd loaded.".postln;
)

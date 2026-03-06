(
~updateGridLEDs = {
    if(~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil) {
        var track = ~tracks[~heldTrack];
        var step = track[\steps][~heldStepIdx];
        var paramNames = ~currentParamNames.();
        var numParams = paramNames.size;
        var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
        var actionPos = ~overlayActionPositions.(~heldTrack, ~heldStepIdx, valueRow);
        var curVal, curPos, numValid;

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
                // Skip action button cells to avoid visual collision
                if((col == actionPos[\pageCol]) && ((valueRow == actionPos[\pageRow]) || (valueRow == actionPos[\copyRow]))) {
                } {
                    var valIdx = if(col < ~heldStepIdx) { col } { col - 1 };
                    if(valIdx < numValid) {
                        var centerPos = ~paramCenterPos.(~paramPage, ~selectedParam);
                        var brightness = if(valIdx == curPos) {
                            GridInterface.ledFull
                        } {
                            if(centerPos.notNil && (valIdx == centerPos)) {
                                GridInterface.ledMedium
                            } {
                                GridInterface.ledDim
                            }
                        };
                        ~grid.led(col, valueRow, brightness);
                    };
                };
            };
        };

        // Action buttons: P (page toggle) and C (copy)
        ~grid.led(actionPos[\pageCol], actionPos[\pageRow],
            if(~paramPage == 1) { GridInterface.ledFull } { GridInterface.ledMedium });
        ~grid.led(actionPos[\copyCol], actionPos[\copyRow],
            if(~clipboard.notNil) { GridInterface.ledBright } { GridInterface.ledDim });

    } {
        if(~trackParamActive && ~trackParamCol.notNil && ~trackParamTrack.notNil) {
            var paramNames = ~currentParamNames.();
            var numParams = paramNames.size;
            var valueRow = ~selectedParam;
            var pagePos = ~trackOverlayPagePos.(~trackParamCol, valueRow);

            ~grid.clear;

            // Held mute key bright
            ~grid.led(~trackParamCol, 7, GridInterface.ledFull);

            // Param column: rows 0-6 at trackParamCol
            7.do { |row|
                if(row < numParams) {
                    var brightness;
                    if(row == 0 && (~paramPage == 0)) {
                        // Bank param: gradient based on bank value
                        var bankVal = ~tracks[~trackParamTrack][\steps][0][\bank];
                        var numBanks = (~numBanks ? 1).max(1);
                        brightness = (GridInterface.ledDim + ((bankVal + 1) / numBanks * (GridInterface.ledFull - GridInterface.ledDim))).round.asInteger.clip(GridInterface.ledDim, GridInterface.ledFull);
                    } {
                        brightness = if(row == ~selectedParam) {
                            GridInterface.ledBright
                        } {
                            GridInterface.ledDim
                        };
                    };
                    ~grid.led(~trackParamCol, row, brightness);
                };
            };

            // Value row at row = selectedParam
            // Check if all steps agree on the selected param value (unanimous check)
            if(~selectedParam == 0 && (~paramPage == 0)) {
                // Sample param
                var firstVal = ~tracks[~trackParamTrack][\steps][0][\sample];
                var unanimous = ~tracks[~trackParamTrack][\steps].every { |step| step[\sample] == firstVal };
                var curPos = if(unanimous) { firstVal.asInteger } { nil };
                var numValid = ~numValidPositions.(0, 0, ~trackParamTrack, 0);

                16.do { |col|
                    if(col != ~trackParamCol && (col != pagePos[\pageCol] || (valueRow != pagePos[\pageRow]))) {
                        var valIdx = ~valueIdxForCol.(col, ~trackParamCol);
                        if(valIdx.notNil && (valIdx < numValid)) {
                            var brightness = if(curPos.notNil && (valIdx == curPos)) {
                                GridInterface.ledFull
                            } {
                                GridInterface.ledDim
                            };
                            ~grid.led(col, valueRow, brightness);
                        };
                    };
                };
            } {
                var curVal = ~tracks[~trackParamTrack][\steps][0][paramNames[~selectedParam]];
                var unanimous = ~tracks[~trackParamTrack][\steps].every { |step| step[paramNames[~selectedParam]] == curVal };
                var curPos = if(unanimous) { ~positionForValue.(~paramPage, ~selectedParam, curVal) } { nil };
                var numValid = ~numValidPositions.(~paramPage, ~selectedParam, ~trackParamTrack, 0);
                var centerPos = ~paramCenterPos.(~paramPage, ~selectedParam);

                16.do { |col|
                    if(col != ~trackParamCol && (col != pagePos[\pageCol] || (valueRow != pagePos[\pageRow]))) {
                        var valIdx = ~valueIdxForCol.(col, ~trackParamCol);
                        if(valIdx.notNil && (valIdx < numValid)) {
                            var brightness = if(curPos.notNil && (valIdx == curPos)) {
                                GridInterface.ledFull
                            } {
                                if(centerPos.notNil && (valIdx == centerPos)) {
                                    GridInterface.ledMedium
                                } {
                                    GridInterface.ledDim
                                }
                            };
                            ~grid.led(col, valueRow, brightness);
                        };
                    };
                };
            };

            // Page toggle button (P only, no C)
            ~grid.led(pagePos[\pageCol], pagePos[\pageRow],
                if(~paramPage == 1) { GridInterface.ledFull } { GridInterface.ledMedium });


        } {
            if(~utilityOverlayActive) {
            ~grid.clear;

            if(~utilityOverlayType == \clockDiv) {
                var divValues = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0];
                ~numTracks.do { |trackIdx|
                    var trackDiv = ~tracks[trackIdx][\clockDiv];
                    divValues.do { |div, colIdx|
                        var brightness = if(div == trackDiv) {
                            GridInterface.ledFull
                        } {
                            GridInterface.ledDim
                        };
                        ~grid.led(colIdx, trackIdx, brightness);
                    };
                };
            } {
                if(~utilityOverlayType == \fxMatrix) {
                    // FX matrix: 16 columns, fader style (up=more)
                    // Current value = full, below = half, above = quarter
                    16.do { |col|
                        var key = ~fxParamKeys[col];
                        var currentRow = ~fxPositionForValue.(col, ~fxParams[key]);
                        7.do { |row|
                            var brightness = if(row == currentRow) {
                                GridInterface.ledFull
                            } {
                                if(row > currentRow) {
                                    GridInterface.ledMedium
                                } {
                                    GridInterface.ledDim
                                }
                            };
                            ~grid.led(col, row, brightness);
                        };
                    };
                } {
                    // Transpose overlay
                    var transposeValues = [0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0];
                    transposeValues.do { |val, i|
                        var brightness = if(val == ~transpose) {
                            GridInterface.ledFull
                        } {
                            GridInterface.ledDim
                        };
                        ~grid.led(4, i, brightness);
                    };
                };
            };
        } {
            if(~lengthModalTrack.notNil) {
                var track = ~tracks[~lengthModalTrack];
                var row = ~lengthModalTrack;
                var startS = track[\startStep];
                var endS = track[\endStep];

                ~grid.clear;

                if(~lengthModalMode == \setEnd) {
                    // Selecting end: all columns available, start point bright
                    16.do { |col|
                        ~grid.led(col, row, GridInterface.ledDim);
                    };
                    ~grid.led(startS, row, GridInterface.ledFull);
                } {
                    // Selecting start: show current range, end point bright
                    16.do { |col|
                        var brightness = if(~stepInRange.(col, startS, endS)) {
                            GridInterface.ledDim
                        } {
                            GridInterface.ledOff
                        };
                        ~grid.led(col, row, brightness);
                    };
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
                    var prevStep = (track[\currentStep] - 1) % ~stepsPerTrack;
                    if(~stepInRange.(prevStep, track[\startStep], track[\endStep]).not) {
                        prevStep = track[\endStep];
                    };
                    ~stepsPerTrack.do { |stepIdx|
                        var brightness;
                        if(~stepInRange.(stepIdx, track[\startStep], track[\endStep])) {
                            if(~playing && (stepIdx == prevStep)) {
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
                ~grid.led(2, 7, if(~fxHasNonDefault.()) { GridInterface.ledFull } { GridInterface.ledDim });
                ~grid.led(3, 7, if(~globalReverse) { GridInterface.ledFull } { GridInterface.ledDim });
                ~grid.led(4, 7, if(~transpose != 1.0) { GridInterface.ledFull } { GridInterface.ledDim });
                4.do { |i|
                    ~grid.led(5 + i, 7, if(~presets[i].notNil) { GridInterface.ledFull } { GridInterface.ledOff });
                };
                ~numTracks.do { |i|
                    ~grid.led(9 + i, 7, if(~tracks[i][\muted]) { GridInterface.ledFull } { GridInterface.ledDim });
                };
                if(~transportHeld == true) {
                    ~grid.led(0, 7, GridInterface.ledFull);
                    // Column 0 rows 0-6: BPM nudge (+10,+5,+1,reset,-1,-5,-10)
                    7.do { |row|
                        var brightness = if(row == 3) { GridInterface.ledBright } { GridInterface.ledDim };
                        ~grid.led(0, row, brightness);
                    };
                };
            };
        };
        };
    };
};

"[Gladiola] grid_leds.scd loaded.".postln;
)

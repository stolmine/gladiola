(
~updateGridLEDs = {
    var pulsePhase, pulseBright, longestDur, pulsePeriod;

    longestDur = 4;
    ~numTracks.do { |i|
        var t = ~tracks[i];
        var len, dur;
        len = if(t[\startStep] <= t[\endStep]) {
            t[\endStep] - t[\startStep] + 1
        } {
            (~stepsPerTrack - t[\startStep]) + t[\endStep] + 1
        };
        dur = len * t[\clockDiv];
        if(dur > longestDur) { longestDur = dur };
    };
    pulsePeriod = longestDur / 4;

    if(~seqClock.notNil && ~playing) {
        pulsePhase = ((~seqClock.beats % pulsePeriod) / pulsePeriod * 16).asInteger;
    } {
        ~presetPulsePhase = (~presetPulsePhase + 1) % 16;
        pulsePhase = ~presetPulsePhase;
    };
    pulseBright = if(pulsePhase < 8) {
        GridInterface.ledDim + ((pulsePhase / 7) * (GridInterface.ledFull - GridInterface.ledDim)).round.asInteger
    } {
        GridInterface.ledFull - (((pulsePhase - 8) / 7) * (GridInterface.ledFull - GridInterface.ledDim)).round.asInteger
    };

    if(~fineActive == true) {
        var currentPos, centerPos = nil, sampleInfo = nil;

        ~grid.clear;

        // Exit key
        ~grid.led(0, 0, pulseBright);

        // Compute current position and center
        switch(~fineContext)
        { \step } {
            if(~fineParamIdx == 0 && (~fineParamPage == 0)) {
                // Sample
                var step = ~tracks[~fineTrackIdx][\steps][~fineStepIdx];
                var bank, sample;
                if(~fineSubStepIdx.notNil) {
                    bank = ~resolveSubStepParam.(step, ~fineSubStepIdx, \bank);
                    sample = ~resolveSubStepParam.(step, ~fineSubStepIdx, \sample);
                } {
                    bank = step[\bank];
                    sample = step[\sample];
                };
                currentPos = ~fineBankToFlat.(bank, sample);
                sampleInfo = ~fineSampleList.();
            } {
                var step = ~tracks[~fineTrackIdx][\steps][~fineStepIdx];
                var paramNames = if(~fineParamPage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 };
                var curVal = if(~fineSubStepIdx.notNil) {
                    ~resolveSubStepParam.(step, ~fineSubStepIdx, paramNames[~fineParamIdx])
                } {
                    step[paramNames[~fineParamIdx]]
                };
                currentPos = ~finePositionForValue.(~fineParamPage, ~fineParamIdx, curVal);
                centerPos = ~fineCenterPos.(~fineParamPage, ~fineParamIdx);
            };
        }
        { \track } {
            if(~fineParamIdx == 0 && (~fineParamPage == 0)) {
                var step = ~tracks[~fineTrackIdx][\steps][0];
                currentPos = ~fineBankToFlat.(step[\bank], step[\sample]);
                sampleInfo = ~fineSampleList.();
            } {
                var paramNames = if(~fineParamPage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 };
                var curVal = ~tracks[~fineTrackIdx][\steps][0][paramNames[~fineParamIdx]];
                currentPos = ~finePositionForValue.(~fineParamPage, ~fineParamIdx, curVal);
                centerPos = ~fineCenterPos.(~fineParamPage, ~fineParamIdx);
            };
        }
        { \fx } {
            var key = ~fxParamKeys[~fineFxCol];
            currentPos = ~fxFinePositionForValue.(~fineFxCol, ~fxParams[key]);
            centerPos = ~fxFineCenterPos.(~fineFxCol);
        }
        { \mixer } {
            currentPos = ~mixerFinePosition.(~trackVolumes[~fineMixerTrack]);
        }
        { \modDepth } {
            var depth = ~trackModSettings[~fineTrackIdx][\depths][~fineModDest];
            currentPos = ~modDepthFinePosition.(depth);
        };

        // Render 127 value cells
        127.do { |pos|
            var cellIdx = pos + 1;
            var cx = cellIdx % 16;
            var cy = cellIdx div: 16;
            var brightness;

            if(pos == currentPos) {
                brightness = GridInterface.ledFull;
            } {
                if(sampleInfo.notNil) {
                    // Sample mode
                    if(pos >= sampleInfo[\count]) {
                        brightness = GridInterface.ledOff;
                    } {
                        if(sampleInfo[\bankBoundaries].includes(pos)) {
                            brightness = GridInterface.ledMedium;
                        } {
                            brightness = GridInterface.ledDim;
                        };
                    };
                } {
                    if(centerPos.notNil && (pos == centerPos)) {
                        brightness = GridInterface.ledMedium;
                    } {
                        brightness = GridInterface.ledDim;
                    };
                };
            };

            ~grid.led(cx, cy, brightness);
        };
    } {

    if(~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil) {
        var track = ~tracks[~heldTrack];
        var step = track[\steps][~heldStepIdx];
        var paramNames = if(~subStepEditing) {
            if(~subStepParamPage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 }
        } { ~currentParamNames.() };
        var numParams = paramNames.size;
        var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
        var layout = ~overlayLayout.(~heldStepIdx, ~heldTrack, valueRow);
        var curVal, curPos, numValid;

        ~grid.clear;

        ~grid.led(~heldStepIdx, ~heldTrack, GridInterface.ledFull);

        8.do { |row|
            if(row != ~heldTrack) {
                var paramIdx = ~paramIndexForRow.(row, ~heldTrack);
                if(paramIdx.notNil && (paramIdx < numParams)) {
                    var brightness;
                    if(paramIdx == 0 && (if(~subStepEditing) { ~subStepParamPage } { ~paramPage } == 0)) {
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

        if(~subStepEditing && ~subStepEditIdx.notNil) {
            var effectivePage = ~subStepParamPage;
            var effectiveParamNames = if(effectivePage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 };
            if(~selectedParam == 0 && (effectivePage == 0)) {
                curVal = ~resolveSubStepParam.(step, ~subStepEditIdx, \sample);
                curPos = curVal.asInteger;
                numValid = ~numValidPositions.(0, 0, ~heldTrack, ~heldStepIdx);
            } {
                var resolvedVal = ~resolveSubStepParam.(step, ~subStepEditIdx, effectiveParamNames[~selectedParam]);
                curVal = resolvedVal;
                curPos = ~positionForValue.(effectivePage, ~selectedParam, curVal);
                numValid = ~numValidPositions.(effectivePage, ~selectedParam, ~heldTrack, ~heldStepIdx);
            };
        } {
            if(~selectedParam == 0 && (~paramPage == 0)) {
                curVal = step[\sample];
                curPos = curVal.asInteger;
                numValid = ~numValidPositions.(0, 0, ~heldTrack, ~heldStepIdx);
            } {
                curVal = step[paramNames[~selectedParam]];
                curPos = ~positionForValue.(~paramPage, ~selectedParam, curVal);
                numValid = ~numValidPositions.(~paramPage, ~selectedParam, ~heldTrack, ~heldStepIdx);
            };
        };

        16.do { |col|
            if(col != ~heldStepIdx) {
                // Skip grid cells to avoid visual collision
                if((layout[\actionCols].includes(col) || layout[\subCols].includes(col)) && layout[\actionRows].includes(valueRow)) {
                } {
                    var valIdx = if(col < ~heldStepIdx) { col } { col - 1 };
                    if(valIdx < numValid) {
                        var centerPos = ~paramCenterPos.(if(~subStepEditing) { ~subStepParamPage } { ~paramPage }, ~selectedParam);
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

        ~grid.led(layout[\pageCol], layout[\pageRow], {
            var ep = if(~subStepEditing) { ~subStepParamPage } { ~paramPage };
            if(ep == 1) { GridInterface.ledFull } { GridInterface.ledMedium }
        }.value);
        ~grid.led(layout[\copyCol], layout[\copyRow], {
            if(~clipboard.isNil) { GridInterface.ledDim } {
                var step = if(~subStepEditing) {
                    ~tracks[~heldTrack][\steps][~heldStepIdx][\subSteps][~subStepEditIdx]
                } {
                    ~tracks[~heldTrack][\steps][~heldStepIdx]
                };
                if(~clipboardMatchesStep.(step)) { GridInterface.ledBright } { 6 }
            }
        }.value);
        ~grid.led(layout[\auditionCol], layout[\auditionRow],
            if(~auditionEnabled) { GridInterface.ledFull } { GridInterface.ledDim });
        ~grid.led(layout[\latchCol], layout[\latchRow],
            if(~latchActive) { pulseBright } { GridInterface.ledDim });

        {
            var subCols = layout[\subCols];
            var subRows = layout[\subRows];
            var subLen, playheadSub;

            subLen = 1;
            step[\subActive].do { |active, i| if(active) { subLen = i + 1 } };

            playheadSub = if(step[\subIdx] > 0) {
                (step[\subIdx] - 1) % subLen
            } { 0 };

            3.do { |ri|
                3.do { |ci|
                    var pos = ri * 3 + ci;
                    var brightness;
                    if(pos < subLen) {
                        if(~subStepEditing && (pos == ~subStepEditIdx)) {
                            brightness = pulseBright;
                        } {
                            if(playheadSub.notNil && (pos == playheadSub)) {
                                brightness = GridInterface.ledFull;
                            } {
                                if(step[\subActive][pos]) {
                                    brightness = GridInterface.ledMedium;
                                } {
                                    brightness = GridInterface.ledDim;
                                };
                            };
                        };
                    } {
                        brightness = GridInterface.ledDim;
                    };
                    ~grid.led(subCols[ci], subRows[ri], brightness);
                };
            };
        }.value;

    } {
        if(~lfoModActive && ~lfoModTrack.notNil) {
            var ms = ~trackModSettings[~lfoModTrack];
            var lfoHz = ~lfoRateHz.(ms[\rate16ths]);
            var animPhase = ((Main.elapsedTime * lfoHz % 1.0) * 16).asInteger;
            var shapeAnim, range, lfoVal;

            ~grid.clear;

            range = GridInterface.ledFull - GridInterface.ledDim;
            lfoVal = ~lfoBus.getSynchronous(~lfoModTrack);


            // Shape animation brightness per shape (freeze when held)
            shapeAnim = if(~lfoHoldActive) { GridInterface.ledFull } { case
                { ms[\shape] == 0 } {
                    // Sine: smooth pulse
                    if(animPhase < 8) {
                        GridInterface.ledDim + ((animPhase / 7) * range).round.asInteger
                    } {
                        GridInterface.ledFull - (((animPhase - 8) / 7) * range).round.asInteger
                    }
                }
                { ms[\shape] == 1 } {
                    // Square
                    if(animPhase < 8) { GridInterface.ledFull } { GridInterface.ledDim }
                }
                { ms[\shape] == 2 } {
                    // Triangle
                    if(animPhase < 8) {
                        GridInterface.ledDim + ((animPhase / 7) * range).round.asInteger
                    } {
                        GridInterface.ledFull - (((animPhase - 8) / 7) * range).round.asInteger
                    }
                }
                { ms[\shape] == 3 } {
                    // Brownian: smoothed random
                    (GridInterface.ledDim + (range * (animPhase.hash % 100 / 100))).round.asInteger
                }
                { ms[\shape] == 4 } {
                    // Random
                    (GridInterface.ledDim + (range * (animPhase.hash % 100 / 100))).round.asInteger
                }
                { ms[\shape] == 5 } {
                    // Saw up
                    (GridInterface.ledDim + (animPhase / 15 * range)).round.asInteger
                }
                { ms[\shape] == 6 } {
                    // Saw down
                    (GridInterface.ledFull - (animPhase / 15 * range)).round.asInteger
                }
                { true } { GridInterface.ledDim } };

            // Col 0: Shape selector
            7.do { |row|
                var brightness = if(row == ms[\shape]) { shapeAnim } { GridInterface.ledDim };
                ~grid.led(0, row, brightness);
            };

            // Col 1: Rate nudge
            7.do { |row|
                var brightness = if(row == 3) { GridInterface.ledBright } { GridInterface.ledDim };
                ~grid.led(1, row, brightness);
            };

            // Cols 2-15: Depth faders — single LED shows LFO position
            14.do { |destIdx|
                var col = destIdx + 2;
                var depth = ms[\depths][destIdx];
                var depthRow = ~modRowForDepth.(depth);
                if(depth > 0) {
                    var polarity = ms[\polarities][destIdx];
                    var span = (6 - depthRow).max(1);
                    var t = ((lfoVal * polarity).max(0) * depth).clip(0, 1);
                    var posRow = (6.0 - (t * span)).round.asInteger.clip(depthRow, 6);
                    7.do { |row|
                        var brightness;
                        if(row == depthRow) {
                            // Peak: absorbs position LED when it arrives
                            brightness = if(posRow == depthRow) {
                                GridInterface.ledFull
                            } { GridInterface.ledBright };
                        } {
                            brightness = if(row == posRow) {
                                GridInterface.ledMedium
                            } { GridInterface.ledDim };
                        };
                        ~grid.led(col, row, brightness);
                    };
                } {
                    7.do { |row|
                        var brightness = if(row == 6) { GridInterface.ledFull } { GridInterface.ledDim };
                        ~grid.led(col, row, brightness);
                    };
                };
            };

            // Row 7: Exit key (col 0) - pulsing (frozen when held)
            ~grid.led(0, 7, if(~lfoHoldActive) { GridInterface.ledMedium } { pulseBright });

            // Row 7: Hold key (col 1) — off until engaged
            ~grid.led(1, 7, if(~lfoHoldActive) { GridInterface.ledFull } { GridInterface.ledOff });

            // Row 7, cols 2-15: Polarity toggles (frozen when held)
            14.do { |destIdx|
                var col = destIdx + 2;
                var pol = ms[\polarities][destIdx];
                var brightness = if(pol > 0) { GridInterface.ledFull } {
                    if(~lfoHoldActive) { GridInterface.ledMedium } { pulseBright }
                };
                ~grid.led(col, 7, brightness);
            };
        } {
        if(~trackParamActive && ~trackParamCol.notNil && ~trackParamTrack.notNil) {
            var paramNames = ~currentParamNames.();
            var numParams = paramNames.size;
            var valueRow = ~selectedParam;
            var layout = ~overlayLayout.(~trackParamCol, -1, valueRow);

            ~grid.clear;

            // Held button
            ~grid.led(~trackParamCol, 7, GridInterface.ledFull);

            // Param selector column
            7.do { |row|
                if(row < numParams) {
                    var brightness;
                    if(row == 0 && (~paramPage == 0)) {
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

            // Value row with collision avoidance
            if(~selectedParam == 0 && (~paramPage == 0)) {
                var firstVal = ~tracks[~trackParamTrack][\steps][0][\sample];
                var unanimous = ~tracks[~trackParamTrack][\steps].every { |step| step[\sample] == firstVal };
                var curPos = if(unanimous) { firstVal.asInteger } { nil };
                var numValid = ~numValidPositions.(0, 0, ~trackParamTrack, 0);

                16.do { |col|
                    if(col != ~trackParamCol) {
                        if((layout[\actionCols].includes(col) || layout[\subCols].includes(col)) && layout[\actionRows].includes(valueRow)) {
                        } {
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
                };
            } {
                var curVal = ~tracks[~trackParamTrack][\steps][0][paramNames[~selectedParam]];
                var unanimous = ~tracks[~trackParamTrack][\steps].every { |step| step[paramNames[~selectedParam]] == curVal };
                var curPos = if(unanimous) { ~positionForValue.(~paramPage, ~selectedParam, curVal) } { nil };
                var numValid = ~numValidPositions.(~paramPage, ~selectedParam, ~trackParamTrack, 0);
                var centerPos = ~paramCenterPos.(~paramPage, ~selectedParam);

                16.do { |col|
                    if(col != ~trackParamCol) {
                        if((layout[\actionCols].includes(col) || layout[\subCols].includes(col)) && layout[\actionRows].includes(valueRow)) {
                        } {
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
            };

            // Action grid LEDs
            ~grid.led(layout[\pageCol], layout[\pageRow],
                if(~paramPage == 1) { GridInterface.ledFull } { GridInterface.ledMedium });
            ~grid.led(layout[\copyCol], layout[\copyRow], GridInterface.ledDim);  // Slice stub
            ~grid.led(layout[\auditionCol], layout[\auditionRow],
                if(~auditionEnabled) { GridInterface.ledFull } { GridInterface.ledDim });
            ~grid.led(layout[\latchCol], layout[\latchRow],
                if(~latchActive) { pulseBright } { GridInterface.ledDim });
            ~grid.led(layout[\actionCols][1], layout[\actionRows][1],
                if(~trackHasModulation.(~trackParamTrack)) { GridInterface.ledMedium } { GridInterface.ledDim });

            // Clear LED (phantom sub grid center)
            ~grid.led(layout[\subCols][1], layout[\subRows][1],
                if(~trackClearArmed) { pulseBright } { GridInterface.ledDim });

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
                    ~grid.led(~utilityHeldButton, 7, GridInterface.ledFull);
                    ~grid.led(~utilityHeldButton + 1, 7, if(~latchActive) { pulseBright } { GridInterface.ledDim });
                } {
                    if(~utilityOverlayType == \fxMatrix) {
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
                        ~grid.led(~utilityHeldButton, 7, GridInterface.ledFull);
                        ~grid.led(~utilityHeldButton + 1, 7, if(~latchActive) { pulseBright } { GridInterface.ledDim });
                    } {
                        if(~utilityOverlayType == \transpose) {
                            var transposeValues = [0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0];
                            transposeValues.do { |val, i|
                                var brightness = if(val == ~transpose) {
                                    GridInterface.ledFull
                                } {
                                    GridInterface.ledDim
                                };
                                ~grid.led(4, i, brightness);
                            };
                            ~grid.led(~utilityHeldButton, 7, GridInterface.ledFull);
                            ~grid.led(~utilityHeldButton + 1, 7, if(~latchActive) { pulseBright } { GridInterface.ledDim });
                        } {
                            if(~utilityOverlayType == \preset) {
                                7.do { |row|
                                    7.do { |col|
                                        var slotIdx = row * 7 + col;
                                        var brightness = if(~presets[slotIdx].notNil) {
                                            if(slotIdx == ~presetSelectedSlot) {
                                                GridInterface.ledFull
                                            } {
                                                GridInterface.ledMedium
                                            }
                                        } {
                                            if(slotIdx == ~presetSelectedSlot) {
                                                GridInterface.ledMedium
                                            } {
                                                GridInterface.ledDim
                                            }
                                        };
                                        ~grid.led(col, row, brightness);
                                    };
                                };
                                ~grid.led(8, 0, if(~presetConfirmArmed == \save) { pulseBright } { GridInterface.ledDim });
                                ~grid.led(8, 2, if(~presetConfirmArmed == \clear) { pulseBright } { GridInterface.ledDim });
                                ~grid.led(8, 4, if(~presetConfirmMode) { GridInterface.ledFull } { GridInterface.ledDim });
                                ~grid.led(8, 6, if(~presetQuantized) { GridInterface.ledFull } { GridInterface.ledDim });
                                if(~utilityHeldButton.notNil) {
                                    ~grid.led(~utilityHeldButton, 7, GridInterface.ledFull);
                                    ~grid.led(~utilityHeldButton + 1, 7, if(~latchActive) { pulseBright } { GridInterface.ledDim });
                                };
                            };
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
                    16.do { |col|
                        ~grid.led(col, row, GridInterface.ledDim);
                    };
                    ~grid.led(startS, row, GridInterface.ledFull);
                } {
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
            if(~transportHeld) {
                ~grid.clear;

                // Transport indicator
                ~grid.led(0, 7, GridInterface.ledFull);

                // Col 0: tempo nudge
                7.do { |row|
                    var brightness = if(row == 3) { GridInterface.ledBright } { GridInterface.ledDim };
                    ~grid.led(0, row, brightness);
                };

                // Col 1: swing nudge
                7.do { |row|
                    var brightness = if(row == 3) { GridInterface.ledBright } { GridInterface.ledDim };
                    ~grid.led(1, row, brightness);
                };

                // Stereo meters (cols 7-8)
                2.do { |ch|
                    var col = 7 + ch;
                    var level = ~meterLevel[ch];
                    var segments = level * 8;
                    var fullSegs = segments.floor.asInteger;
                    var frac = segments - fullSegs;

                    fullSegs.do { |i|
                        ~grid.led(col, 7 - i, GridInterface.ledFull);
                    };
                    if(fullSegs < 8) {
                        if(frac > 0.05) {
                            ~grid.led(col, 7 - fullSegs, (frac * GridInterface.ledFull).round.asInteger);
                        };
                    };
                };

                // Latch key
                ~grid.led(1, 7, if(~latchActive) { pulseBright } { GridInterface.ledDim });
                // Kill FX tails
                ~grid.led(2, 7, GridInterface.ledDim);

                // Mixer faders (cols 9-15, tracks 0-6)
                7.do { |trackIdx|
                    var col = 9 + trackIdx;
                    var curRow = ~mixerPosForVolume.(~trackVolumes[trackIdx]);
                    8.do { |row|
                        var brightness = if(row == curRow) { GridInterface.ledFull }
                            { if(row > curRow) { GridInterface.ledMedium } { GridInterface.ledDim } };
                        ~grid.led(col, row, brightness);
                    };
                };
            } {
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

                ~grid.led(0, 7, if(~playing) { GridInterface.ledFull } { GridInterface.ledDim });
                ~grid.led(1, 7, GridInterface.ledDim);
                ~grid.led(2, 7, if(~fxHasNonDefault.()) { GridInterface.ledFull } { GridInterface.ledDim });
                ~grid.led(3, 7, if(~globalReverse) { GridInterface.ledFull } { GridInterface.ledDim });
                ~grid.led(4, 7, if(~transpose != 1.0) { GridInterface.ledFull } { GridInterface.ledDim });
                4.do { |i|
                    var mappedSlot = ~presetSlotMap[i];
                    var brightness;
                    if(~pendingPresetRecall.notNil && (~pendingPresetButton == i)) {
                        brightness = pulseBright;
                    } {
                        if(~presets[mappedSlot].notNil) {
                            brightness = if(~activePresetButton == i) {
                                GridInterface.ledFull
                            } {
                                GridInterface.ledMedium
                            };
                        } {
                            brightness = GridInterface.ledOff;
                        };
                    };
                    ~grid.led(5 + i, 7, brightness);
                };
                ~numTracks.do { |i|
                    ~grid.led(9 + i, 7, if(~tracks[i][\muted]) { GridInterface.ledFull } { GridInterface.ledDim });
                };
            };
            };
        };
        };
        };
    };
    };  // close if(~fineActive) else
};

"[Gladiola] grid_leds.scd loaded.".postln;
)

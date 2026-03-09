(
~heldTrack = nil;
~heldStepIdx = nil;
~paramMenuActive = false;
~selectedParam = 0;
~pendingToggle = nil;
~pendingToggleTrack = nil;
~lengthModalTrack = nil;
~lengthModalMode = nil;
~utilityOverlayActive = false;
~utilityOverlayType = nil;
~utilityHeldButton = nil;
~presetHeldSlot = nil;
~presetHeldX = nil;
~clipboard = nil;
~trackParamActive = false;
~trackParamCol = nil;
~trackParamTrack = nil;
~reverseHeld = false;
~prevTranspose = nil;
~transportHeld = false;
~transportPressTime = nil;
~auditionEnabled = true;
~presetConfirmArmed = nil;
~presetFlashState = false;
~presetPulsePhase = 0;
~subStepEditing = false;
~subStepEditIdx = nil;
~anchorPressTime = nil;


~subStepParamPage = 0;
~savedParamPage = nil;
~savedSelectedParam = nil;
~pendingSubToggle = nil;
~latchActive = false;
~pulseRoutine = nil;
~lastOverlayCloseTime = nil;
~trackClearArmed = false;
~lfoModActive = false;
~lfoModTrack = nil;
~lfoHoldActive = false;

~startPulseRoutine = {
    if(~pulseRoutine.isNil) {
        ~pulseRoutine = Routine({
            loop {
                0.033.wait;
                { ~updateGridLEDs.() }.defer;
            };
        }).play(AppClock);
    };
};

~stopPulseRoutine = {
    if(~pulseRoutine.notNil) {
        ~pulseRoutine.stop;
        ~pulseRoutine = nil;
    };
};

~paramRowForIndex = { |paramIdx, heldTrack|
    var row = if(paramIdx < heldTrack) { paramIdx } { paramIdx + 1 };
    row
};

~paramIndexForRow = { |row, heldTrack|
    if(row == heldTrack) { nil } {
        if(row < heldTrack) { row } {
            if(row <= 6) { row - 1 } {
                if(row == 7) { 6 } { nil }
            }
        }
    }
};

~overlayLayout = { |heldStepIdx, heldTrack, valueRow|
    var subCols, actionCols, rows;
    var allBlocks, valid, bestBlock, bestScore;

    // Columns: two 3-col groups side by side on far side from param column
    if(heldStepIdx < 8) {
        subCols = [13,14,15];
        actionCols = [9,10,11];
    } {
        subCols = [0,1,2];
        actionCols = [4,5,6];
    };

    // Rows: single 3-row block shared by both grids, maximise gap from valueRow
    // heldTrack is NOT considered occupied — param selector skips that row
    allBlocks = [[0,1,2],[1,2,3],[2,3,4],[3,4,5],[4,5,6],[5,6,7]];
    valid = allBlocks.select { |block|
        block.includes(valueRow).not
    };

    bestBlock = valid[0];
    bestScore = -1;
    {   var bestSum = -1;
        valid.do { |block|
            var minDist = 99, sumDist = 0;
            block.do { |r|
                var rd = (r - valueRow).abs;
                if(rd < minDist) { minDist = rd };
                sumDist = sumDist + rd;
            };
            if((minDist > bestScore) || ((minDist == bestScore) && (sumDist > bestSum))) {
                bestScore = minDist;
                bestSum = sumDist;
                bestBlock = block;
            };
        };
    }.value;

    rows = bestBlock;

    // Post-placement fix: try nudging ±1 or ±2 to maximise gap from valueRow
    {
        var minGap = rows.collect { |r| (r - valueRow).abs }.minItem;
        if(minGap < 2) {
            var bestRows = rows, bestGap = minGap;
            [-2, -1, 1, 2].do { |offset|
                var candidate = rows.collect { |r| r + offset };
                if((candidate[0] >= 0) && (candidate[2] <= 7) && candidate.includes(valueRow).not) {
                    var gap = candidate.collect { |r| (r - valueRow).abs }.minItem;
                    if(gap > bestGap) { bestGap = gap; bestRows = candidate };
                };
            };
            if(bestRows != rows) {
                "[Layout DBG] NUDGE: % -> % (gap % -> %)".format(rows, bestRows, minGap, bestGap).postln;
                rows = bestRows;
            };
        };
    }.value;

    "[Layout DBG] step=% track=% vRow=% -> rows=% subCols=% actCols=%".format(heldStepIdx, heldTrack, valueRow, rows, subCols, actionCols).postln;

    Dictionary[
        \subCols -> subCols, \subRows -> rows,
        \actionCols -> actionCols, \actionRows -> rows,
        \pageCol -> actionCols[0], \pageRow -> rows[0],
        \copyCol -> actionCols[2], \copyRow -> rows[0],
        \auditionCol -> actionCols[0], \auditionRow -> rows[2],
        \latchCol -> actionCols[2], \latchRow -> rows[2]
    ]
};

~valueIdxForCol = { |col, heldCol|
    if(col == heldCol) { nil } {
        if(col < heldCol) { col } { col - 1 }
    }
};

~subIdxFromGrid = { |x, y, subPos|
    var result = nil;
    subPos[0].do { |c, ci|
        subPos[1].do { |r, ri|
            if(x == c && (y == r)) { result = ri * 3 + ci };
        };
    };
    result
};

~initGridHandler = {

    ~grid.key({ |x, y, state|
        if(state == 1) {
            if(~lengthModalTrack.notNil) {
                if(y == ~lengthModalTrack) {
                    if(~lengthModalMode == \setEnd) {
                        ~setTrackEnd.(~lengthModalTrack, x);
                    } {
                        ~setTrackStart.(~lengthModalTrack, x);
                    };
                    ~lengthModalTrack = nil;
                    ~lengthModalMode = nil;
                    ~updateGridLEDs.();
                } {
                    ~lengthModalTrack = nil;
                    ~lengthModalMode = nil;
                    ~updateGridLEDs.();
                };
            } {
                if(~transportHeld) {
                    if(x == 0 && (y < 7)) {
                        if(y == 3) {
                            ~anchorPressTime = Main.elapsedTime;
                            AppClock.sched(0.5, {
                                if(~anchorPressTime.notNil) {
                                    ~anchorTempo = ~bpm;
                                    ~anchorPressTime = nil;
                                    "[Gladiola] Anchor tempo set to % BPM".format(~bpm).postln;
                                    { ~updateGridLEDs.() }.defer;
                                };
                                nil;
                            });
                        } {
                            var nudges = [10, 5, 1, nil, -1, -5, -10];
                            var nudge = nudges[y];
                            if(nudge.notNil) {
                                ~setTempo.(~bpm + nudge);
                            };
                        };
                        ~updateGridLEDs.();
                    };
                    if(x == 1 && (y < 7)) {
                        if(y == 3) {
                            ~setSwing.(50);
                        } {
                            var nudges = [10, 5, 1, nil, -1, -5, -10];
                            var nudge = nudges[y];
                            if(nudge.notNil) {
                                ~setSwing.(~swing + nudge);
                            };
                        };
                        ~updateGridLEDs.();
                    };
                    if(x == 2 && (y == 7)) {
                        ~killFxTails.();
                        "[Gladiola] FX tails killed".postln;
                        ~updateGridLEDs.();
                    };
                    if(x == 1 && (y == 7)) {
                        if(~latchActive) {
                            ~latchActive = false;
                            ~transportHeld = false;
                            ~stopPulseRoutine.();
                            ~updateGridLEDs.();
                        } {
                            ~latchActive = true;
                            ~updateGridLEDs.();
                        };
                    };
                    if(x >= 9 && (x <= 15)) {
                        var trackIdx = x - 9;
                        ~setTrackVolume.(trackIdx, ~mixerVolumes[y]);
                        ~updateGridLEDs.();
                    };
                } {
                if(~utilityOverlayActive) {
                    if(x == (~utilityHeldButton + 1) && (y == 7)) {
                        if(~latchActive) {
                            ~latchActive = false;
                            ~stopPulseRoutine.();
                            if(~utilityOverlayType == \preset) {
                                var btnIdx = ~utilityHeldButton - 5;
                                if(~presetSelectedSlot.notNil) {
                                    ~presetSlotMap[btnIdx] = ~presetSelectedSlot;
                                };
                            };
                            ~utilityOverlayActive = false;
                            ~utilityOverlayType = nil;
                            ~utilityHeldButton = nil;
                            ~presetConfirmArmed = nil;
                            ~updateGridLEDs.();
                        } {
                            ~latchActive = true;
                            ~startPulseRoutine.();
                            ~updateGridLEDs.();
                        };
                    };
                    if(~utilityOverlayType == \clockDiv) {
                        if(x < 7 && (y < 7)) {
                            var divValues = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0];
                            var div = divValues[x];
                            "[Gladiola] Clock div overlay tap: col %, row % -> track % div %".format(x, y, y, div).postln;
                            ~setTrackClockDiv.(y, div);
                            ~updateGridLEDs.();
                        };
                    } {
                        if(~utilityOverlayType == \fxMatrix) {
                            if(x < 16 && (y < 7)) {
                                var key = ~fxParamKeys[x];
                                var value = ~fxValueForPosition.(x, y);
                                ~setFxParam.(key, value);
                                "[Gladiola] FX: % -> %".format(key, value).postln;
                                ~updateGridLEDs.();
                            };
                        } {
                            if(~utilityOverlayType == \transpose) {
                                if(x == 4 && (y < 7)) {
                                    var transposeValues = [0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0];
                                    ~prevTranspose = ~transpose;
                                    ~transpose = transposeValues[y];
                                    "[Gladiola] Transpose -> %".format(~transpose).postln;
                                    ~updateGridLEDs.();
                                };
                            } {
                                if(~utilityOverlayType == \preset) {
                                    if(x < 7 && (y < 7)) {
                                        var slotIdx = y * 7 + x;
                                        ~presetSelectedSlot = slotIdx;
                                        ~presetConfirmArmed = nil;
                                        "[Gladiola] Preset slot selected: %".format(slotIdx).postln;
                                        ~updateGridLEDs.();
                                    };
                                    if(x == 8) {
                                        if(y == 0) {
                                            if(~presetSelectedSlot.notNil) {
                                                if(~presetConfirmMode && ~presets[~presetSelectedSlot].notNil) {
                                                    if(~presetConfirmArmed == \save) {
                                                        ~savePreset.(~presetSelectedSlot);
                                                        ~presetConfirmArmed = nil;
                                                        "[Gladiola] Preset % saved (confirmed).".format(~presetSelectedSlot).postln;
                                                    } {
                                                        ~presetConfirmArmed = \save;
                                                        "[Gladiola] Preset % save armed — tap again to confirm.".format(~presetSelectedSlot).postln;
                                                    };
                                                } {
                                                    ~savePreset.(~presetSelectedSlot);
                                                    ~presetConfirmArmed = nil;
                                                    "[Gladiola] Preset % saved.".format(~presetSelectedSlot).postln;
                                                };
                                                ~updateGridLEDs.();
                                            };
                                        };
                                        if(y == 2) {
                                            if(~presetSelectedSlot.notNil) {
                                                if(~presetConfirmMode && ~presets[~presetSelectedSlot].notNil) {
                                                    if(~presetConfirmArmed == \clear) {
                                                        ~clearPreset.(~presetSelectedSlot);
                                                        ~presetConfirmArmed = nil;
                                                        if(~activePresetButton.notNil && (~presetSlotMap[~activePresetButton] == ~presetSelectedSlot)) {
                                                            ~activePresetButton = nil;
                                                        };
                                                        "[Gladiola] Preset % cleared (confirmed).".format(~presetSelectedSlot).postln;
                                                    } {
                                                        ~presetConfirmArmed = \clear;
                                                        "[Gladiola] Preset % clear armed — tap again to confirm.".format(~presetSelectedSlot).postln;
                                                    };
                                                } {
                                                    ~clearPreset.(~presetSelectedSlot);
                                                    ~presetConfirmArmed = nil;
                                                    if(~activePresetButton.notNil && (~presetSlotMap[~activePresetButton] == ~presetSelectedSlot)) {
                                                        ~activePresetButton = nil;
                                                    };
                                                };
                                                ~updateGridLEDs.();
                                            };
                                        };
                                        if(y == 4) {
                                            ~presetConfirmMode = ~presetConfirmMode.not;
                                            "[Gladiola] Preset confirm mode -> %".format(~presetConfirmMode).postln;
                                            ~updateGridLEDs.();
                                        };
                                        if(y == 6) {
                                            ~presetQuantized = ~presetQuantized.not;
                                            "[Gladiola] Preset quantize -> %".format(~presetQuantized).postln;
                                            ~updateGridLEDs.();
                                        };
                                    };
                                };
                            };
                        };
                    };
                } {
                    if(~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil) {
                        var effectivePage = if(~subStepEditing) { ~subStepParamPage } { ~paramPage };
                        var paramNames = if(effectivePage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 };
                        var step = ~tracks[~heldTrack][\steps][~heldStepIdx];
                        var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
                        var layout = ~overlayLayout.(~heldStepIdx, ~heldTrack, valueRow);
                        var subIdx = ~subIdxFromGrid.(x, y, [layout[\subCols], layout[\subRows]]);

                        if(subIdx.notNil) {
                            if(~subStepEditing && (subIdx == ~subStepEditIdx)) {
                                ~subStepEditing = false;
                                ~subStepEditIdx = nil;
                                if(~latchActive.not) { ~stopPulseRoutine.() };
                                ~paramPage = ~savedParamPage ? 0;
                                ~selectedParam = ~savedSelectedParam ? 0;
                                ~savedParamPage = nil;
                                ~savedSelectedParam = nil;
                                "[Gladiola] Sub-step editing exited".postln;
                            } {
                                if(~subStepEditing.not) {
                                    if(subIdx != 0) {
                                        ~pendingSubToggle = subIdx;
                                    };
                                };
                            };
                            ~updateGridLEDs.();
                        } {
                        if(x == layout[\auditionCol] && (y == layout[\auditionRow])) {
                            ~auditionEnabled = ~auditionEnabled.not;
                            "[Gladiola] Audition -> %".format(~auditionEnabled).postln;
                            if(~auditionEnabled && ~playing.not) {
                                ~previewStep.(~heldTrack, ~heldStepIdx);
                            };
                            ~updateGridLEDs.();
                        } {
                        if(x == layout[\pageCol] && (y == layout[\pageRow])) {
                            if(~subStepEditing) {
                                ~subStepParamPage = 1 - ~subStepParamPage;
                                "[Gladiola] Sub-step param page -> %".format(~subStepParamPage).postln;
                            } {
                                ~paramPage = 1 - ~paramPage;
                                "[Gladiola] Param page -> %".format(~paramPage).postln;
                            };
                            ~selectedParam = 0;
                            ~updateGridLEDs.();
                        } {
                        if(x == layout[\copyCol] && (y == layout[\copyRow])) {
                            ~clipboard = ~deepCopyStep.(step);
                            ~clipboard.removeAt(\on);
                            "[Gladiola] Copied step params from track % step %".format(~heldTrack, ~heldStepIdx).postln;
                            ~updateGridLEDs.();
                        } {
                        if(x == layout[\latchCol] && (y == layout[\latchRow])) {
                            if(~latchActive) {
                                ~latchActive = false;
                                ~stopPulseRoutine.();
                                ~paramMenuActive = false;
                                ~heldTrack = nil;
                                ~heldStepIdx = nil;
                                ~auditionEnabled = true;
                                ~subStepEditing = false;
                                ~subStepEditIdx = nil;
                                ~pendingSubToggle = nil;
                                ~savedParamPage = nil;
                                ~savedSelectedParam = nil;
                                "[Gladiola] Latch disengaged, overlay closed".postln;
                                ~updateGridLEDs.();
                            } {
                                ~latchActive = true;
                                ~startPulseRoutine.();
                                "[Gladiola] Latch engaged".postln;
                                ~updateGridLEDs.();
                            };
                        } {
                            if(x == ~heldStepIdx && (y != ~heldTrack)) {
                                var paramIdx = ~paramIndexForRow.(y, ~heldTrack);
                                if(paramIdx.notNil && (paramIdx < paramNames.size)) {
                                    if(paramIdx == 0 && (~selectedParam == 0) && (effectivePage == 0)) {
                                        var numBanks = (~numBanks ? 1).max(1);
                                        var target = if(~subStepEditing && ~subStepEditIdx.notNil) {
                                            if(step[\subSteps][~subStepEditIdx].isNil) { step[\subSteps][~subStepEditIdx] = Dictionary.new };
                                            step[\subSteps][~subStepEditIdx]
                                        } { step };
                                        var curBank = target[\bank] ?? { step[\bank] };
                                        var newBank = (curBank + 1) % numBanks;
                                        target[\bank] = newBank;
                                        target[\sample] = 0;
                                        "[Gladiola] Track % step %: bank -> %".format(~heldTrack, ~heldStepIdx, newBank).postln;
                                    } {
                                        ~selectedParam = paramIdx;
                                        "[Gladiola] Param -> %".format(paramNames[paramIdx]).postln;
                                    };
                                    ~updateGridLEDs.();
                                };
                            } {
                                var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
                                if(y == valueRow && (x != ~heldStepIdx)) {
                                    var valIdx = ~valueIdxForCol.(x, ~heldStepIdx);
                                    if(valIdx.notNil) {
                                        var numValid = ~numValidPositions.(effectivePage, ~selectedParam, ~heldTrack, ~heldStepIdx);
                                        if(valIdx < numValid) {
                                            if(~subStepEditing && ~subStepEditIdx.notNil) {
                                                if(step[\subSteps][~subStepEditIdx].isNil) { step[\subSteps][~subStepEditIdx] = Dictionary.new };
                                                if(~selectedParam == 0 && (effectivePage == 0)) {
                                                    step[\subSteps][~subStepEditIdx][\sample] = valIdx;
                                                    "[Gladiola] Sub-step %: sample -> %".format(~subStepEditIdx, valIdx).postln;
                                                } {
                                                    var val = ~valueForPosition.(effectivePage, ~selectedParam, valIdx);
                                                    step[\subSteps][~subStepEditIdx][paramNames[~selectedParam]] = val;
                                                    "[Gladiola] Sub-step %: % -> %".format(~subStepEditIdx, paramNames[~selectedParam], val).postln;
                                                };
                                            } {
                                                if(~selectedParam == 0 && (effectivePage == 0)) {
                                                    step[\sample] = valIdx;
                                                    "[Gladiola] Track % step %: sample -> %".format(~heldTrack, ~heldStepIdx, valIdx).postln;
                                                } {
                                                    var val = ~valueForPosition.(effectivePage, ~selectedParam, valIdx);
                                                    step[paramNames[~selectedParam]] = val;
                                                    "[Gladiola] Track % step %: % -> %".format(~heldTrack, ~heldStepIdx, paramNames[~selectedParam], val).postln;
                                                };
                                            };
                                            if(~auditionEnabled && ~playing.not) {
                                                ~previewStep.(~heldTrack, ~heldStepIdx);
                                            };
                                            ~updateGridLEDs.();
                                        };
                                    };
                                };
                            };
                        };
                        };
                        };
                        };
                        };
                    } {
                        if(~lfoModActive && ~lfoModTrack.notNil) {
                            var ms = ~trackModSettings[~lfoModTrack];
                            if(x == 0 && (y < 7)) {
                                // Shape selector
                                ~setModShape.(~lfoModTrack, y);
                                "[Gladiola] LFO shape -> %".format(~modShapeNames[y]).postln;
                                ~updateGridLEDs.();
                            };
                            if(x == 1 && (y < 7)) {
                                // Rate nudge
                                if(y != 3) {
                                    var nudge = ~modRateNudges[y];
                                    var cur = ms[\rate16ths];
                                    var newRate;
                                    if(cur == 1 && (nudge == 16)) {
                                        newRate = 16;
                                    } {
                                        newRate = (cur + nudge).clip(1, 128);
                                    };
                                    ~setModRate.(~lfoModTrack, newRate);
                                    "[Gladiola] LFO rate -> % sixteenths".format(ms[\rate16ths]).postln;
                                    ~updateGridLEDs.();
                                };
                            };
                            if(x >= 2 && (x <= 15) && (y < 7)) {
                                // Depth fader
                                var destIdx = x - 2;
                                var depth = ~modDepthForRow.(y);
                                var polarity = ms[\polarities][destIdx];
                                ~setModDepth.(~lfoModTrack, destIdx, depth, polarity);
                                "[Gladiola] LFO % depth -> %".format(~modDestKeys[destIdx], depth).postln;
                                ~updateGridLEDs.();
                            };
                            if(x >= 2 && (x <= 15) && (y == 7)) {
                                // Polarity toggle
                                var destIdx = x - 2;
                                var newPol = ms[\polarities][destIdx].neg;
                                ms[\polarities][destIdx] = newPol;
                                if(ms[\depths][destIdx] > 0) {
                                    ~setModDepth.(~lfoModTrack, destIdx, ms[\depths][destIdx], newPol);
                                };
                                "[Gladiola] LFO % polarity -> %".format(~modDestKeys[destIdx], if(newPol > 0) { "+" } { "-" }).postln;
                                ~updateGridLEDs.();
                            };
                            if(x == 0 && (y == 7)) {
                                // Exit — return to track overlay
                                ~lfoModActive = false;
                                ~lfoHoldActive = false;
                                ~trackParamActive = true;
                                ~trackParamCol = 9 + ~lfoModTrack;
                                ~trackParamTrack = ~lfoModTrack;
                                ~selectedParam = 0;
                                ~paramPage = 0;
                                // Keep latch active
                                "[Gladiola] LFO mod overlay closed, back to track overlay".postln;
                                ~updateGridLEDs.();
                            };
                            if(x == 1 && (y == 7)) {
                                // Hold (freeze) — press
                                ~lfoHoldActive = true;
                                if(~lfoSynths.notNil) { if(~lfoSynths[~lfoModTrack].notNil) {
                                    ~lfoSynths[~lfoModTrack].set(\freeze, 1)
                                } };
                                "[Gladiola] LFO hold engaged".postln;
                                ~updateGridLEDs.();
                            };
                        } {
                        if(~trackParamActive && ~trackParamCol.notNil && ~trackParamTrack.notNil) {
                            var paramNames = ~currentParamNames.();
                            var valueRow = ~selectedParam;
                            var layout = ~overlayLayout.(~trackParamCol, -1, valueRow);

                            // Disarm clear on any non-clear press
                            if(x != layout[\subCols][1] || (y != layout[\subRows][1])) {
                                if(~trackClearArmed) {
                                    ~trackClearArmed = false;
                                    "[Gladiola] Track clear disarmed".postln;
                                };
                            };

                            if(x == layout[\pageCol] && (y == layout[\pageRow])) {
                                // Page toggle
                                ~paramPage = 1 - ~paramPage;
                                ~selectedParam = 0;
                                "[Gladiola] Track param page -> %".format(~paramPage).postln;
                                ~updateGridLEDs.();
                            } {
                            if(x == layout[\copyCol] && (y == layout[\copyRow])) {
                                // Slice stub
                                "[Gladiola] Slice toggle (stub) for track %".format(~trackParamTrack).postln;
                                ~updateGridLEDs.();
                            } {
                            if(x == layout[\auditionCol] && (y == layout[\auditionRow])) {
                                // Audition toggle
                                ~auditionEnabled = ~auditionEnabled.not;
                                "[Gladiola] Audition -> %".format(~auditionEnabled).postln;
                                if(~auditionEnabled && ~playing.not) {
                                    ~previewStep.(~trackParamTrack, 0);
                                };
                                ~updateGridLEDs.();
                            } {
                            if(x == layout[\latchCol] && (y == layout[\latchRow])) {
                                // Latch toggle
                                if(~latchActive) {
                                    ~latchActive = false;
                                    ~stopPulseRoutine.();
                                    ~trackParamActive = false;
                                    ~trackParamCol = nil;
                                    ~trackParamTrack = nil;
                                    ~trackClearArmed = false;
                                    ~auditionEnabled = true;
                                    ~lastOverlayCloseTime = Main.elapsedTime;
                                    "[Gladiola] Track latch disengaged, overlay closed".postln;
                                } {
                                    ~latchActive = true;
                                    ~startPulseRoutine.();
                                    "[Gladiola] Track latch engaged".postln;
                                };
                                ~updateGridLEDs.();
                            } {
                            if(x == layout[\actionCols][1] && (y == layout[\actionRows][1])) {
                                // Enter LFO mod overlay
                                ~lfoModActive = true;
                                ~lfoModTrack = ~trackParamTrack;
                                ~trackParamActive = false;
                                ~trackParamCol = nil;
                                ~trackClearArmed = false;
                                ~latchActive = true;
                                ~startPulseRoutine.();
                                "[Gladiola] LFO mod overlay opened for track %".format(~lfoModTrack).postln;
                                ~updateGridLEDs.();
                            } {
                            if(x == layout[\subCols][1] && (y == layout[\subRows][1])) {
                                // Clear
                                if(~trackClearArmed) {
                                    ~tracks[~trackParamTrack][\steps] = Array.fill(~stepsPerTrack, {
                                        Dictionary.newFrom([
                                            \on, false, \bank, 0, \sample, 0, \pitch, 1.0,
                                            \velocity, 1.0, \loopLength, 0.0, \loopRegion, 0.0,
                                            \ratchet, 1, \attack, 0.002, \gateLength, 1.0,
                                            \reverse, false, \filter, 0.0, \pan, 0.0,
                                            \probability, 1.0, \delaySend, 0.0, \bitcrush, 0.0,
                                            \subSteps, Array.fill(9, { nil }),
                                            \subActive, Array.fill(9, { |i| i == 0 }),
                                            \subIdx, 0
                                        ])
                                    });
                                    ~trackClearArmed = false;
                                    "[Gladiola] Track % cleared".format(~trackParamTrack).postln;
                                } {
                                    ~trackClearArmed = true;
                                    "[Gladiola] Track % clear armed".format(~trackParamTrack).postln;
                                };
                                ~updateGridLEDs.();
                            } {
                            if(x == ~trackParamCol && (y < 7)) {
                                // Param selector
                                if(y < paramNames.size) {
                                    if(y == 0 && (~selectedParam == 0) && (~paramPage == 0)) {
                                        var numBanks = (~numBanks ? 1).max(1);
                                        var curBank = ~tracks[~trackParamTrack][\steps][0][\bank];
                                        var newBank = (curBank + 1) % numBanks;
                                        ~tracks[~trackParamTrack][\steps].do { |step|
                                            step[\bank] = newBank;
                                            step[\sample] = 0;
                                        };
                                        "[Gladiola] Track % all steps: bank -> %".format(~trackParamTrack, newBank).postln;
                                    } {
                                        ~selectedParam = y;
                                        "[Gladiola] Track param -> %".format(paramNames[y]).postln;
                                    };
                                    ~updateGridLEDs.();
                                };
                            } {
                            if(y == ~selectedParam && (x != ~trackParamCol)) {
                                // Value row — skip action/sub grid cells
                                if((layout[\actionCols].includes(x) || layout[\subCols].includes(x)) && layout[\actionRows].includes(y)) {
                                    // Skip — collision with action/sub grid
                                } {
                                    var valIdx = ~valueIdxForCol.(x, ~trackParamCol);
                                    if(valIdx.notNil) {
                                        var numValid = ~numValidPositions.(~paramPage, ~selectedParam, ~trackParamTrack, 0);
                                        if(valIdx < numValid) {
                                            if(~selectedParam == 0 && (~paramPage == 0)) {
                                                ~tracks[~trackParamTrack][\steps].do { |step|
                                                    step[\sample] = valIdx;
                                                };
                                                "[Gladiola] Track % all steps: sample -> %".format(~trackParamTrack, valIdx).postln;
                                            } {
                                                var val = ~valueForPosition.(~paramPage, ~selectedParam, valIdx);
                                                ~tracks[~trackParamTrack][\steps].do { |step|
                                                    step[paramNames[~selectedParam]] = val;
                                                };
                                                "[Gladiola] Track % all steps: % -> %".format(~trackParamTrack, paramNames[~selectedParam], val).postln;
                                            };
                                            if(~auditionEnabled && ~playing.not) {
                                                ~previewStep.(~trackParamTrack, 0);
                                            };
                                            ~updateGridLEDs.();
                                        };
                                    };
                                };
                            };
                            };
                            };
                            };
                            };
                            };
                            };
                            };
                        } {
                            if(y == 7) {
                                if(x == 0) {
                                    ~pendingToggle = 0;
                                    ~pendingToggleTrack = 7;
                                    ~transportPressTime = Main.elapsedTime;
                                    AppClock.sched(0.5, {
                                        if(~transportPressTime.notNil) {
                                            ~transportHeld = true;
                                            ~startPulseRoutine.();
                                            ~pendingToggle = nil;
                                            ~pendingToggleTrack = nil;
                                            "[Gladiola] Tempo nudge mode".postln;
                                            ~updateGridLEDs.();
                                        };
                                        nil;
                                    });
                                };
                                if(x == 3) {
                                    ~globalReverse = ~globalReverse.not;
                                    ~reverseHeld = false;
                                    "[Gladiola] Global reverse -> %".format(~globalReverse).postln;
                                    ~updateGridLEDs.();
                                };
                                if(x == 4) {
                                    ~pendingToggle = 4;
                                    ~pendingToggleTrack = 7;
                                };
                                if(x >= 5 && (x <= 8)) {
                                    ~presetHeldSlot = x - 5;
                                    ~presetHeldX = x;
                                };
                                if(x >= 9 && (x <= 15)) {
                                    ~pendingToggle = x;
                                    ~pendingToggleTrack = 7;
                                };
                            } {
                                if(y >= 0 && (y < ~numTracks)) {
                                    var track = ~tracks[y];
                                    if(~stepInRange.(x, track[\startStep], track[\endStep])) {
                                        ~pendingToggle = x;
                                        ~pendingToggleTrack = y;
                                    };
                                };
                            };
                        };
                        };
                    };
                };
                };
            };
        };
    });

    ~grid.hold({ |x, y|
        if(~paramMenuActive && ~subStepEditing.not && ~heldTrack.notNil && ~heldStepIdx.notNil) {
            var step = ~tracks[~heldTrack][\steps][~heldStepIdx];
            var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
            var layout = ~overlayLayout.(~heldStepIdx, ~heldTrack, valueRow);
            var subIdx = ~subIdxFromGrid.(x, y, [layout[\subCols], layout[\subRows]]);
            if(subIdx.notNil) { if(step[\subActive][subIdx]) {
                ~pendingSubToggle = nil;
                ~subStepEditing = true;
                ~subStepEditIdx = subIdx;
                ~startPulseRoutine.();

                ~savedParamPage = ~paramPage;
                ~savedSelectedParam = ~selectedParam;
                ~subStepParamPage = ~paramPage;
                if(step[\subSteps][subIdx].isNil) { step[\subSteps][subIdx] = Dictionary.new };
                "[Gladiola] Sub-step % editing".format(subIdx).postln;
                ~updateGridLEDs.();
            } };
        } {
        if(~paramMenuActive.not && ~trackParamActive.not && ~lfoModActive.not && ~lengthModalTrack.isNil && ~lengthModalMode.isNil && ~utilityOverlayActive.not && ~transportHeld.not) {
            if(y >= 0 && (y < ~numTracks)) {
                var track = ~tracks[y];
                if(~stepInRange.(x, track[\startStep], track[\endStep])) {
                    var step = track[\steps][x];
                    if(~clipboard.notNil && (step[\on] == false)) {
                        ~pendingToggle = nil;
                        ~pendingToggleTrack = nil;
                        track[\steps][x] = ~deepCopyStep.(~clipboard);
                        track[\steps][x][\on] = true;
                        "[Gladiola] Pasted into track % step %".format(y, x).postln;
                        ~updateGridLEDs.();
                    } {
                        ~pendingToggle = nil;
                        ~pendingToggleTrack = nil;
                        ~heldTrack = y;
                        ~heldStepIdx = x;
                        ~paramMenuActive = true;
                        ~selectedParam = 0;
                        ~paramPage = 0;
                        ~updateGridLEDs.();
                    };
                };
            };
            if(y == 7) {
                if(x == 3) {
                    ~reverseHeld = true;
                };
                if(x == 1) {
                    ~pendingToggle = nil;
                    ~utilityOverlayActive = true;
                    ~utilityOverlayType = \clockDiv;
                    ~utilityHeldButton = x;
                    "[Gladiola] Clock div overlay opened".postln;
                    ~updateGridLEDs.();
                };
                if(x == 2) {
                    ~pendingToggle = nil;
                    ~utilityOverlayActive = true;
                    ~utilityOverlayType = \fxMatrix;
                    ~utilityHeldButton = x;
                    "[Gladiola] FX matrix overlay opened".postln;
                    ~updateGridLEDs.();
                };
                if(x == 4) {
                    ~pendingToggle = nil;
                    ~utilityOverlayActive = true;
                    ~utilityOverlayType = \transpose;
                    ~utilityHeldButton = x;
                    "[Gladiola] Transpose overlay opened (current: %)".format(~transpose).postln;
                    ~updateGridLEDs.();
                };
                if(x >= 5 && (x <= 8)) {
                    var btnIdx = x - 5;
                    var mappedSlot = ~presetSlotMap[btnIdx];
                    if(~presets[mappedSlot].isNil) {
                        ~presetHeldSlot = nil;
                        ~presetHeldX = nil;
                        ~savePreset.(mappedSlot);
                        ~updateGridLEDs.();
                    } {
                        ~presetHeldSlot = nil;
                        ~presetHeldX = nil;
                        ~pendingToggle = nil;
                        ~utilityOverlayActive = true;
                        ~utilityOverlayType = \preset;
                        ~utilityHeldButton = x;
                        ~presetSelectedSlot = mappedSlot;
                        ~presetConfirmArmed = nil;
                        "[Gladiola] Preset matrix overlay opened (slot %)".format(mappedSlot).postln;
                        ~updateGridLEDs.();
                    };
                };
                if(x >= 9 && (x <= 15)) {
                    ~pendingToggle = nil;
                    ~pendingToggleTrack = nil;
                    ~trackParamActive = true;
                    ~trackParamCol = x;
                    ~trackParamTrack = x - 9;
                    ~selectedParam = 0;
                    ~paramPage = 0;
                    ~updateGridLEDs.();
                };
            };
        };
        };
    });

    ~grid.release({ |x, y|
        if(~transportHeld && (x == 0) && (y == 3)) {
            if(~anchorPressTime.notNil) {
                ~setTempo.(~anchorTempo);
                ~anchorPressTime = nil;
                "[Gladiola] Anchor tempo recalled: % BPM".format(~anchorTempo).postln;
                ~updateGridLEDs.();
            };
        };
        if(y == 7 && (x == 0)) {
            ~transportPressTime = nil;
            if(~transportHeld) {
                if(~latchActive) {
                    // Latch engaged — keep transport open
                } {
                    ~transportHeld = false;
                    if(~subStepEditing.not) { ~stopPulseRoutine.() };
                    "[Gladiola] Transport page closed".postln;
                    ~updateGridLEDs.();
                };
            };
        };
        if(y == 7 && (x == 3) && ~reverseHeld) {
            ~reverseHeld = false;
            ~globalReverse = ~globalReverse.not;
            "[Gladiola] Global reverse hold release -> %".format(~globalReverse).postln;
            ~updateGridLEDs.();
        };
        if(~paramMenuActive) {
            if(~heldTrack.notNil && (x == ~heldStepIdx) && (y == ~heldTrack)) {
                if(~latchActive) {
                    // Latch is engaged — keep overlay open after releasing parent step
                } {
                    ~stopPulseRoutine.();
                    ~lastOverlayCloseTime = Main.elapsedTime;
                    ~paramMenuActive = false;
                    ~heldTrack = nil;
                    ~heldStepIdx = nil;
                    ~auditionEnabled = true;
                    ~subStepEditing = false;
                    ~subStepEditIdx = nil;
                    ~pendingSubToggle = nil;
                    ~latchActive = false;
                    ~savedParamPage = nil;
                    ~savedSelectedParam = nil;
                    ~updateGridLEDs.();
                };
            } {
                if(~pendingSubToggle.notNil && ~heldTrack.notNil && ~heldStepIdx.notNil) {
                    var step = ~tracks[~heldTrack][\steps][~heldStepIdx];
                    var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
                    var layout = ~overlayLayout.(~heldStepIdx, ~heldTrack, valueRow);
                    var subIdx = ~subIdxFromGrid.(x, y, [layout[\subCols], layout[\subRows]]);
                    if(subIdx.notNil && (subIdx == ~pendingSubToggle)) {
                        step[\subActive][subIdx] = step[\subActive][subIdx].not;
                        ~pendingSubToggle = nil;
                        ~updateGridLEDs.();
                    };
                };
            };
        } {
            if(~lfoModActive) {
                if(x == 1 && (y == 7)) {
                    ~lfoHoldActive = false;
                    if(~lfoSynths.notNil) { if(~lfoSynths[~lfoModTrack].notNil) {
                        ~lfoSynths[~lfoModTrack].set(\freeze, 0)
                    } };
                    "[Gladiola] LFO hold released".postln;
                    ~updateGridLEDs.();
                };
            } {
            if(~trackParamActive) {
                if(x == ~trackParamCol && (y == 7)) {
                    if(~latchActive) {
                        // Latch engaged — keep overlay open
                    } {
                        ~trackParamActive = false;
                        ~trackParamCol = nil;
                        ~trackParamTrack = nil;
                        ~trackClearArmed = false;
                        ~lastOverlayCloseTime = Main.elapsedTime;
                        ~updateGridLEDs.();
                    };
                };
            } {
                if(~utilityOverlayActive) {
                    if(y == 7 && (x == ~utilityHeldButton)) {
                        if(~latchActive) {
                            // Latch engaged — keep overlay open
                        } {
                            if(~utilityOverlayType == \preset) {
                                var btnIdx = x - 5;
                                ~utilityOverlayActive = false;
                                ~utilityOverlayType = nil;
                                ~utilityHeldButton = nil;
                                ~presetConfirmArmed = nil;
                                if(~presetSelectedSlot.notNil) {
                                    ~presetSlotMap[btnIdx] = ~presetSelectedSlot;
                                };
                                "[Gladiola] Preset overlay closed, btn % -> slot %".format(btnIdx, ~presetSlotMap[btnIdx]).postln;
                                ~updateGridLEDs.();
                            } {
                                "[Gladiola] Overlay closed".postln;
                                ~utilityOverlayActive = false;
                                ~utilityOverlayType = nil;
                                ~utilityHeldButton = nil;
                                ~updateGridLEDs.();
                            };
                        };
                    } {
                        "[Gladiola] Overlay release ignored: x=%, y=%, expected (%, 7)".format(x, y, ~utilityHeldButton).postln;
                    };
                } {
                    if(y == 7 && (x >= 5) && (x <= 8) && ~presetHeldSlot.notNil && (x == ~presetHeldX)) {
                        var btnIdx = ~presetHeldSlot;
                        var mappedSlot = ~presetSlotMap[btnIdx];
                        ~presetHeldSlot = nil;
                        ~presetHeldX = nil;
                        if(~presets[mappedSlot].notNil) {
                            if(~presetQuantized && ~playing) {
                                if(~pendingPresetRecall == mappedSlot) {
                                    ~pendingPresetRecall = nil;
                                    ~pendingPresetButton = nil;
                                    ~recallPreset.(mappedSlot);
                                    ~activePresetButton = btnIdx;
                                    "[Gladiola] Preset % immediate recall (was queued).".format(mappedSlot).postln;
                                } {
                                    ~pendingPresetRecall = mappedSlot;
                                    ~pendingPresetButton = btnIdx;
                                    "[Gladiola] Preset % queued for quantized recall.".format(mappedSlot).postln;
                                };
                            } {
                                ~recallPreset.(mappedSlot);
                                ~activePresetButton = btnIdx;
                            };
                        };
                        ~updateGridLEDs.();
                    } {
                        if(~pendingToggle.notNil && ~pendingToggleTrack.notNil) {
                            if(~pendingToggleTrack == 7 && (~pendingToggle == 0)) {
                                ~pendingToggle = nil;
                                ~pendingToggleTrack = nil;
                                if(~playing) { ~stopTransport.() } { ~startTransport.() };
                                ~updateGridLEDs.();
                            } {
                                if(~pendingToggleTrack == 7 && (~pendingToggle == 4)) {
                                    ~pendingToggle = nil;
                                    ~pendingToggleTrack = nil;
                                    if(~prevTranspose.notNil) {
                                        var swap = ~transpose;
                                        ~transpose = ~prevTranspose;
                                        ~prevTranspose = swap;
                                        "[Gladiola] Transpose swap -> %".format(~transpose).postln;
                                    };
                                    ~updateGridLEDs.();
                                } {
                                if(~pendingToggleTrack == 7) {
                                    var trackIdx = ~pendingToggle - 9;
                                    ~pendingToggle = nil;
                                    ~pendingToggleTrack = nil;
                                    ~toggleMuteTrack.(trackIdx);
                                    ~updateGridLEDs.();
                                } {
                                    var stepIdx = ~pendingToggle;
                                    var trackIdx = ~pendingToggleTrack;
                                    ~pendingToggle = nil;
                                    ~pendingToggleTrack = nil;
                                    ~tracks[trackIdx][\steps][stepIdx][\on] = ~tracks[trackIdx][\steps][stepIdx][\on].not;
                                    ~updateGridLEDs.();
                                };
                            };
                            };
                        };
                    };
                };
            };
            };
        };
    });

    ~grid.doubleTap({ |x, y|
        if(y == 7 && (x == 0)) {
            ~stopTransport.();
            ~panicVoices.();
            ~killFxTails.();
            ~updateGridLEDs.();
        };
        if(~paramMenuActive && ~subStepEditing.not && ~heldTrack.notNil && ~heldStepIdx.notNil) {
            var step = ~tracks[~heldTrack][\steps][~heldStepIdx];
            var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
            var layout = ~overlayLayout.(~heldStepIdx, ~heldTrack, valueRow);
            var subIdx = ~subIdxFromGrid.(x, y, [layout[\subCols], layout[\subRows]]);
            if(subIdx.notNil) {
                step[\subSteps][subIdx] = nil;
                "[Gladiola] Sub-step % overrides cleared".format(subIdx).postln;
                ~updateGridLEDs.();
            };
        };
        if(y >= 0 && (y < ~numTracks)) {
            if(~utilityOverlayActive.not && ~paramMenuActive.not && ~trackParamActive.not && ~lfoModActive.not && ~lengthModalTrack.isNil && ~transportHeld.not && (~lastOverlayCloseTime.isNil || { (Main.elapsedTime - ~lastOverlayCloseTime) > 0.3 })) {
                var track = ~tracks[y];
                if(~stepInRange.(x, track[\startStep], track[\endStep])) {
                    track[\steps][x][\on] = track[\steps][x][\on].not;
                };
                ~setTrackStart.(y, x);
                ~pendingToggle = nil;
                ~pendingToggleTrack = nil;
                ~lengthModalTrack = y;
                ~lengthModalMode = \setEnd;
                "[Gladiola] Track %: start -> %, select end".format(y, x).postln;
                ~updateGridLEDs.();
            };
        };
    });

    "[Gladiola] Grid handler initialized.".postln;
};

"[Gladiola] grid_input.scd loaded.".postln;
)

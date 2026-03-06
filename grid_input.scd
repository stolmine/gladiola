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

~overlayActionPositions = { |heldTrack, heldStepIdx, valueRow|
    var actionCol = if(heldStepIdx <= 7) { (heldStepIdx + 4).min(15) } { (heldStepIdx - 4).max(0) };
    var pRow, cRow, aRow;
    if(heldTrack <= 1) { pRow = heldTrack + 2; cRow = heldTrack + 4; aRow = heldTrack + 6 };
    if(heldTrack >= 2 && (heldTrack <= 3)) { pRow = heldTrack - 2; cRow = heldTrack + 2; aRow = heldTrack + 4 };
    if(heldTrack == 4) { pRow = heldTrack - 2; cRow = heldTrack + 2; aRow = 0 };
    if(heldTrack >= 5) { pRow = heldTrack - 4; cRow = heldTrack - 2; aRow = 7 };
    // Dodge value row collisions
    if(valueRow.notNil) {
        if(pRow == valueRow) {
            if((pRow - 1) >= 0 && ((pRow - 1) != heldTrack)) { pRow = pRow - 1 }
            { if((pRow + 1) <= 7 && ((pRow + 1) != heldTrack) && ((pRow + 1) != cRow)) { pRow = pRow + 1 } };
        };
        if(cRow == valueRow) {
            if((cRow + 1) <= 7 && ((cRow + 1) != heldTrack)) { cRow = cRow + 1 }
            { if((cRow - 1) >= 0 && ((cRow - 1) != heldTrack) && ((cRow - 1) != pRow)) { cRow = cRow - 1 } };
        };
        if(aRow == valueRow) {
            if((aRow + 1) <= 7 && ((aRow + 1) != heldTrack) && ((aRow + 1) != pRow) && ((aRow + 1) != cRow)) { aRow = aRow + 1 }
            { if((aRow - 1) >= 0 && ((aRow - 1) != heldTrack) && ((aRow - 1) != pRow) && ((aRow - 1) != cRow)) { aRow = aRow - 1 } };
        };
    };
    Dictionary[\pageCol -> actionCol, \pageRow -> pRow, \copyCol -> actionCol, \copyRow -> cRow, \auditionCol -> actionCol, \auditionRow -> aRow]
};

~valueIdxForCol = { |col, heldCol|
    if(col == heldCol) { nil } {
        if(col < heldCol) { col } { col - 1 }
    }
};

~trackOverlayPagePos = { |heldCol, valueRow|
    var pageCol = heldCol - 4;
    var pageRow = if(valueRow != 0) { 0 } { 1 };
    Dictionary[\pageCol -> pageCol, \pageRow -> pageRow]
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
                        var nudges = [10, 5, 1, nil, -1, -5, -10];
                        var nudge = nudges[y];
                        if(nudge.notNil) {
                            ~setTempo.(~bpm + nudge);
                        } {
                            ~setTempo.(120);
                        };
                        ~updateGridLEDs.();
                    };
                } {
                if(~utilityOverlayActive) {
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
                                                        "[Gladiola] Preset % cleared (confirmed).".format(~presetSelectedSlot).postln;
                                                    } {
                                                        ~presetConfirmArmed = \clear;
                                                        "[Gladiola] Preset % clear armed — tap again to confirm.".format(~presetSelectedSlot).postln;
                                                    };
                                                } {
                                                    ~clearPreset.(~presetSelectedSlot);
                                                    ~presetConfirmArmed = nil;
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
                        var paramNames = ~currentParamNames.();
                        var step = ~tracks[~heldTrack][\steps][~heldStepIdx];
                        var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
                        var actionPos = ~overlayActionPositions.(~heldTrack, ~heldStepIdx, valueRow);

                        if(x == actionPos[\auditionCol] && (y == actionPos[\auditionRow])) {
                            ~auditionEnabled = ~auditionEnabled.not;
                            "[Gladiola] Audition -> %".format(~auditionEnabled).postln;
                            if(~auditionEnabled && ~playing.not) {
                                ~previewStep.(~heldTrack, ~heldStepIdx);
                            };
                            ~updateGridLEDs.();
                        } {
                        if(x == actionPos[\pageCol] && (y == actionPos[\pageRow])) {
                            ~paramPage = 1 - ~paramPage;
                            ~selectedParam = 0;
                            "[Gladiola] Param page -> %".format(~paramPage).postln;
                            ~updateGridLEDs.();
                        } {
                        if(x == actionPos[\copyCol] && (y == actionPos[\copyRow])) {
                            ~clipboard = step.copy;
                            ~clipboard.removeAt(\on);
                            "[Gladiola] Copied step params from track % step %".format(~heldTrack, ~heldStepIdx).postln;
                            ~updateGridLEDs.();
                        } {
                            if(x == ~heldStepIdx && (y != ~heldTrack)) {
                                var paramIdx = ~paramIndexForRow.(y, ~heldTrack);
                                if(paramIdx.notNil && (paramIdx < paramNames.size)) {
                                    if(paramIdx == 0 && (~selectedParam == 0) && (~paramPage == 0)) {
                                        var numBanks = (~numBanks ? 1).max(1);
                                        var curBank = step[\bank];
                                        var newBank = (curBank + 1) % numBanks;
                                        step[\bank] = newBank;
                                        step[\sample] = 0;
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
                                        var numValid = ~numValidPositions.(~paramPage, ~selectedParam, ~heldTrack, ~heldStepIdx);
                                        if(valIdx < numValid) {
                                            if(~selectedParam == 0 && (~paramPage == 0)) {
                                                step[\sample] = valIdx;
                                                "[Gladiola] Track % step %: sample -> %".format(~heldTrack, ~heldStepIdx, valIdx).postln;
                                            } {
                                                var val = ~valueForPosition.(~paramPage, ~selectedParam, valIdx);
                                                step[paramNames[~selectedParam]] = val;
                                                "[Gladiola] Track % step %: % -> %".format(~heldTrack, ~heldStepIdx, paramNames[~selectedParam], val).postln;
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
                    } {
                        if(~trackParamActive && ~trackParamCol.notNil && ~trackParamTrack.notNil) {
                            var paramNames = ~currentParamNames.();
                            var valueRow = ~selectedParam;
                            var pagePos = ~trackOverlayPagePos.(~trackParamCol, valueRow);

                            if(x == pagePos[\pageCol] && (y == pagePos[\pageRow])) {
                                ~paramPage = 1 - ~paramPage;
                                ~selectedParam = 0;
                                "[Gladiola] Track param page -> %".format(~paramPage).postln;
                                ~updateGridLEDs.();
                            } {
                                if(x == ~trackParamCol && (y < 7)) {
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
                                                ~updateGridLEDs.();
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
                                    if(~prevTranspose.notNil) {
                                        var swap = ~transpose;
                                        ~transpose = ~prevTranspose;
                                        ~prevTranspose = swap;
                                        "[Gladiola] Transpose swap -> %".format(~transpose).postln;
                                        ~updateGridLEDs.();
                                    };
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
    });

    ~grid.hold({ |x, y|
        if(~paramMenuActive.not && ~trackParamActive.not && ~lengthModalTrack.isNil && ~lengthModalMode.isNil && ~utilityOverlayActive.not && ~transportHeld.not) {
            if(y >= 0 && (y < ~numTracks)) {
                var track = ~tracks[y];
                if(~stepInRange.(x, track[\startStep], track[\endStep])) {
                    var step = track[\steps][x];
                    if(~clipboard.notNil && (step[\on] == false)) {
                        ~pendingToggle = nil;
                        ~pendingToggleTrack = nil;
                        ~clipboard.keysValuesDo { |key, val|
                            step[key] = val;
                        };
                        step[\on] = true;
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
                        ~lastRecalledSlot[btnIdx] = mappedSlot;
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
    });

    ~grid.release({ |x, y|
        if(y == 7 && (x == 0)) {
            ~transportPressTime = nil;
            if(~transportHeld) {
                ~transportHeld = false;
                "[Gladiola] Tempo nudge mode off".postln;
                ~updateGridLEDs.();
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
                ~paramMenuActive = false;
                ~heldTrack = nil;
                ~heldStepIdx = nil;
                ~auditionEnabled = true;
                ~updateGridLEDs.();
            };
        } {
            if(~trackParamActive) {
                if(x == ~trackParamCol && (y == 7)) {
                    ~trackParamActive = false;
                    ~trackParamCol = nil;
                    ~trackParamTrack = nil;
                    ~updateGridLEDs.();
                };
            } {
                if(~utilityOverlayActive) {
                    if(y == 7 && (x == ~utilityHeldButton)) {
                        if(~utilityOverlayType == \preset) {
                            var btnIdx = x - 5;
                            ~utilityOverlayActive = false;
                            ~utilityOverlayType = nil;
                            ~utilityHeldButton = nil;
                            ~presetConfirmArmed = nil;
                            if(~presetSelectedSlot.notNil) {
                                ~presetSlotMap[btnIdx] = ~presetSelectedSlot;
                                if(~presets[~presetSelectedSlot].notNil) {
                                    if(~presetQuantized) {
                                        ~pendingPresetRecall = ~presetSelectedSlot;
                                        ~pendingPresetButton = btnIdx;
                                        "[Gladiola] Preset % queued (matrix).".format(~presetSelectedSlot).postln;
                                    } {
                                        ~recallPreset.(~presetSelectedSlot);
                                        ~lastRecalledSlot[btnIdx] = ~presetSelectedSlot;
                                    };
                                };
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
                            if(~presetQuantized) {
                                ~pendingPresetRecall = mappedSlot;
                                ~pendingPresetButton = btnIdx;
                                "[Gladiola] Preset % queued for quantized recall.".format(mappedSlot).postln;
                            } {
                                ~recallPreset.(mappedSlot);
                                ~lastRecalledSlot[btnIdx] = mappedSlot;
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
    });

    ~grid.doubleTap({ |x, y|
        if(y == 7 && (x == 0)) {
            ~stopTransport.();
            ~panicVoices.();
            ~killFxTails.();
            ~updateGridLEDs.();
        };
        if(y >= 0 && (y < ~numTracks)) {
            if(~utilityOverlayActive.not && ~paramMenuActive.not && ~trackParamActive.not && ~lengthModalTrack.isNil) {
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

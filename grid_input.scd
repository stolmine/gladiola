(
~heldTrack = nil;
~heldStepIdx = nil;
~paramMenuActive = false;
~selectedParam = 0;
~pendingToggle = nil;
~pendingToggleTrack = nil;
~lengthModalTrack = nil;
~lengthModalMode = nil;  // \setEnd or \setStart
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

~paramRowForIndex = { |paramIdx, heldTrack|
    // Maps param index (0-6) to grid row, skipping heldTrack's row.
    // Rows 0-6 provide 6 slots; paramIdx 6 overflows to row 7.
    var row = if(paramIdx < heldTrack) { paramIdx } { paramIdx + 1 };
    row
};

~paramIndexForRow = { |row, heldTrack|
    // Maps grid row to param index, accounting for skipped heldTrack row.
    // Row 7 maps to paramIdx 6 (the overflow slot).
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
    var pRow, cRow;
    if(heldTrack <= 1) { pRow = heldTrack + 2; cRow = heldTrack + 4 };
    if(heldTrack >= 2 && (heldTrack <= 4)) { pRow = heldTrack - 2; cRow = heldTrack + 2 };
    if(heldTrack >= 5) { pRow = heldTrack - 4; cRow = heldTrack - 2 };
    // Dodge value row collisions
    if(valueRow.notNil) {
        if(pRow == valueRow) {
            // P tries to shift up (away from C), then down
            if((pRow - 1) >= 0 && ((pRow - 1) != heldTrack)) { pRow = pRow - 1 }
            { if((pRow + 1) <= 7 && ((pRow + 1) != heldTrack) && ((pRow + 1) != cRow)) { pRow = pRow + 1 } };
        };
        if(cRow == valueRow) {
            // C tries to shift down (away from P), then up
            if((cRow + 1) <= 7 && ((cRow + 1) != heldTrack)) { cRow = cRow + 1 }
            { if((cRow - 1) >= 0 && ((cRow - 1) != heldTrack) && ((cRow - 1) != pRow)) { cRow = cRow - 1 } };
        };
    };
    "[Gladiola] actionPos: heldTrack=%, heldStep=%, actionCol=%, pRow=%, cRow=%, valueRow=%".format(heldTrack, heldStepIdx, actionCol, pRow, cRow, valueRow).postln;
    Dictionary[\pageCol -> actionCol, \pageRow -> pRow, \copyCol -> actionCol, \copyRow -> cRow]
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
                if(~utilityOverlayActive) {
                    var expectedCol = switch(~utilityOverlayType)
                        { \clockDiv } { 1 }
                        { \delayDiv } { 2 }
                        { \transpose } { 4 };
                    if(x == expectedCol && (y < 7)) {
                        if(~utilityOverlayType == \transpose) {
                            var transposeValues = [0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0];
                            ~prevTranspose = ~transpose;
                            ~transpose = transposeValues[y];
                            "[Gladiola] Transpose -> %".format(~transpose).postln;
                        } {
                            var divValues = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0];
                            var div = divValues[y];
                            "[Gladiola] Div overlay tap: col %, row % -> %".format(x, y, div).postln;
                            if(~utilityOverlayType == \clockDiv) {
                                ~setClockDiv.(div);
                            } {
                                ~setDelayDiv.(div);
                            };
                        };
                        ~updateGridLEDs.();
                    };
                } {
                    if(~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil) {
                        var paramNames = ~currentParamNames.();
                        var step = ~tracks[~heldTrack][\steps][~heldStepIdx];
                        var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
                        var actionPos = ~overlayActionPositions.(~heldTrack, ~heldStepIdx, valueRow);

                        if(x == actionPos[\pageCol] && (y == actionPos[\pageRow])) {
                            // Page toggle
                            ~paramPage = 1 - ~paramPage;
                            ~selectedParam = 0;
                            "[Gladiola] Param page -> %".format(~paramPage).postln;
                            ~updateGridLEDs.();
                        } {
                        if(x == actionPos[\copyCol] && (y == actionPos[\copyRow])) {
                            // Copy step params to clipboard
                            ~clipboard = step.copy;
                            ~clipboard.removeAt(\on);
                            "[Gladiola] Copied step params from track % step %".format(~heldTrack, ~heldStepIdx).postln;
                            ~updateGridLEDs.();
                        } {
                            if(x == ~heldStepIdx && (y != ~heldTrack)) {
                                // Tap in held column: select param (rows 0-7 except heldTrack)
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
                                // Tap in value row (could be on rows 0-7)
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
                                            ~updateGridLEDs.();
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
                                // Page toggle
                                ~paramPage = 1 - ~paramPage;
                                ~selectedParam = 0;
                                "[Gladiola] Track param page -> %".format(~paramPage).postln;
                                ~updateGridLEDs.();
                            } {
                                if(x == ~trackParamCol && (y < 7)) {
                                    // Param select
                                    if(y < paramNames.size) {
                                        if(y == 0 && (~selectedParam == 0) && (~paramPage == 0)) {
                                            // Bank cycle: apply to ALL steps
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
                                    // Value tap
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
                                    if(~playing) { ~stopTransport.() } { ~startTransport.() };
                                    ~updateGridLEDs.();
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
    });

    ~grid.hold({ |x, y|
        if(~paramMenuActive.not && ~trackParamActive.not && ~lengthModalTrack.isNil && ~lengthModalMode.isNil && ~utilityOverlayActive.not) {
            if(y >= 0 && (y < ~numTracks)) {
                var track = ~tracks[y];
                if(~stepInRange.(x, track[\startStep], track[\endStep])) {
                    var step = track[\steps][x];
                    if(~clipboard.notNil && (step[\on] == false)) {
                        // Paste clipboard into off step
                        ~pendingToggle = nil;
                        ~pendingToggleTrack = nil;
                        ~clipboard.keysValuesDo { |key, val|
                            step[key] = val;
                        };
                        step[\on] = true;
                        "[Gladiola] Pasted into track % step %".format(y, x).postln;
                        ~updateGridLEDs.();
                    } {
                        // Open param menu
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
                    "[Gladiola] Clock div overlay opened (current: %)".format(~clockDiv).postln;
                    ~updateGridLEDs.();
                };
                if(x == 2) {
                    ~pendingToggle = nil;
                    ~utilityOverlayActive = true;
                    ~utilityOverlayType = \delayDiv;
                    ~utilityHeldButton = x;
                    "[Gladiola] Delay div overlay opened (current: %)".format(~delayDiv).postln;
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
                    ~presetHeldSlot = nil;
                    ~presetHeldX = nil;
                    ~savePreset.(x - 5);
                    ~updateGridLEDs.();
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
                        "[Gladiola] Div overlay closed".postln;
                        ~utilityOverlayActive = false;
                        ~utilityOverlayType = nil;
                        ~utilityHeldButton = nil;
                        ~updateGridLEDs.();
                    } {
                        "[Gladiola] Div overlay release ignored: x=%, y=%, expected (%, 7)".format(x, y, ~utilityHeldButton).postln;
                    };
                } {
                    if(y == 7 && (x >= 5) && (x <= 8) && ~presetHeldSlot.notNil && (x == ~presetHeldX)) {
                        var slot = ~presetHeldSlot;
                        ~presetHeldSlot = nil;
                        ~presetHeldX = nil;
                        ~recallPreset.(slot);
                        ~updateGridLEDs.();
                    } {
                        if(~pendingToggle.notNil && ~pendingToggleTrack.notNil) {
                            if(~pendingToggleTrack == 7) {
                                // Mute toggle (deferred from press)
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
    });

    ~grid.doubleTap({ |x, y|
        if(y == 7 && (x == 0)) {
            ~stopTransport.();
            ~panicVoices.();
            ~updateGridLEDs.();
        };
        if(y == 7 && (x >= 5) && (x <= 8)) {
            if(~utilityOverlayActive.not && ~paramMenuActive.not && ~trackParamActive.not && ~lengthModalTrack.isNil) {
                ~presetHeldSlot = nil;
                ~presetHeldX = nil;
                ~clearPreset.(x - 5);
                ~updateGridLEDs.();
            };
        };
        if(y >= 0 && (y < ~numTracks)) {
            if(~utilityOverlayActive.not && ~paramMenuActive.not && ~trackParamActive.not && ~lengthModalTrack.isNil) {
                var track = ~tracks[y];
                // Undo toggle from first tap's release (only if step was in range)
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

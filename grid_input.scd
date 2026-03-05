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

~valueIdxForCol = { |col, heldCol|
    if(col == heldCol) { nil } {
        if(col < heldCol) { col } { col - 1 }
    }
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
                    var expectedCol = if(~utilityOverlayType == \clockDiv) { 1 } { 2 };
                    if(x == expectedCol && (y < 7)) {
                        var divValues = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0];
                        var div = divValues[y];
                        "[Gladiola] Div overlay tap: col %, row % -> %".format(x, y, div).postln;
                        if(~utilityOverlayType == \clockDiv) {
                            ~setClockDiv.(div);
                        } {
                            ~setDelayDiv.(div);
                        };
                        ~updateGridLEDs.();
                    } {
                        "[Gladiola] Div overlay tap ignored: x=%, y=%, expected col=%".format(x, y, expectedCol).postln;
                    };
                } {
                    if(~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil) {
                        var paramNames = ~currentParamNames.();
                        var step = ~tracks[~heldTrack][\steps][~heldStepIdx];

                        if(x == 3 && y == 7) {
                            // Page toggle on utility row
                            ~paramPage = 1 - ~paramPage;
                            ~selectedParam = 0;
                            "[Gladiola] Param page -> %".format(~paramPage).postln;
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
                    } {
                        if(y == 7) {
                            if(x == 0) {
                                if(~playing) { ~stopTransport.() } { ~startTransport.() };
                                ~updateGridLEDs.();
                            };
                            if(x >= 9 && (x <= 15)) {
                                var trackIdx = x - 9;
                                ~toggleMuteTrack.(trackIdx);
                                ~updateGridLEDs.();
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
    });

    ~grid.hold({ |x, y|
        if(~paramMenuActive.not && ~lengthModalTrack.isNil && ~lengthModalMode.isNil && ~utilityOverlayActive.not) {
            if(y >= 0 && (y < ~numTracks)) {
                var track = ~tracks[y];
                if(~stepInRange.(x, track[\startStep], track[\endStep])) {
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
            if(y == 7) {
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
            };
        };
    });

    ~grid.release({ |x, y|
        if(~paramMenuActive) {
            if(~heldTrack.notNil && (x == ~heldStepIdx) && (y == ~heldTrack)) {
                ~paramMenuActive = false;
                ~heldTrack = nil;
                ~heldStepIdx = nil;
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
                if(~pendingToggle.notNil && ~pendingToggleTrack.notNil) {
                    var stepIdx = ~pendingToggle;
                    var trackIdx = ~pendingToggleTrack;
                    ~pendingToggle = nil;
                    ~pendingToggleTrack = nil;
                    ~tracks[trackIdx][\steps][stepIdx][\on] = ~tracks[trackIdx][\steps][stepIdx][\on].not;
                    ~updateGridLEDs.();
                };
            };
        };
    });

    ~grid.doubleTap({ |x, y|
        if(y >= 0 && (y < ~numTracks)) {
            var track = ~tracks[y];
            // Undo the step toggle from first tap's release
            track[\steps][x][\on] = track[\steps][x][\on].not;
            // Set this position as start, then select end
            ~setTrackStart.(y, x);
            ~pendingToggle = nil;
            ~pendingToggleTrack = nil;
            ~paramMenuActive = false;
            ~heldTrack = nil;
            ~heldStepIdx = nil;
            ~lengthModalTrack = y;
            ~lengthModalMode = \setEnd;
            ~updateGridLEDs.();
        };
    });

    "[Gladiola] Grid handler initialized.".postln;
};

"[Gladiola] grid_input.scd loaded.".postln;
)

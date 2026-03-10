(
~fdbg = { |tag, vals| (tag ++ " " ++ vals.asString).postln };

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
~lfoFrozenVal = nil;
~condEditMode = false;
~phaseEditActive = Array.fill(14, { false });
~polarityPending = nil;
~fxModActive = false;
~fxPhaseEditActive = Array.fill(12, { false });
~fxPolarityPending = nil;
~fxLfoHoldActive = false;
~fxLfoFrozenVal = nil;
~fxShapePending = nil;

~fineActive = false;
~fineContext = nil;
~fineParamPage = nil;
~fineParamIdx = nil;
~fineFxCol = nil;
~fineMixerTrack = nil;
~fineModDest = nil;
~fineTrackIdx = nil;
~fineStepIdx = nil;
~fineSubStepIdx = nil;

~fineGridToPos = { |x, y|
    var cellIdx = y * 16 + x;
    if(cellIdx == 0) { nil } { cellIdx - 1 }
};
~finePosToGrid = { |pos|
    var cellIdx = pos + 1;
    [cellIdx % 16, cellIdx div: 16]
};

~startPulseRoutine = {
    if(~pulseRoutine.isNil) {
        ~pulseRoutine = Routine({
            loop {
                if(~grid.isNil) { nil.yield }; // exit if grid freed
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

~layoutCache = nil;
~layoutCacheKey = nil;

~overlayLayout = { |heldStepIdx, heldTrack, valueRow|
    var key = [heldStepIdx, heldTrack, valueRow];
    if(~layoutCacheKey == key && ~layoutCache.notNil) {
        ~layoutCache
    } {
        var subCols, actionCols, rows;
        var allBlocks, valid, bestBlock, bestScore;

        if(heldStepIdx < 8) {
            subCols = [13,14,15];
            actionCols = [9,10,11];
        } {
            subCols = [0,1,2];
            actionCols = [4,5,6];
        };

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
                if(bestRows != rows) { rows = bestRows };
            };
        }.value;

        ~layoutCache = Dictionary[
            \subCols -> subCols, \subRows -> rows,
            \actionCols -> actionCols, \actionRows -> rows,
            \pageCol -> actionCols[0], \pageRow -> rows[0],
            \sliceCol -> actionCols[2], \sliceRow -> rows[0],
            \auditionCol -> actionCols[0], \auditionRow -> rows[2],
            \latchCol -> actionCols[2], \latchRow -> rows[2]
        ];
        ~layoutCacheKey = key;
        ~layoutCache
    };
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


~handleKeyFine = { |x, y|
    if(x == 0 && (y == 0)) {
        // Exit fine fader
        ~fineActive = false;
        ~fineContext = nil;
        "[Gladiola] Fine fader closed".postln;
        ~updateGridLEDs.();
    } {
        var pos = ~fineGridToPos.(x, y);
        if(pos.notNil) {
            switch(~fineContext)
            { \step } {
                var step = ~tracks[~fineTrackIdx][\steps][~fineStepIdx];
                var target = if(~fineSubStepIdx.notNil) {
                    if(step[\subSteps][~fineSubStepIdx].isNil) { step[\subSteps][~fineSubStepIdx] = Dictionary.new };
                    step[\subSteps][~fineSubStepIdx]
                } { step };
                if(~fineParamIdx == 0 && (~fineParamPage == 0)) {
                    var info = ~fineSampleToBank.(pos);
                    target[\bank] = info[0];
                    target[\sample] = info[1];
                    "[Gladiola] Fine step sample -> bank % sample %".format(info[0], info[1]).postln;
                } {
                    var val = ~fineValueForPosition.(~fineParamPage, ~fineParamIdx, pos);
                    var paramNames = if(~fineParamPage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 };
                    target[paramNames[~fineParamIdx]] = val;
                    "[Gladiola] Fine step % -> %".format(paramNames[~fineParamIdx], val).postln;
                };
                if(~auditionEnabled && ~playing.not) {
                    ~previewStep.(~fineTrackIdx, ~fineStepIdx);
                };
            }
            { \track } {
                var paramNames = if(~fineParamPage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 };
                if(~fineParamIdx == 0 && (~fineParamPage == 0)) {
                    var info = ~fineSampleToBank.(pos);
                    ~tracks[~fineTrackIdx][\steps].do { |step|
                        step[\bank] = info[0];
                        step[\sample] = info[1];
                    };
                    "[Gladiola] Fine track sample -> bank % sample %".format(info[0], info[1]).postln;
                } {
                    var val = ~fineValueForPosition.(~fineParamPage, ~fineParamIdx, pos);
                    ~tracks[~fineTrackIdx][\steps].do { |step|
                        step[paramNames[~fineParamIdx]] = val;
                    };
                    "[Gladiola] Fine track % -> %".format(paramNames[~fineParamIdx], val).postln;
                };
                if(~auditionEnabled && ~playing.not) {
                    ~previewStep.(~fineTrackIdx, 0, true);
                };
            }
            { \fxClouds } {
                var key = ~fxCloudsKeys[~fineFxCol];
                var value = ~fxCloudsFineValueForPosition.(key, pos);
                ~setFxCloudsParam.(key, value);
                ~updateGridLEDs.();
            }
            { \fxMaster } {
                var key = ~fxMasterKeys[~fineFxCol];
                var value = ~fxMasterFineValueForPosition.(key, pos);
                ~setFxParam.(key, value);
                ~updateGridLEDs.();
            }
            { \fxModDepth } {
                var depth = ~modDepthFineValue.(pos);
                var polarity = ~fxModSettings[\polarities][~fineModDest];
                ~setFxModDepth.(~fineModDest, depth, polarity);
                ~updateGridLEDs.();
            }
            { \fxModPhase } {
                var phase = ~phaseFineValue.(pos);
                ~setFxModPhase.(~fineModDest, phase);
                ~updateGridLEDs.();
            }
            { \mixer } {
                var val = ~mixerFineValue.(pos);
                ~setTrackVolume.(~fineMixerTrack, val);
                "[Gladiola] Fine mixer track % -> %".format(~fineMixerTrack, val).postln;
            }
            { \modDepth } {
                var val = ~modDepthFineValue.(pos);
                var polarity = ~trackModSettings[~fineTrackIdx][\polarities][~fineModDest];
                ~setModDepth.(~fineTrackIdx, ~fineModDest, val, polarity);
                "[Gladiola] Fine mod % depth -> %".format(~modDestKeys[~fineModDest], val).postln;
            }
            { \modPhase } {
                var val = ~phaseFineValue.(pos);
                ~setModPhase.(~fineTrackIdx, ~fineModDest, val);
                "[Gladiola] Fine mod % phase -> % deg".format(~modDestKeys[~fineModDest], (val * 360).round).postln;
            };
            ~updateGridLEDs.();
        };
    };
};

~handleKeyLengthModal = { |x, y|
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
};

~handleKeyTransport = { |x, y|
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
};

~handleKeyUtility = { |x, y|
    // Latch toggle (one column right of held button)
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
    switch(~utilityOverlayType)
    { \clockDiv } {
        if(x < 7 && (y < 7)) {
            var divValues = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0];
            var div = divValues[x];
            "[Gladiola] Clock div overlay tap: col %, row % -> track % div %".format(x, y, y, div).postln;
            ~setTrackClockDiv.(y, div);
            ~updateGridLEDs.();
        };
    }
    { \fxMatrix } {
        if(~fxModActive == true) {
            // FX Mod Detail Page press
            if(x == 0 && (y < 7)) {
                // Shape selector
                ~setFxModShape.(y);
                "[Gladiola] FX LFO shape -> %".format(~modShapeNames[y]).postln;
                ~updateGridLEDs.();
            };
            if(x == 0 && (y == 7)) {
                // Exit mod detail
                ~fxModActive = false;
                ~fxLfoHoldActive = false;
                ~fxLfoFrozenVal = nil;
                ~fxPhaseEditActive = Array.fill(12, { false });
                ~fxPolarityPending = nil;
                "[Gladiola] FX mod detail closed.".postln;
                ~updateGridLEDs.();
            };
            if(x == 1 && (y < 7)) {
                // Rate nudge
                var nudge = ~modRateNudges[y];
                if(nudge == 0) {
                    ~setFxModRate.(16);
                } {
                    ~setFxModRate.(~fxModSettings[\rate16ths] + nudge);
                };
                "[Gladiola] FX LFO rate -> % sixteenths".format(~fxModSettings[\rate16ths]).postln;
                ~updateGridLEDs.();
            };
            if(x == 1 && (y == 7)) {
                // Hold/Freeze
                ~fxLfoHoldActive = true;
                ~fxLfoFrozenVal = ~fxLfoBus.getSynchronous;
                if(~fxLfoSynth.notNil) { ~fxLfoSynth.set(\freeze, 1) };
                "[Gladiola] FX LFO hold engaged.".postln;
                ~updateGridLEDs.();
            };
            if(x == 2 && (y < 7)) {
                // TrigRate fader
                var rate = ~fxTrigRateForRow.(y);
                ~setFxCloudsParam.(\trigRate, rate);
                "[Gladiola] FX trigRate -> %".format(rate).postln;
                ~updateGridLEDs.();
            };
            if(x >= 4 && (x <= 15)) {
                var destIdx = x - 4;
                if(y < 7) {
                    if(~fxPhaseEditActive[destIdx]) {
                        // Phase fader
                        var phase = ~phaseValues[y];
                        ~setFxModPhase.(destIdx, phase);
                        "[Gladiola] FX mod phase % -> %".format(~fxModDestKeys[destIdx], phase).postln;
                        ~updateGridLEDs.();
                    } {
                        // Depth fader
                        var depth = ~modDepthForRow.(y);
                        var polarity = ~fxModSettings[\polarities][destIdx];
                        ~setFxModDepth.(destIdx, depth, polarity);
                        "[Gladiola] FX mod depth % -> %".format(~fxModDestKeys[destIdx], depth).postln;
                        ~updateGridLEDs.();
                    };
                };
                if(y == 7) {
                    // Polarity/phase pending
                    ~fxPolarityPending = destIdx;
                };
            };
        } {
            // Main FX Page press
            if(x == 0 && (y < 7)) {
                // Rate nudge
                var nudge = ~modRateNudges[y];
                if(nudge == 0) {
                    ~setFxModRate.(16);
                } {
                    ~setFxModRate.(~fxModSettings[\rate16ths] + nudge);
                };
                "[Gladiola] FX LFO rate -> % sixteenths".format(~fxModSettings[\rate16ths]).postln;
                ~updateGridLEDs.();
            };
            if(x == 0 && (y == 7)) {
                // Shape cycle pending (defer to release; hold enters mod detail)
                ~fxShapePending = true;
            };
            if(x >= 1 && (x <= 9) && (y < 7)) {
                // Clouds param fader
                var key = ~fxCloudsKeys[x - 1];
                var value = ~fxCloudsValueForPosition.(key, y);
                ~setFxCloudsParam.(key, value);
                "[Gladiola] FX Clouds: % -> %".format(key, value).postln;
                ~updateGridLEDs.();
            };
            if(x == 10) {
                if(y == 0) {
                    // Freeze toggle
                    var newFreeze = if(~fxCloudsParams[\freeze] > 0) { 0 } { 1 };
                    ~setFxCloudsParam.(\freeze, newFreeze);
                    "[Gladiola] FX freeze -> %".format(newFreeze).postln;
                    ~updateGridLEDs.();
                };
                if(y == 2) {
                    // Mode cycle
                    var newMode = (~fxCloudsParams[\mode] + 1) % 4;
                    ~setFxCloudsParam.(\mode, newMode);
                    "[Gladiola] FX mode -> %".format(newMode).postln;
                    ~updateGridLEDs.();
                };
                if(y == 4) {
                    // Lofi toggle
                    var newLofi = if(~fxCloudsParams[\lofi] > 0) { 0 } { 1 };
                    ~setFxCloudsParam.(\lofi, newLofi);
                    "[Gladiola] FX lofi -> %".format(newLofi).postln;
                    ~updateGridLEDs.();
                };
                if(y == 7) {
                    // Manual trig
                    if(~cloudsSynth.notNil) { ~cloudsSynth.set(\t_trig, 1) };
                    "[Gladiola] FX manual trig.".postln;
                };
            };
            if(x >= 11 && (x <= 15) && (y < 7)) {
                // Master bus params (unchanged)
                var key = ~fxMasterKeys[x - 11];
                var value = ~fxMasterValueForPosition.(key, y);
                ~setFxParam.(key, value);
                "[Gladiola] FX master: % -> %".format(key, value).postln;
                ~updateGridLEDs.();
            };
        };
    }
    { \transpose } {
        if(x == 4 && (y < 7)) {
            var transposeValues = [0.333, 0.5, 0.667, 1.0, 1.5, 2.0, 3.0];
            ~prevTranspose = ~transpose;
            ~transpose = transposeValues[y];
            "[Gladiola] Transpose -> %".format(~transpose).postln;
            ~updateGridLEDs.();
        };
    }
    { \preset } {
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

~handleKeyLfoMod = { |x, y|
    var ms = ~trackModSettings[~lfoModTrack];
    if(x == 0 && (y < 7)) {
        // Shape selector
        ~setModShape.(~lfoModTrack, y);
        "[Gladiola] LFO shape -> %".format(~modShapeNames[y]).postln;
        ~updateGridLEDs.();
    };
    if(x == 1 && (y < 7)) {
        // Rate nudge (row 3 = snap to 16)
        if(y == 3) {
            ~setModRate.(~lfoModTrack, 16);
            "[Gladiola] LFO rate -> 16 sixteenths (reset)".postln;
        } {
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
        };
        ~updateGridLEDs.();
    };
    if(x >= 2 && (x <= 15) && (y < 7)) {
        var destIdx = x - 2;
        if(~phaseEditActive[destIdx]) {
            // Phase fader
            var phase = ~phaseValues[y];
            ~setModPhase.(~lfoModTrack, destIdx, phase);
            "[Gladiola] LFO % phase -> % deg".format(~modDestKeys[destIdx], ((phase * 360) % 360).round).postln;
            ~updateGridLEDs.();
        } {
            // Depth fader
            var depth = ~modDepthForRow.(y);
            var polarity = ms[\polarities][destIdx];
            ~setModDepth.(~lfoModTrack, destIdx, depth, polarity);
            "[Gladiola] LFO % depth -> %".format(~modDestKeys[destIdx], depth).postln;
            ~updateGridLEDs.();
        };
    };
    if(x >= 2 && (x <= 15) && (y == 7)) {
        // Polarity — defer to release (hold enters phase mode)
        var destIdx = x - 2;
        ~polarityPending = destIdx;
    };
    if(x == 0 && (y == 7)) {
        // Exit — return to track overlay
        ~lfoModActive = false;
        ~lfoHoldActive = false;
        ~lfoFrozenVal = nil;
        ~phaseEditActive = Array.fill(14, { false });
        ~trackParamActive = true;
        ~trackParamCol = 9 + ~lfoModTrack;
        ~trackParamTrack = ~lfoModTrack;
        ~selectedParam = 0;
        ~paramPage = 0;
        "[Gladiola] LFO mod overlay closed, back to track overlay".postln;
        ~updateGridLEDs.();
    };
    if(x == 1 && (y == 7)) {
        // Hold (freeze) — press
        ~lfoHoldActive = true;
        ~lfoFrozenVal = ~lfoBus.getSynchronous(~lfoModTrack);
        if(~lfoSynths.notNil) { if(~lfoSynths[~lfoModTrack].notNil) {
            ~lfoSynths[~lfoModTrack].set(\freeze, 1)
        } };
        "[Gladiola] LFO hold engaged".postln;
        ~updateGridLEDs.();
    };
};

~handleKeyStepOverlay = { |x, y|
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
        ~condEditMode = false;
        ~updateGridLEDs.();
    } {
    if(x == layout[\sliceCol] && (y == layout[\sliceRow])) {
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
            ~condEditMode = false;
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
            var sliceValueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
            var isSliceValueTap = (y == sliceValueRow) && { ~tracks[~heldTrack][\sliceMode] == true } && { ~selectedParam == 0 } && { effectivePage == 0 };
            if(isSliceValueTap) {
                // In slice mode, heldStepIdx column is a value cell on the value row
                var valIdx = x;
                if(~subStepEditing && ~subStepEditIdx.notNil) {
                    if(step[\subSteps][~subStepEditIdx].isNil) { step[\subSteps][~subStepEditIdx] = Dictionary.new };
                    step[\subSteps][~subStepEditIdx][\sliceIdx] = valIdx;
                    "[Gladiola] Sub-step %: sliceIdx -> %".format(~subStepEditIdx, valIdx).postln;
                } {
                    step[\sliceIdx] = valIdx;
                    "[Gladiola] Track % step %: sliceIdx -> %".format(~heldTrack, ~heldStepIdx, valIdx).postln;
                };
                if(~auditionEnabled && ~playing.not) {
                    ~previewStep.(~heldTrack, ~heldStepIdx);
                };
                ~updateGridLEDs.();
            } {
            if(paramIdx.notNil && (paramIdx < paramNames.size)) {
                if(paramIdx == 0 && (~selectedParam == 0) && (effectivePage == 0)) {
                    if(~tracks[~heldTrack][\sliceMode] == true) {
                        var target = if(~subStepEditing && ~subStepEditIdx.notNil) {
                            if(step[\subSteps][~subStepEditIdx].isNil) { step[\subSteps][~subStepEditIdx] = Dictionary.new };
                            step[\subSteps][~subStepEditIdx]
                        } { step };
                        target[\sliceIdx] = ~heldStepIdx;
                        "[Gladiola] Track % step %: sliceIdx -> %".format(~heldTrack, ~heldStepIdx, ~heldStepIdx).postln;
                        if(~auditionEnabled && ~playing.not) {
                            ~previewStep.(~heldTrack, ~heldStepIdx);
                        };
                    } {
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
                    };
                } {
                    if(paramIdx == ~selectedParam && (paramIdx == 5) && (effectivePage == 1)) {
                        ~condEditMode = ~condEditMode.not;
                        "[Gladiola] Cond edit mode -> %".format(~condEditMode).postln;
                    } {
                        if(~condEditMode && (paramIdx != 5 || (effectivePage != 1))) {
                            ~condEditMode = false;
                        };
                        ~selectedParam = paramIdx;
                        "[Gladiola] Param -> %".format(paramNames[paramIdx]).postln;
                    };
                };
                ~updateGridLEDs.();
            };
            };
        } {
            var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);
            var isSliceRow = ~tracks[~heldTrack][\sliceMode] == true && { ~selectedParam == 0 } && { effectivePage == 0 };
            if(y == valueRow && ((x != ~heldStepIdx) || isSliceRow)) {
                if(~condEditMode && (effectivePage == 1) && (~selectedParam == 5)) {
                    // Conditional mode value row: positions 0-6 = N, 7-14 = M
                    var valIdx = ~valueIdxForCol.(x, ~heldStepIdx);
                    if(valIdx.notNil) {
                        if(valIdx <= 6) {
                            var newN = valIdx + 1;
                            step[\condMode] = true;
                            step[\condN] = newN.min(step[\condM]);
                            "[Gladiola] Track % step %: condN -> %".format(~heldTrack, ~heldStepIdx, step[\condN]).postln;
                        } {
                            if(valIdx <= 14) {
                                var newM = valIdx - 7 + 1;
                                if(newM == 1) {
                                    step[\condMode] = false;
                                    step[\condN] = 1;
                                    step[\condM] = 1;
                                    "[Gladiola] Track % step %: cond off (1:1)".format(~heldTrack, ~heldStepIdx).postln;
                                } {
                                    step[\condMode] = true;
                                    step[\condM] = newM;
                                    if(step[\condN] > newM) { step[\condN] = newM };
                                    "[Gladiola] Track % step %: condM -> %, condN -> %".format(~heldTrack, ~heldStepIdx, step[\condM], step[\condN]).postln;
                                };
                            };
                        };
                        ~updateGridLEDs.();
                    };
                } {
                var valIdx = if(isSliceRow) { x } { ~valueIdxForCol.(x, ~heldStepIdx) };
                if(valIdx.notNil) {
                    var numValid = ~numValidPositions.(effectivePage, ~selectedParam, ~heldTrack, ~heldStepIdx);
                    if(valIdx < numValid) {
                        if(~subStepEditing && ~subStepEditIdx.notNil) {
                            if(step[\subSteps][~subStepEditIdx].isNil) { step[\subSteps][~subStepEditIdx] = Dictionary.new };
                            if(~selectedParam == 0 && (effectivePage == 0)) {
                                if(~tracks[~heldTrack][\sliceMode] == true) {
                                    step[\subSteps][~subStepEditIdx][\sliceIdx] = valIdx;
                                    "[Gladiola] Sub-step %: sliceIdx -> %".format(~subStepEditIdx, valIdx).postln;
                                } {
                                    step[\subSteps][~subStepEditIdx][\sample] = valIdx;
                                    "[Gladiola] Sub-step %: sample -> %".format(~subStepEditIdx, valIdx).postln;
                                };
                            } {
                                var val = ~valueForPosition.(effectivePage, ~selectedParam, valIdx);
                                step[\subSteps][~subStepEditIdx][paramNames[~selectedParam]] = val;
                                "[Gladiola] Sub-step %: % -> %".format(~subStepEditIdx, paramNames[~selectedParam], val).postln;
                            };
                        } {
                            if(~selectedParam == 0 && (effectivePage == 0)) {
                                if(~tracks[~heldTrack][\sliceMode] == true) {
                                    step[\sliceIdx] = valIdx;
                                    "[Gladiola] Track % step %: sliceIdx -> %".format(~heldTrack, ~heldStepIdx, valIdx).postln;
                                } {
                                    step[\sample] = valIdx;
                                    "[Gladiola] Track % step %: sample -> %".format(~heldTrack, ~heldStepIdx, valIdx).postln;
                                };
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
    };
};

~handleKeyTrackOverlay = { |x, y|
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
    if(x == layout[\sliceCol] && (y == layout[\sliceRow])) {
        var wasSlice = ~tracks[~trackParamTrack][\sliceMode] == true;
        ~tracks[~trackParamTrack][\sliceMode] = wasSlice.not;
        if(~tracks[~trackParamTrack][\voice].notNil) {
            ~tracks[~trackParamTrack][\voice].set(\sliceMode, wasSlice.not.asInteger);
        };
        if(wasSlice.not) {
            // Enabling: init each step's sliceIdx to step index
            ~stepsPerTrack.do { |stepIdx|
                ~tracks[~trackParamTrack][\steps][stepIdx][\sliceIdx] = stepIdx;
            };
            "[Gladiola] Track %: slice mode ON, steps initialized".format(~trackParamTrack).postln;
        } {
            "[Gladiola] Track %: slice mode OFF".format(~trackParamTrack).postln;
        };
        ~updateGridLEDs.();
    } {
    if(x == layout[\auditionCol] && (y == layout[\auditionRow])) {
        // Audition toggle
        ~auditionEnabled = ~auditionEnabled.not;
        "[Gladiola] Audition -> %".format(~auditionEnabled).postln;
        if(~auditionEnabled && ~playing.not) {
            ~previewStep.(~trackParamTrack, 0, true);
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
                    \sliceIdx, 0,
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
                        ~previewStep.(~trackParamTrack, 0, true);
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
};

~handleKeyNormal = { |x, y|
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

~initGridHandler = {

    ~grid.key({ |x, y, state|
        if(state == 1) {
            case
            { ~fineActive == true }                                               { ~handleKeyFine.(x, y) }
            { ~lengthModalTrack.notNil }                                          { ~handleKeyLengthModal.(x, y) }
            { ~transportHeld }                                                    { ~handleKeyTransport.(x, y) }
            { ~utilityOverlayActive }                                             { ~handleKeyUtility.(x, y) }
            { ~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil }      { ~handleKeyStepOverlay.(x, y) }
            { ~lfoModActive && ~lfoModTrack.notNil }                              { ~handleKeyLfoMod.(x, y) }
            { ~trackParamActive && ~trackParamCol.notNil && ~trackParamTrack.notNil } { ~handleKeyTrackOverlay.(x, y) }
            { true }                                                              { ~handleKeyNormal.(x, y) };
        };
    });
    ~grid.hold({ |x, y|
        ~fdbg.("HOLD", [x, y, ~fineActive, ~paramMenuActive, ~trackParamActive, ~utilityOverlayActive, ~transportHeld, ~lfoModActive]);
        if(~fineActive == true) {
            // Already in fine fader, ignore holds
        } {
        if(~paramMenuActive && ~heldTrack.notNil && ~heldStepIdx.notNil) {
            var effectivePage = if(~subStepEditing) { ~subStepParamPage } { ~paramPage };
            var paramNames = if(effectivePage == 0) { ~paramNamesPage1 } { ~paramNamesPage2 };
            var step = ~tracks[~heldTrack][\steps][~heldStepIdx];
            var valueRow = ~paramRowForIndex.(~selectedParam, ~heldTrack);

            ~fdbg.("STEP", [y, valueRow, x, ~heldStepIdx, ~selectedParam, effectivePage]);
            if(y == valueRow && (x != ~heldStepIdx)) {
                var valIdx = ~valueIdxForCol.(x, ~heldStepIdx);
                ~fdbg.("STEP2", [valIdx, x, ~heldStepIdx]);
                if(valIdx.notNil) {
                    var curPos, isSample = (~selectedParam == 0 && (effectivePage == 0));
                    if(isSample) {
                        curPos = if(~subStepEditing && ~subStepEditIdx.notNil) {
                            ~resolveSubStepParam.(step, ~subStepEditIdx, \sample).asInteger
                        } {
                            step[\sample].asInteger
                        };
                    } {
                        var curVal = if(~subStepEditing && ~subStepEditIdx.notNil) {
                            ~resolveSubStepParam.(step, ~subStepEditIdx, paramNames[~selectedParam])
                        } {
                            step[paramNames[~selectedParam]]
                        };
                        curPos = ~positionForValue.(effectivePage, ~selectedParam, curVal);
                    };
                    ~fdbg.("STEP3", [valIdx, curPos, isSample, valIdx == curPos]);
                    if(valIdx == curPos) {
                        if(isSample or: { ~paramHasFine.(effectivePage, ~selectedParam) }) {
                        ~fdbg.("STEP ENTER", nil);
                            ~fineActive = true;
                            ~fineContext = \step;
                            ~fineParamPage = effectivePage;
                            ~fineParamIdx = ~selectedParam;
                            ~fineTrackIdx = ~heldTrack;
                            ~fineStepIdx = ~heldStepIdx;
                            ~fineSubStepIdx = if(~subStepEditing) { ~subStepEditIdx } { nil };
                            ~latchActive = true;
                            ~startPulseRoutine.();
                            "[Gladiola] Fine fader opened (step)".postln;
                            ~updateGridLEDs.();
                        };
                    };
                };
            };
        };
        if(~fineActive.not && ~trackParamActive && ~trackParamCol.notNil && ~trackParamTrack.notNil) {
            var paramNames = ~currentParamNames.();
            var valueRow = ~selectedParam;
            ~fdbg.("TRACK", [y, valueRow, x, ~trackParamCol, ~selectedParam, ~paramPage]);
            if(y == valueRow && (x != ~trackParamCol)) {
                var valIdx = ~valueIdxForCol.(x, ~trackParamCol);
                ~fdbg.("TRK2", [valIdx, x, ~trackParamCol]);
                if(valIdx.notNil) {
                    var curPos, isSample = (~selectedParam == 0 && (~paramPage == 0));
                    if(isSample) {
                        var firstVal = ~tracks[~trackParamTrack][\steps][0][\sample];
                        curPos = firstVal.asInteger;
                    } {
                        var curVal = ~tracks[~trackParamTrack][\steps][0][paramNames[~selectedParam]];
                        curPos = ~positionForValue.(~paramPage, ~selectedParam, curVal);
                    };
                    ~fdbg.("TRK3", [valIdx, curPos, isSample, valIdx == curPos]);
                    if(valIdx == curPos) {
                        if(isSample or: { ~paramHasFine.(~paramPage, ~selectedParam) }) {
                        ~fdbg.("TRK ENTER", nil);
                            ~fineActive = true;
                            ~fineContext = \track;
                            ~fineParamPage = ~paramPage;
                            ~fineParamIdx = ~selectedParam;
                            ~fineTrackIdx = ~trackParamTrack;
                            ~latchActive = true;
                            ~startPulseRoutine.();
                            "[Gladiola] Fine fader opened (track)".postln;
                            ~updateGridLEDs.();
                        };
                    };
                };
            };
        };
        if(~fineActive.not && ~utilityOverlayActive && (~utilityOverlayType == \fxMatrix)) {
            if(~fxModActive == true) {
                // FX Mod detail hold handler
                if(x == 0 && (y == 7)) {
                    // Already in mod detail — ignore
                };
                if(x >= 4 && (x <= 15) && (y < 7)) {
                    var destIdx = x - 4;
                    if(~fxPhaseEditActive[destIdx]) {
                        // Hold on phase fader → fine fader for phase
                        var phase = ~fxModSettings[\phases][destIdx];
                        var phaseRow = ~phaseRowForValue.(phase);
                        if(y == phaseRow) {
                            ~fineActive = true;
                            ~fineContext = \fxModPhase;
                            ~fineModDest = destIdx;
                            ~latchActive = true;
                            ~startPulseRoutine.();
                            "[Gladiola] FX mod phase fine fader (%)".format(~fxModDestKeys[destIdx]).postln;
                            ~updateGridLEDs.();
                        };
                    } {
                        // Hold on depth fader → fine fader for depth
                        var depth = ~fxModSettings[\depths][destIdx];
                        var depthRow = ~modRowForDepth.(depth);
                        if(y == depthRow) {
                            ~fineActive = true;
                            ~fineContext = \fxModDepth;
                            ~fineModDest = destIdx;
                            ~latchActive = true;
                            ~startPulseRoutine.();
                            "[Gladiola] FX mod depth fine fader (%)".format(~fxModDestKeys[destIdx]).postln;
                            ~updateGridLEDs.();
                        };
                    };
                };
                if(x >= 4 && (x <= 15) && (y == 7)) {
                    // Hold on row 7 polarity key → enter phase edit
                    var destIdx = x - 4;
                    if(~fxPolarityPending == destIdx) {
                        ~fxPhaseEditActive[destIdx] = ~fxPhaseEditActive[destIdx].not;
                        "[Gladiola] FX mod phase edit % -> %".format(~fxModDestKeys[destIdx], ~fxPhaseEditActive[destIdx]).postln;
                        ~fxPolarityPending = nil;
                        ~updateGridLEDs.();
                    };
                };
            } {
                // Main FX page hold handler
                if(x == 0 && (y == 7)) {
                    // Hold on col 0 row 7 → enter mod detail
                    ~fxShapePending = nil;
                    ~fxModActive = true;
                    ~latchActive = true;
                    ~startPulseRoutine.();
                    "[Gladiola] FX mod detail opened.".postln;
                    ~updateGridLEDs.();
                };
                if(x >= 1 && (x <= 9) && (y < 7)) {
                    // Hold on Clouds fader → fine fader
                    var key = ~fxCloudsKeys[x - 1];
                    var currentRow = ~fxCloudsPositionForValue.(key, ~fxCloudsParams[key]);
                    if(y == currentRow) {
                        ~fineActive = true;
                        ~fineContext = \fxClouds;
                        ~fineFxCol = x - 1;
                        ~latchActive = true;
                        ~startPulseRoutine.();
                        "[Gladiola] Fine fader opened (Clouds %)".format(key).postln;
                        ~updateGridLEDs.();
                    };
                };
                if(x >= 11 && (x <= 15) && (y < 7)) {
                    // Hold on master bus fader → fine fader
                    var key = ~fxMasterKeys[x - 11];
                    if(~fxMasterHasFine.(key)) {
                        var currentRow = ~fxMasterPositionForValue.(key, ~fxParams[key]);
                        if(y == currentRow) {
                            ~fineActive = true;
                            ~fineContext = \fxMaster;
                            ~fineFxCol = x - 11;
                            ~latchActive = true;
                            ~startPulseRoutine.();
                            "[Gladiola] Fine fader opened (Master %)".format(key).postln;
                            ~updateGridLEDs.();
                        };
                    };
                };
            };
        };
        if(~fineActive.not && ~transportHeld) {
            ~fdbg.("MIX", [x, y]);
            if(x >= 9 && (x <= 15) && (y < 8)) {
                var trackIdx = x - 9;
                var curRow = ~mixerPosForVolume.(~trackVolumes[trackIdx]);
                ~fdbg.("MIX2", [trackIdx, curRow, y, y == curRow]);
                if(y == curRow) {
                    ~fineActive = true;
                    ~fineContext = \mixer;
                    ~fineMixerTrack = trackIdx;
                    ~latchActive = true;
                    ~startPulseRoutine.();
                    "[Gladiola] Fine fader opened (mixer track %)".format(trackIdx).postln;
                    ~updateGridLEDs.();
                };
            };
        };
        if(~fineActive.not && ~lfoModActive && ~lfoModTrack.notNil) {
            ~fdbg.("MOD", [x, y]);
            if(x >= 2 && (x <= 15) && (y < 7)) {
                var destIdx = x - 2;
                if(~phaseEditActive[destIdx]) {
                    // Fine fader for phase
                    var phase = ~trackModSettings[~lfoModTrack][\phases][destIdx];
                    var phaseRow = ~phaseRowForValue.(phase);
                    if(y == phaseRow) {
                        ~fineActive = true;
                        ~fineContext = \modPhase;
                        ~fineModDest = destIdx;
                        ~fineTrackIdx = ~lfoModTrack;
                        ~latchActive = true;
                        ~startPulseRoutine.();
                        "[Gladiola] Fine fader opened (phase %)".format(~modDestKeys[destIdx]).postln;
                        ~updateGridLEDs.();
                    };
                } {
                    // Fine fader for depth
                    var depth = ~trackModSettings[~lfoModTrack][\depths][destIdx];
                    var depthRow = ~modRowForDepth.(depth);
                    ~fdbg.("MOD2", [destIdx, depthRow, y, y == depthRow]);
                    if(y == depthRow) {
                        ~fineActive = true;
                        ~fineContext = \modDepth;
                        ~fineModDest = destIdx;
                        ~fineTrackIdx = ~lfoModTrack;
                        ~latchActive = true;
                        ~startPulseRoutine.();
                        "[Gladiola] Fine fader opened (mod %)".format(~modDestKeys[destIdx]).postln;
                        ~updateGridLEDs.();
                    };
                };
            };
            if(x >= 2 && (x <= 15) && (y == 7)) {
                // Hold on polarity key — toggle phase edit mode
                var destIdx = x - 2;
                if(~polarityPending == destIdx) {
                    if(~destHasPhase.(destIdx)) {
                        ~phaseEditActive[destIdx] = ~phaseEditActive[destIdx].not;
                        "[Gladiola] LFO % phase edit -> %".format(~modDestKeys[destIdx], ~phaseEditActive[destIdx]).postln;
                    };
                    ~polarityPending = nil;
                    ~updateGridLEDs.();
                };
            };
        };
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
        };
    });

    ~grid.release({ |x, y|
        if(~fineActive == true) {
            // Auto-latched, release does nothing
        } {
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
                    ~condEditMode = false;
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
                    ~lfoFrozenVal = nil;
                    if(~lfoSynths.notNil) { if(~lfoSynths[~lfoModTrack].notNil) {
                        ~lfoSynths[~lfoModTrack].set(\freeze, 0)
                    } };
                    "[Gladiola] LFO hold released".postln;
                    ~updateGridLEDs.();
                };
                if(x >= 2 && (x <= 15) && (y == 7)) {
                    // Deferred polarity toggle or phase exit (hold didn't fire)
                    var destIdx = x - 2;
                    if(~polarityPending == destIdx) {
                        if(~phaseEditActive[destIdx]) {
                            // Tap exits phase mode (no polarity toggle)
                            ~phaseEditActive[destIdx] = false;
                            "[Gladiola] LFO % phase edit off".format(~modDestKeys[destIdx]).postln;
                        } {
                            // Normal polarity toggle
                            var ms = ~trackModSettings[~lfoModTrack];
                            var newPol = ms[\polarities][destIdx].neg;
                            ms[\polarities][destIdx] = newPol;
                            if(ms[\depths][destIdx] > 0) {
                                ~setModDepth.(~lfoModTrack, destIdx, ms[\depths][destIdx], newPol);
                            };
                            "[Gladiola] LFO % polarity -> %".format(~modDestKeys[destIdx], if(newPol > 0) { "+" } { "-" }).postln;
                        };
                        ~polarityPending = nil;
                        ~updateGridLEDs.();
                    };
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
                if(~utilityOverlayActive && (~utilityOverlayType == \fxMatrix)) {
                    // FX-specific release handlers
                    if(~fxModActive == true) {
                        if(x == 1 && (y == 7)) {
                            // Release hold
                            ~fxLfoHoldActive = false;
                            ~fxLfoFrozenVal = nil;
                            if(~fxLfoSynth.notNil) { ~fxLfoSynth.set(\freeze, 0) };
                            "[Gladiola] FX LFO hold released.".postln;
                            ~updateGridLEDs.();
                        };
                        if(x >= 4 && (x <= 15) && (y == 7)) {
                            var destIdx = x - 4;
                            if(~fxPolarityPending == destIdx) {
                                if(~fxPhaseEditActive[destIdx]) {
                                    // Tap exits phase mode (no polarity toggle)
                                    ~fxPhaseEditActive[destIdx] = false;
                                    "[Gladiola] FX mod phase edit % off".format(~fxModDestKeys[destIdx]).postln;
                                } {
                                    // Normal polarity toggle
                                    var newPol = ~fxModSettings[\polarities][destIdx].neg;
                                    ~setFxModDepth.(destIdx, ~fxModSettings[\depths][destIdx], newPol);
                                    "[Gladiola] FX mod polarity % -> %".format(~fxModDestKeys[destIdx], newPol).postln;
                                };
                                ~fxPolarityPending = nil;
                                ~updateGridLEDs.();
                            };
                        };
                    } {
                        if(x == 0 && (y == 7) && ~fxShapePending.notNil) {
                            // Shape cycle (hold didn't fire → mod detail)
                            var newShape = (~fxModSettings[\shape] + 1) % 7;
                            ~setFxModShape.(newShape);
                            ~fxShapePending = nil;
                            "[Gladiola] FX LFO shape -> %".format(~modShapeNames[newShape]).postln;
                            ~updateGridLEDs.();
                        };
                    };
                };
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
                                ~fxModActive = false;
                                ~fxPhaseEditActive = Array.fill(12, { false });
                                ~fxPolarityPending = nil;
                                ~fxLfoHoldActive = false;
                                ~fxLfoFrozenVal = nil;
                                ~fxShapePending = nil;
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
            if(~fineActive.not && ~utilityOverlayActive.not && ~paramMenuActive.not && ~trackParamActive.not && ~lfoModActive.not && ~lengthModalTrack.isNil && ~transportHeld.not && (~lastOverlayCloseTime.isNil || { (Main.elapsedTime - ~lastOverlayCloseTime) > 0.3 })) {
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

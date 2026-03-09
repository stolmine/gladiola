# gladiola - todo

## done

- [x] sample playback SynthDef (\gladiolaSample) with pitch, velocity, loop length/region, ratchet
- [x] recursive sample directory scanning (filesDo) with subdirectory/random/sequential modes
- [x] sample bank system (16 banks × 15 samples = 240 samples)
- [x] mono buffer loading (Buffer.readChannel, channel 0)
- [x] GridInterface class (shared with griddlecake, in Extensions)
  - serialosc handshake (/sys/port, /sys/host, /sys/prefix)
  - oscgrid support
  - hold detection (0.5s), double-tap (0.25s), release callbacks
  - LED buffering with dirty flag, 30fps refresh
- [x] 7-track × 16-step sequencer (rows 0-6), utility row (row 7)
- [x] per-step state: on/off, bank, sample, pitch, velocity, loopLength, loopRegion, ratchet, randomness, gateLength, reverse, filter, pan, probability, delaySend, bitcrush
- [x] per-track start/end step with wrap-around (polymetric/offset patterns)
- [x] double-tap any step to set start point, then select end point
- [x] clock/tempo with TempoClock, 16th note default
- [x] randomness meta-mutator (per-read parameter mutation)
- [x] hold-to-reveal parameter overlay with column/row selection
- [x] two-page param system (page 1: bank/pitch/velocity/loop/ratchet/randomness, page 2: gateLength/reverse/filter/pan/probability/delaySend/bitcrush)
- [x] page toggle at (3,7) on utility row during param overlay
- [x] 7th param uses row 7 as overflow during overlay
- [x] deferred toggle (press sets pending, release commits, hold cancels)
- [x] param menu persists until held button released
- [x] serialosc auto-detect via ~connectSerialosc
- [x] main.scd boot with modular file loading
- [x] active steps display velocity via LED brightness (dim→medium range)
- [x] live tempo change via ~setTempo (updates TempoClock in place)
- [x] live clock division change via ~setClockDiv (hold col 1 row 7, vertical overlay)
- [x] live delay division change via ~setDelayDiv (hold col 2 row 7, vertical overlay)
- [x] global transpose (hold col 4 row 7, vertical overlay: -oct5th to +oct5th)
- [x] gate envelope with range from 1/16 step to full sustain (15 exponential values)
- [x] reverse sample playback per step
- [x] bipolar filter per step (negative=lowpass, positive=highpass)
- [x] per-step pan control
- [x] per-step probability (step fires based on coin flip)
- [x] per-step delay send amount
- [x] per-step bitcrush effect
- [x] full FX chain: delay (CombC + tone filter), granular (MiClouds), reverb (Greyhole), saturation (softclip/tanh/fold), tilt EQ, compressor, limiter
- [x] FX matrix overlay (hold col 2 row 7): 16×7 grid, one column per FX parameter, instant control
- [x] per-track clock division (hold col 1 row 7): 7×7 grid, independent timing per track
- [x] transport start/stop on (0,7), double-tap for panic (silence all voices)
- [x] per-track mute toggles on (9-15, 7)
- [x] bank brightness indicator on param column
- [x] playhead LED clearly brighter than active steps
- [x] grid split into grid_params.scd, grid_leds.scd, grid_input.scd
- [x] 4-slot preset system (cols 5-8 row 7): tap to recall, hold to save, double-tap to clear — superseded by 49-slot matrix
- [x] presets capture full state: steps, params, start/end, mutes, clockDiv, delayDiv, transpose, globalReverse
- [x] global reverse toggle (col 3 row 7): XOR inversion of per-step reverse settings
- [x] input mutex system: modal guards on doubleTap handler block length modal/preset clear during overlays
- [x] preset coordinate tracking (~presetHeldX) prevents wrong-slot recall on slide
- [x] undo-toggle scoped to ~stepInRange to prevent out-of-range step corruption
- [x] step copy/paste: copy params from held step (C button), paste into off steps (hold)
- [x] dynamic overlay action buttons (P=page toggle, C=copy) positioned relative to held step
- [x] removed fixed page toggle at (3,7)/(4,7) — row 7 now full param selector during overlay
- [x] session manager (session.scd): save/load/new sessions as .gladiola archives in ~/gladiola-sessions/
- [x] session GUI: BPM display, sample dir display, stereo level meters, New/Save/Save As/Load buttons
- [x] sessions capture: tracks, presets, BPM, clockDiv, delayDiv, transpose, globalReverse, sampleDir
- [x] tempo nudge mode: hold transport (0,7) 500ms → column 0 rows 0-6 become ±10/±5/±1/reset BPM buttons
- [x] Server.sync after ~freeSamples in sample_loader.scd to prevent buffer exhaustion on session load
- [x] ~basePath stored globally in main.scd; ~sessionsDir set to ~/gladiola-sessions/ with auto-create
- [x] session GUI auto-opens on boot
- [x] double-tap transport panic kills FX tails (frees and recreates send FX synths)
- [x] step audition: A button in param overlay toggles auto-preview on param changes (transport stopped only)
- [x] granular (MiClouds) improvements: 1.5× input boost, step-triggered S&H modulation via Latch.kr, user-controllable mod depth (\granModDepth param)
- [x] loop length changed from buffer-relative to step-relative (clock-scaled): 0=one-shot, 1/16-1.0=sub-step fractions, 2/4/8=multi-step loops
- [x] session GUI: Grid connection button + live status indicator
- [x] 49-slot preset matrix overlay (7×7) replacing 4-slot system: hold populated preset button to open matrix, select/save/clear slots, confirm mode, quantized switching (fires on longest-pattern wrap)
- [x] preset utility LEDs differentiate active (full) vs populated-not-active (medium) vs empty (off)
- [x] double-tap preset clear removed (clearing via matrix overlay only)
- [x] fixed preset matrix overlay LED rendering: extra `};` brace broke if/else structure in grid_leds.scd, preventing overlay LEDs from displaying
- [x] fixed quantized preset switching: wrap detection now works for all pattern lengths including full 0-15, not just sub-ranges
- [x] fixed utility row preset lighting: replaced per-button ~lastRecalledSlot with single ~activePresetButton; only most-recently-recalled slot shows full brightness
- [x] removed auto-recall on overlay release: closing preset matrix overlay remaps button only; user taps to recall
- [x] pulse animation for queued presets and armed save/clear buttons in matrix overlay (dim→full→dim instead of flash)
- [x] granular FX rework: per-parameter S&H mod depth (size, position, pitch) replacing single modDepth + direct control; pitch quantized to musical intervals (±fifth, ±octave, ±oct+fifth)
- [x] pulse animation rate synced to 1/4 slowest pattern period (clock-derived phase instead of per-call increment)
- [x] preset clear resets activePresetButton when clearing mapped slot; matrix shows empty-selected as medium instead of full
- [x] per-step sub-sequencing: 3×3 grid of up to 9 sub-steps per step, override/inherit model, cycle on parent step fire
  - sub-step toggle (tap), edit mode (hold to enter, tap to exit with pulse animation), double-tap to clear overrides
  - 4-brightness LED levels (full=active+overrides, medium-high=active+inherit, medium=inactive+overrides, dim=empty)
  - contiguous row placement including row 7, dynamic repositioning when selectedParam changes
  - backward-compatible session/preset migration for old data
  - deep copy support for step copy/paste with sub-step data
- [x] fixed transpose hold: holding col 4 now only opens the overlay; tap (deferred to release) performs the swap — hold no longer fires both
- [x] fixed queued preset immediate recall: tapping an already-queued preset in quantized mode cancels the queue and recalls immediately
- [x] fixed preset timing: longestPatternTrack computes duration (steps × clockDiv) not raw step count; quantized recall uses deferred scheduling with handoff delay so the last step plays fully; all tracks reset to startStep on recall
- [x] fixed sub-step hold detection: active sub-step toggle deferred to release so holding enters edit mode rather than toggling off
- [x] fixed mute silences voice: muting a track immediately sets amp=0 on the running voice, stopping long gates and looping sounds
- [x] overlay layout refactor: replaced ad-hoc single-column action buttons and separate sub-grid positioning with unified ~overlayLayout function
  - sub-seq and action 3×3 grids placed side-by-side on same rows, far side from held step
  - action grid uses corner keys: page (TL), copy (TR), audition (BL), latch (BR)
  - fixed column positions per side: steps 0-7 use cols 9-11 + 13-15, steps 8-15 use cols 0-2 + 4-6
  - minimax row scoring maximises gap from value row only (heldTrack not considered occupied)
  - post-placement nudge (±1 or ±2 rows) with sum-of-distances tiebreaker
  - fallback allows value row overlap when no block avoids it (grids overwrite cosmetically)
- [x] latch key: keeps param overlay open after releasing held step, pulses when engaged
- [x] pulse animation routine (~startPulseRoutine/~stopPulseRoutine): 20fps AppClock refresh drives latch and sub-step edit pulse indicators even when transport is stopped
- [x] fixed SC && non-short-circuit crash: step[\subActive][subIdx] evaluated even when subIdx was nil; changed to nested if
- [x] quantized preset switching bypasses queue when transport is stopped (instant recall, setting preserved for playback)
- [x] session manager quit button with confirmation dialog: stops transport, silences voices, kills FX tails, clears/frees grid, quits server
- [x] three-state copy key LED in param overlay: dim = clipboard empty, subtle glow (6) = clipboard populated but differs from held step, bright (12) = clipboard matches held step; scalar params compared via ~clipboardMatchesStep helper (array types skipped)
- [x] fixed audition during sub-step editing: ~previewStep now resolves params through ~resolveSubStepParam when ~subStepEditing is active, matching sequencer playback
- [x] latch keys for global overlays: transport (1,7), clockDiv (2,7), FX matrix (3,7), transpose (5,7), and preset overlays (6-9,7) can be latched open via key one column right of held button on row 7; latch pulses when engaged, dim when available
- [x] kill FX tails button on transport hold page at (2,7): tap to immediately free and recreate send FX synths
- [x] fixed preset save to mapped slot: holding a preset button mapped to an empty slot now saves to the mapped slot instead of resetting to the button's default slot
- [x] fixed gate length max: replaced 100 sentinel ("full sustain") with 16 steps (one full pattern cycle), clock-relative to track division — eliminates runaway sample playback
- [x] per-track global overlay rework: uses ~overlayLayout instead of ad-hoc ~trackOverlayPagePos; action grid (page/slice stub/audition/latch corners + mod stub center) and phantom sub-step grid (center = clear with two-tap confirm via ~trackClearArmed); latch keeps overlay open after release; value row collision avoidance; audition preview on param change when transport stopped
- [x] double-tap guard after step overlay close: records ~lastOverlayCloseTime on overlay release, double-tap handler checks 300ms cooldown to prevent false triggers
- [x] bitcrush value curve: replaced linear pos/14.0 mapping with 15-value lookup table (approx quadratic curve), effect noticeable from position 2-3 onward
- [x] compressor scaling: raised threshold floor (0.3), stronger ratio (8:1), wider attack (5ms-300ms) and release (30ms-1.5s) ranges, added auto makeup gain via thresh.reciprocal.pow(1 - ratio)
- [x] saturation redesign: 7 discrete types (fold, tanh, softclip, hard clip, sqrt, rectify, quantize) replacing 3-type crossfade; baked-in DC offset (0.05) for asymmetric harmonic character with LeakDC cleanup; satType value table now integer indices 0-6

## per-track global overlay rework

Reworked from simple hold-to-open param editor to proper track control surface using ~overlayLayout. Action grid always on left (cols 4-6) since track mute keys are cols 9-15.

### overlay structure (done)
- [x] action grid keys: page toggle (TL), slice stub (TR), audition (BL), latch (BR), mod stub (center)
- [x] latch via action grid corner key (BR), keeps overlay open after mute key release
- [x] page toggle via action grid corner key (TL)
- [x] clear track via phantom sub-step grid center cell — two-tap confirmation (~trackClearArmed)
- [x] value row collision avoidance with action/sub grid cells
- [x] audition preview on param change when transport stopped

### per-track LFO modulation system
- one LFO per track, available to all 14 param destinations via mod depth faders
- motivation: per-step/sub-step editing is powerful but surgical and local; need movement over time at the *track* level without manual intervention
- UI: tap modulation key in per-track global action grid
  - blocking overlay with 14 depth faders (cols 2-15) + shape/rate controls (cols 0-1)
  - auto-latched on entrance, lower-left key pulses and user hits it to exit
  - depth fader layout per column:
    - rows 0-5: depth levels 6-1 (expo curve, row 0 = max depth)
    - row 6: zero (no modulation)
    - row 7: polarity toggle (solid = positive, pulse = negative)
    - full brightness at current position, dim elsewhere; polarity toggle independent of depth value
  - left two columns reserved for shape and rate:
    - col 0: 7 shapes — sine (default), square, triangle, brownian, full random, saw up, saw down
    	- currently selected notch can give visual feedback regarding state: sine smoothly pulses, square flashes on/off, etc, we should be able to map actual rate to animation
    - col 0,row 7 (currently unoccupied) could be a momentary hold or a reset. i am partial to hold myself, should be released if still on when leaving page
    - col 1: rate as nudge in 16ths — buttons for +16, +4, +1, center at 1 bar (16/16), -1, -4, -16; allows odd timings for polyrhythmic drift
- modulation behavior:
  - LFO offsets from each step's current value (per-step settings are the offset control)
  - continuous params interpolate smoothly (not restricted to step overlay 15 notch selector layouts); discrete params (sample, ratchet, reverse) use sample-and-hold per trigger
  - bank excluded as destination
  - values clamp at param min/max (no wrapping)
  - modulation takes priority over per-step values (step values set initial offset, LFO adds movement on top)
  - param order matches step overlay page 1 + page 2 for memorability
- implementation: one LFO synth per track → control bus, read by sample_voice SynthDef with 14 mod depth args (verbose but lightweight); params stored as floats so continuous interpolation is straightforward

### sample slice mode
- toggle slice mode on in per-track global action grid
- locks all steps on track to selected sample (slices by equal division, 16 slices; whatever is simplest and fastest)
- sample selection inside per-track global (requires auditioning in this overlay)
- step overlay sample bank chooser disabled in slice mode; user chooses from 16 slices per step instead
- time stretching is prerequisite for this to be useful

### time stretching
- per-track toggle, lives in per-track global overlay; prerequisite for slicing
- how would this work when not in slice mode with a locked sample? would everything just get stretched? a problem to consider

## roadmap

### phase 1 — bug fixes and quick wins (no architectural changes) ✓
- [x] pitch param ordering — fixed, array reordered ascending
- [x] double-tap guard after overlay close
- [x] bitcrush value curve
- [x] compressor scaling
- [x] saturation redesign

### phase 2 — undo system (abandoned)
- undo requires deferring transport toggle past the double-tap window to disambiguate single-tap (transport) from double-tap (undo)
- minimum viable deferral (~85ms) still allows 1-2 steps to fire before transport stops, and adds perceptible latency to transport start — unacceptable for live performance
- single-layer undo has limited value when the grid provides full visual state feedback; user can manually revert any change in the same number of gestures
- optimistic execute + rollback was attempted but rollback still arrives too late (audible transport blip)

### phase 3 — per-track global overlay rework ✓
- [x] overlay structure — uses ~overlayLayout for layout (action grid 3x3 with corners + center, phantom sub grid for clear). track keys always on right so grids always on left.
- [x] audition in track overlay — audition toggle in action grid (BL corner), preview on param change when transport stopped
- [x] clear track with confirmation — center cell of phantom sub grid, two-tap arm/confirm via ~trackClearArmed
- [x] latch support — action grid BR corner, engage keeps overlay open after release, disengage closes it
- [x] value row collision avoidance with action/sub grid cells

foundation for phases 4 and 5. get solid and tested before building on top.

### phase 4 — param page reorg + new params
- [ ] decide replacement params — attack and filter resonance are strongest candidates
	- if we are going forward with mod system we can nix randomization altogether, it won't be necessary and will in fact just be very coarse compared to mod system
	- what can we replace it with that we are currently missing?
		- Filter could be given resonance
		- we could have ratchet start and ratchet end, interpolate between values for interesting rolls, but over the course a single step? idrk
		- what else?
		- pitch EG? this would require two selectors to be useful tho
		- attack? this could be quite useful on a single selector
		- slew rate? this could be really fun, but it makes little sense
			- what i envision is that this is set per step and determines how long it takes for given step to assume its own params. maybe this would be better per track than per step, but i think it could be fun either way. discrete things like reverse and sample selection could not be slewed, obv
			- also would not make much sense when dealing with 16ths that have one step of gate length
		- anything else I am not thinking of?
- [ ] reorg pages — filter, pan, gate length to page 1; looping, ratchet to page 2. drop randomness.
- [ ] add new params — attack envelope time and/or filter resonance to SynthDef, value tables, overlay rendering
- [ ] session migration — ensure old sessions/presets load with sensible defaults for new params

bundle as one breaking change. after overlay rework so track overlay has new structure. before mod system so it targets the final param set.

### phase 5 — LFO modulation system
- [ ] LFO SynthDef — one per track, outputting to control bus. shape selection, rate in 16ths.
- [ ] voice SynthDef integration — 14 mod depth args reading from control bus, applying offset to step values, clamping. S&H for discrete params.
- [ ] mod overlay UI — blocking page from track overlay action grid. 14 depth faders, polarity toggles, shape/rate columns, shape-animated LED feedback, hold key, auto-latch.
- [ ] preset/session persistence — mod settings per track saved and recalled

biggest single feature. SynthDef work and UI work can be developed somewhat in parallel.

### phase 6 — fine fader view
- [ ] fine fader infrastructure — hold-to-reveal full-grid selector, 127-128 positions, latch key, center dent rendering
- [ ] integrate across all contexts — step overlay, track overlay, transport, FX, mod page
  - respects parent page's latch and audition status
  - interaction flow (step/track overlays):
    - user enters overlay → holds param selector button in column → detail fader opens
    - 127 or 128 choices across the full grid
    - latch key at (0,0) or (0,7) for iterating by ear
    - if latch off: select value → page closes → return to parent overlay (if latched) or main screen (if unlatched)
    - if latch on: select value → page stays open for further adjustment
    - coarse fader on parent page shows closest-fit representation of fine value
  - center dents represented in fine view for params that have them (filter, pan)
  - discrete params (reverse, bank) excluded; only continuous values get fine view

do after everything else — universal enhancement that touches every overlay, easier once all overlays are in final form.

### phase 7 — time stretch + slicing (longest horizon)
- [ ] time stretch SynthDef — per-track toggle, figure out behavior outside slice mode
- [ ] slice mode — toggle in track overlay, lock sample, 16 equal divisions, step overlay shows slice selection instead of bank/sample

most open design questions and heaviest DSP work. save for last.

### unsequenced (implement whenever)
- [ ] clock sync (MIDI clock, Link)
- [ ] audio output routing options (bus selection)
- [ ] legato mode for preset switching: start presets from the same position the previous one was at instead of resetting to start, given instant switching is enabled (clock div interpolation would be goofy but worth a try)
- [ ] add record button to session manager

## abandoned
- [0] groove templates (swing is implemented; templates would be preset swing curves beyond linear)
- [0] copy/paste step regions (multi-step copy) - given we have no facility for selecting multiple steps i think we forget this one
- [0] pattern chaining / song mode - i think we will stick to manual preset switching
- [0] per-track sample lock (all steps in a track share one sample) - already accomplished with global track overlays
- [0] FX volumes to transport hold page - conceptually wrong grouping; FX levels belong with FX matrix, transport is for global performance controls; 3 reclaimed FX columns aren't valuable enough

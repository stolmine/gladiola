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
- [x] tempo-synced delay (CombC with configurable division)
- [x] transport start/stop on (0,7), double-tap for panic (silence all voices)
- [x] per-track mute toggles on (9-15, 7)
- [x] bank brightness indicator on param column
- [x] playhead LED clearly brighter than active steps
- [x] grid split into grid_params.scd, grid_leds.scd, grid_input.scd
- [x] 4-slot preset system (cols 5-8 row 7): tap to recall, hold to save, double-tap to clear
- [x] presets capture full state: steps, params, start/end, mutes, clockDiv, delayDiv, transpose, globalReverse
- [x] global reverse toggle (col 3 row 7): XOR inversion of per-step reverse settings
- [x] input mutex system: modal guards on doubleTap handler block length modal/preset clear during overlays
- [x] preset coordinate tracking (~presetHeldX) prevents wrong-slot recall on slide
- [x] undo-toggle scoped to ~stepInRange to prevent out-of-range step corruption
- [x] step copy/paste: copy params from held step (C button), paste into off steps (hold)
- [x] dynamic overlay action buttons (P=page toggle, C=copy) positioned relative to held step
- [x] removed fixed page toggle at (3,7)/(4,7) — row 7 now full param selector during overlay

## ideas

- [ ] time stretching infrastructure for loop/break support
- [ ] pattern save/load (persist to disk)
- [ ] copy/paste step regions (multi-step copy)
- [ ] swing / groove templates
- [ ] clock sync (MIDI clock, Link)
- [ ] audio output routing options (bus selection)
- [ ] pattern chaining / song mode
- [ ] sample slice mode (auto-chop breaks)
- [ ] delay feedback / mix controls on utility row
- [ ] per-track sample lock (all steps in a track share one sample)

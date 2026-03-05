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
- [x] gate envelope with range from 1/16 step to full sustain
- [x] reverse sample playback per step
- [x] bipolar filter per step (negative=lowpass, positive=highpass)
- [x] per-step pan control
- [x] per-step probability (step fires based on coin flip)
- [x] per-step delay send amount
- [x] per-step bitcrush effect
- [x] tempo-synced delay (CombC with configurable division, hold col 2 row 7)
- [x] transport start/stop on (0,7)
- [x] per-track mute toggles on (9-15, 7)
- [x] bank brightness indicator on param column
- [x] playhead LED clearly brighter than active steps
- [x] grid split into grid_params.scd, grid_leds.scd, grid_input.scd

## ideas

- [ ] time stretching infrastructure for loop/break support
- [ ] pattern save/load (persist to disk)
- [ ] copy/paste steps or regions
- [ ] swing / groove templates
- [ ] clock sync (MIDI clock, Link)
- [ ] audio output routing options (bus selection)
- [ ] pattern chaining / song mode
- [ ] sample slice mode (auto-chop breaks)
- [ ] delay feedback / mix controls on utility row
- [ ] per-track sample lock (all steps in a track share one sample)

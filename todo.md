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
- [x] 128-step chaselight sequencer (left→right, top→bottom)
- [x] per-step state (on/off, bank, sample, pitch, velocity, loopLength, loopRegion, ratchet, randomness)
- [x] adjustable pattern length (double-tap top-left modal)
- [x] clock/tempo with TempoClock, 16th note default
- [x] randomness meta-mutator (per-read parameter mutation)
- [x] hold-to-reveal parameter menu with column/row selection
- [x] deferred toggle (press sets pending, release commits, hold cancels)
- [x] param menu persists until held button released
- [x] serialosc auto-detect via ~connectSerialosc
- [x] main.scd boot with modular file loading

## bugs

- [ ] steps trigger one step late — check if we advance ~currentStep before or after triggering (should trigger then advance, not advance then trigger)

## next

- [ ] active steps should display velocity via LED brightness (map velocity to brightness range)

## remaining

- [ ] time stretching infrastructure for loop/break support
- [ ] audio output routing options (bus selection)
- [ ] pattern save/load (persist to disk)
- [ ] multi-voice support (more than one simultaneous sample voice)
- [ ] copy/paste steps or regions
- [ ] swing / groove templates
- [ ] per-step pan control
- [ ] visual feedback: brightness variation for velocity/parameter values in normal mode
- [ ] clock sync (MIDI clock, Link)

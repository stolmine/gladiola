# Gladiola Documentation Index

A 7-track groovebox for monome grid, powered by SuperCollider.

## Documentation

| File | Description |
|------|-------------|
| [manual.md](manual.md) | User manual — grid layout, controls, parameters, functions |
| [todo.md](todo.md) | Feature tracking — completed work and future ideas |

## Source Files

| File | Purpose |
|------|---------|
| `main.scd` | Boot sequence, file loading, grid connection, session auto-open; calls ~cleanup before re-init for safe re-evaluation |
| `sequencer.scd` | 7-track sequencer engine, transport, presets, clock |
| `synthdefs/sample_voice.scd` | Sample playback SynthDef |
| `synthdefs/fx_chain.scd` | FX chain SynthDefs (MiClouds, saturation, tilt EQ, compressor, limiter) |
| `fx_params.scd` | FX parameter definitions, value tables, lookup functions |
| `sample_loader.scd` | Bank-based sample loading (16 banks × 15 samples) |
| `grid_params.scd` | Parameter definitions, value tables, mapping, sub-step resolution helpers |
| `grid_leds.scd` | LED rendering for all display modes |
| `grid_input.scd` | Grid input handling — 8 extracted key handlers with flat case dispatch, gesture recognition, modal state |
| `session.scd` | Session save/load/new, GUI window with metering, recording, and quit button |
| `synthdefs/lfo.scd` | Per-track LFO SynthDefs (one per track, outputting to control bus) |
| `lfo_params.scd` | LFO parameter definitions, mod depth tables, shape/rate helpers, phase offset helpers |

## Key Features

- 7 tracks × 16 steps with per-step parameters (2 pages, 14 params) and per-step sub-sequencing (up to 9 sub-steps per step)
- Hold-to-reveal parameter overlay with bank/sample selection, latch mode for hands-free editing
- Step copy/paste via side-by-side sub-seq and action grids (3×3 each, same rows, far side from held step)
- 49-slot preset matrix with confirm mode and quantized switching
- Global reverse toggle (XOR with per-step reverse)
- Clock division, FX matrix, and transpose overlays, each with a latch key (one column right on row 7) to lock the overlay open hands-free
- Transport hold page: hold transport 500ms for BPM nudge, swing nudge, kill FX tails, and VU meters; latched via (1, 7)
- Session manager: save/load/new sessions as `.gladiola` archives with GUI, stereo metering, and audio recording
- Session GUI with grid connection button, live status, and record toggle (AIFF int24 to SC default recordings directory)
- Full FX chain: single expanded MiClouds instance (9 continuous params + freeze/mode/lofi toggles + auto-trigger), feeding into saturation (7 types: fold/tanh/softclip/hard clip/sqrt/rectify/quantize), tilt EQ, compressor with auto makeup gain, limiter; FX page has dedicated LFO with 12 mod destinations, per-destination phase offsets, and full blocking mod detail overlay
- Per-step bitcrush, bipolar filter, pan, probability
- Clock-relative loop lengths (scales with tempo and clock division)
- Start/end points with wrap-around for polymetric patterns
- Per-track "macro" parameter overlay via mute key hold (apply params to all steps at once) with action grid (page, slice toggle, audition, latch, mod key), clear track (two-tap confirm), and audition preview; mod key opens the LFO overlay and shows medium brightness when the track has active modulation
- Per-track slice mode: S key in track overlay divides buffer into 16 equal slices; per-step sliceIdx selects which slice plays via BufRd repitch; LFO sample mod modulates sliceIdx in slice mode; sweep-based gate prevents looping on both slice and normal paths; persisted per preset and session
- Per-track LFO modulation system: one tempo-synced LFO per track with 7 shapes, rate in 1-128 sixteenths, and 14 per-destination depth faders with polarity toggles and per-destination phase offsets (±180° via DelayC.kr); slink visualization shows full bipolar LFO travel with per-destination phase shift; hold key freezes LFO and slink; mod settings saved per preset and session
- Per-step conditional playback: deterministic "fire on pass N of every M" gating, stackable with probability; double-tap probability selector to toggle conditional edit mode with split N/M value row
- Input mutex system preventing gesture conflicts across modal states

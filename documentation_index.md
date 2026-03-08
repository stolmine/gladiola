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
| `main.scd` | Boot sequence, file loading, grid connection, session auto-open |
| `sequencer.scd` | 7-track sequencer engine, transport, presets, clock |
| `synthdefs/sample_voice.scd` | Sample playback SynthDef |
| `synthdefs/fx_chain.scd` | FX chain SynthDefs (delay, granular, reverb, saturation, tilt, compressor, limiter) |
| `fx_params.scd` | FX parameter definitions, value tables, lookup functions |
| `sample_loader.scd` | Bank-based sample loading (16 banks × 15 samples) |
| `grid_params.scd` | Parameter definitions, value tables, mapping, sub-step resolution helpers |
| `grid_leds.scd` | LED rendering for all display modes |
| `grid_input.scd` | Grid input handling, gesture recognition, modal state |
| `session.scd` | Session save/load/new, GUI window with metering and quit button |

## Key Features

- 7 tracks × 16 steps with per-step parameters (2 pages, 14 params) and per-step sub-sequencing (up to 9 sub-steps per step)
- Hold-to-reveal parameter overlay with bank/sample selection, latch mode for hands-free editing
- Step copy/paste via side-by-side sub-seq and action grids (3×3 each, same rows, far side from held step)
- 49-slot preset matrix with confirm mode and quantized switching
- Global reverse toggle (XOR with per-step reverse)
- Clock division, FX matrix, and transpose overlays, each with a latch key (one column right on row 7) to lock the overlay open hands-free
- Transport hold page: hold transport 500ms for BPM nudge, swing nudge, kill FX tails, and VU meters; latched via (1, 7)
- Session manager: save/load/new sessions as `.gladiola` archives with GUI and stereo metering
- Session GUI with grid connection button and live status
- Full FX chain (delay, granular, reverb, saturation, tilt EQ, compressor, limiter), bitcrush, bipolar filter, pan, probability
- Granular (MiClouds) with 1.5× input boost, per-parameter S&H mod depth (size/position/pitch), quantized pitch intervals
- Clock-relative loop lengths (scales with tempo and clock division)
- Start/end points with wrap-around for polymetric patterns
- Per-track "macro" parameter overlay via mute key hold (apply params to all steps at once)
- Input mutex system preventing gesture conflicts across modal states

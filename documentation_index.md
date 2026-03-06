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
| `grid_params.scd` | Parameter definitions, value tables, mapping |
| `grid_leds.scd` | LED rendering for all display modes |
| `grid_input.scd` | Grid input handling, gesture recognition, modal state |
| `session.scd` | Session save/load/new, GUI window with metering |

## Key Features

- 7 tracks × 16 steps with per-step parameters (2 pages, 14 params)
- Hold-to-reveal parameter overlay with bank/sample selection
- Step copy/paste with dynamically positioned overlay action buttons
- 49-slot preset matrix with confirm mode and quantized switching
- Global reverse toggle (XOR with per-step reverse)
- Clock division, FX matrix, and transpose overlays
- Tempo nudge mode: hold transport 500ms, column 0 rows 0-6 adjust BPM (±1/5/10, reset)
- Session manager: save/load/new sessions as `.gladiola` archives with GUI and stereo metering
- Session GUI with grid connection button and live status
- Full FX chain (delay, granular, reverb, saturation, tilt EQ, compressor, limiter), bitcrush, bipolar filter, pan, probability
- Granular (MiClouds) with 1.5× input boost, per-parameter S&H mod depth (size/position/pitch), quantized pitch intervals
- Clock-relative loop lengths (scales with tempo and clock division)
- Start/end points with wrap-around for polymetric patterns
- Per-track "macro" parameter overlay via mute key hold (apply params to all steps at once)
- Input mutex system preventing gesture conflicts across modal states

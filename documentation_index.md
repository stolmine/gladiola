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
| `main.scd` | Boot sequence, file loading, grid connection |
| `sequencer.scd` | 7-track sequencer engine, transport, presets, clock |
| `synthdefs/sample_voice.scd` | Sample playback + delay SynthDefs |
| `sample_loader.scd` | Bank-based sample loading (16 banks × 15 samples) |
| `grid_params.scd` | Parameter definitions, value tables, mapping |
| `grid_leds.scd` | LED rendering for all display modes |
| `grid_input.scd` | Grid input handling, gesture recognition, modal state |

## Key Features

- 7 tracks × 16 steps with per-step parameters (2 pages, 14 params)
- Hold-to-reveal parameter overlay with bank/sample selection
- Step copy/paste with dynamically positioned overlay action buttons
- 4-slot preset system (save/recall/clear full state)
- Global reverse toggle (XOR with per-step reverse)
- Clock/delay division and transpose overlays
- Tempo-synced delay, bitcrush, bipolar filter, pan, probability
- Start/end points with wrap-around for polymetric patterns
- Per-track "macro" parameter overlay via mute key hold (apply params to all steps at once)
- Input mutex system preventing gesture conflicts across modal states

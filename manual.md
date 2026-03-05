# Gladiola Manual

A 7-track groovebox for monome grid, powered by SuperCollider.

## Setup

1. Install the `GridInterface` class in your SuperCollider Extensions folder
2. Place audio samples in the `samples/` directory (organized in subdirectories = banks)
3. Boot: `"/path/to/gladiola/main.scd".load;`
4. Connect grid: `~connectSerialosc.()`

## Grid Layout

```
Row 0:  Track 1  ──  16 steps
Row 1:  Track 2  ──  16 steps
Row 2:  Track 3  ──  16 steps
Row 3:  Track 4  ──  16 steps
Row 4:  Track 5  ──  16 steps
Row 5:  Track 6  ──  16 steps
Row 6:  Track 7  ──  16 steps
Row 7:  Utility row
```

### Utility Row (Row 7)

| Column | Function |
|--------|----------|
| 0 | Transport start/stop (tap) |
| 1 | Clock division (hold for menu) |
| 2 | Delay division (hold for menu) |
| 3 | Param page toggle (during param overlay) |
| 9-15 | Track mute toggles (tracks 1-7) |

## Basic Operation

### Toggling Steps

Tap a step on any track row to toggle it on/off. Active steps show LED brightness proportional to velocity. The playhead shows at full brightness during playback.

### Start/End Points

Double-tap any step in a track row to set it as the **start point**. This opens end point selection — tap another column on the same row to set the **end point**. Tap outside the row to cancel.

Start can be after end for wrap-around patterns (e.g., start=12, end=3 plays steps 12→15, 0→3).

### Division Menus

Hold column 1 (clock) or column 2 (delay) on the utility row. Options appear vertically in the column above, rows 0-6:

| Row | Division |
|-----|----------|
| 0 | 1/16 (0.0625) |
| 1 | 1/8 (0.125) |
| 2 | 3/16 (0.25) |
| 3 | 1/2 (0.5) |
| 4 | 1 (1.0) |
| 5 | 2 (2.0) |
| 6 | 4 (4.0) |

Tap a row to select. Release the held button to close.

## Parameter Overlay

Hold any active step to open the parameter overlay. The held step lights full brightness. The held step's column shows parameter selectors on the other rows. The selected parameter's row shows value positions.

### Navigating Parameters

- Tap a row in the held column to select that parameter
- Tap a column in the selected parameter's row to set its value
- Tap (3, 7) to toggle between page 1 and page 2

### Page 1 Parameters

| Param | Range | Notes |
|-------|-------|-------|
| Bank | 0-15 | Tap again when selected to cycle banks |
| Pitch | 0.125x - 4.0x | 15 preset values |
| Velocity | 1/15 - 1.0 | Affects LED brightness |
| Loop Length | 0.0 - 1.0 | 0 = one-shot, >0 = loop region |
| Loop Region | 0.0 - 1.0 | Start position in buffer |
| Ratchet | 1-8 | Subdivisions per step |
| Randomness | 0.0 - 1.0 | Mutates params per trigger |

### Page 2 Parameters

| Param | Range | Notes |
|-------|-------|-------|
| Gate Length | 1/16 step - full sustain | 15 values, exponential |
| Reverse | off/on | Plays sample backward |
| Filter | -1.0 - 1.0 | Negative=lowpass, positive=highpass, 0=bypass |
| Pan | -1.0 - 1.0 | Stereo position |
| Probability | 1/15 - 1.0 | Chance step fires |
| Delay Send | 0.0 - 1.0 | Amount sent to delay |
| Bitcrush | 0.0 - 1.0 | Sample rate/bit reduction |

## Functions

| Function | Description |
|----------|-------------|
| `~connectSerialosc.()` | Auto-detect hardware grid |
| `~connectGrid.(ip, port, osc, prefix)` | Connect manually |
| `~startTransport.()` | Start sequencer |
| `~stopTransport.()` | Stop sequencer |
| `~setTempo.(bpm)` | Change tempo (20-300) |
| `~setClockDiv.(div)` | Clock division (0.0625-4.0) |
| `~setDelayDiv.(div)` | Delay division (0.0625-4.0) |
| `~setTrackStart.(track, step)` | Set track start point (0-15) |
| `~setTrackEnd.(track, step)` | Set track end point (0-15) |
| `~muteTrack.(idx)` | Mute track |
| `~unmuteTrack.(idx)` | Unmute track |
| `~loadSamples.(path, mode)` | Load samples (subdirectory/random/sequential) |
| `~clearPattern.()` | Clear all steps |
| `~cleanup.()` | Shutdown |

## File Structure

| File | Purpose |
|------|---------|
| `main.scd` | Boot, load order, cleanup |
| `sequencer.scd` | 7-track sequencer engine, transport, clock |
| `synthdefs/sample_voice.scd` | Sample playback + delay SynthDefs |
| `sample_loader.scd` | Bank-based sample loading |
| `grid_params.scd` | Parameter definitions, value tables |
| `grid_leds.scd` | LED rendering for all modes |
| `grid_input.scd` | Grid input handling |

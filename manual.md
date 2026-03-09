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
| 0 | Transport start/stop (tap), panic/silence all (double-tap) |
| 1 | Clock division (hold for menu) |
| 2 | FX matrix (hold for menu). Lights full when any FX param differs from default. |
| 3 | Global reverse toggle |
| 4 | Global transpose (hold for menu) |
| 5-8 | Preset slots 1-4 |
| 9-15 | Track mute toggles (tracks 1-7) |

## Basic Operation

### Toggling Steps

Tap a step on any track row to toggle it on/off. Active steps show LED brightness proportional to velocity. The playhead shows at full brightness during playback.

### Transport

- **Tap** (0, 7): Toggle start/stop
- **Double-tap** (0, 7): Stop transport, silence all voices, and kill FX tails (panic)
- **Hold** (0, 7) for 500ms: Enter tempo nudge mode

### Transport Hold Page

Hold the transport button (column 0, row 7) for 500ms without releasing to open the transport hold page. The page is fully blocking — all grid input is captured by the transport page while it is open. Release the transport button to close (or use the latch key to keep it open).

**Latch**: Tap (1, 7) while the transport page is open to latch it. The latch key pulses when engaged; tap again to close. When latched, releasing the transport button does not close the page.

**Tempo nudge** — column 0, rows 0-6:

| Row | Action |
|-----|--------|
| 0 | +10 BPM |
| 1 | +5 BPM |
| 2 | +1 BPM |
| 3 | Recall anchor tempo (tap) / Set anchor tempo (hold 500ms) |
| 4 | -1 BPM |
| 5 | -5 BPM |
| 6 | -10 BPM |

Tap any nudge button to apply the adjustment immediately. The anchor tempo (row 3) defaults to 120 BPM; hold row 3 for 500ms to store the current BPM as the new anchor.

**Swing nudge** — column 1, rows 0-6:

| Row | Action |
|-----|--------|
| 0 | +10% swing |
| 1 | +5% swing |
| 2 | +1% swing |
| 3 | Reset swing to 50% |
| 4 | -1% swing |
| 5 | -5% swing |
| 6 | -10% swing |

Swing ranges from 50% (straight) to 100% (full shuffle). Even steps are delayed by the swing amount; odd steps are advanced correspondingly.

**Kill FX tails** — (2, 7): Tap to immediately free and recreate all send FX synths, silencing delay trails, granular clouds, and reverb.

**VU meters** — columns 7-8: Stereo output level displayed as vertical segment fills with fractional brightness at the top.

**Mixer faders** — columns 9-15: Per-track volume faders for tracks 1-7. Each column controls one track; rows 0-6 step through volume levels.

Nudge mode is blocked during overlays, modals, and other active utility states.

### Start/End Points

Double-tap any step in a track row to set it as the **start point**. This opens end point selection — tap another column on the same row to set the **end point**. Tap outside the row to cancel.

Start can be after end for wrap-around patterns (e.g., start=12, end=3 plays steps 12→15, 0→3).

### Division Menus

Hold column 1 (clock) on the utility row. Options appear vertically in the column above, rows 0-6:

| Row | Division |
|-----|----------|
| 0 | 1/16 (0.0625) |
| 1 | 1/8 (0.125) |
| 2 | 3/16 (0.25) |
| 3 | 1/2 (0.5) |
| 4 | 1 (1.0) |
| 5 | 2 (2.0) |
| 6 | 4 (4.0) |

Tap a row to select. Release the held button to close, or tap (2, 7) to latch the overlay open. The latch key pulses when engaged; tap again to close. While latched, releasing the held button does not close the overlay.

## FX Matrix

Hold column 2 on the utility row to open the FX matrix overlay. A 16×7 grid appears showing all FX parameters. Each column controls one parameter, rows 0-6 select from 7 preset values. One bright LED per column shows the current setting.

Tap any position to set that parameter to the corresponding value. Changes take effect immediately. Release the held button to close, or tap (3, 7) to latch the overlay open. The latch key pulses when engaged; tap again to close. While latched, releasing the held button does not close the overlay.

### Signal Flow

```
Voice dry → bus 0 → Saturation → Tilt EQ → Compressor → Limiter → Out
Voice send → FX bus ─┬─ Delay ──→ bus 0
                     ├─ Granular → bus 0
                     └─ Reverb ──→ bus 0
```

### Parameters

| Col | Parameter | Values (row 0→6) |
|-----|-----------|-------------------|
| 0 | Delay division | 1/16, dot 1/16, 1/8, dot 1/8, 1/4, 1/2, 1 |
| 1 | Delay feedback | 0 → 0.95 |
| 2 | Delay tone | -1 (dark) → +1 (bright) |
| 3 | Delay level | 0 → 1.0 |
| 4 | Granular size mod | 0 → 1.0 (S&H depth) |
| 5 | Granular position mod | 0 → 1.0 (S&H depth) |
| 6 | Granular pitch range | 0 → 1.0 (quantized intervals) |
| 7 | Granular level | 0 → 1.0 |
| 8 | Reverb size | 0.1 → 1.0 |
| 9 | Reverb damping | 0 → 1.0 |
| 10 | Reverb level | 0 → 1.0 |
| 11 | Saturation depth | 0 → 1.0 |
| 12 | Saturation type | fold, tanh, softclip, hard clip, sqrt, rectify, quantize (row 6→0) |
| 13 | Tilt EQ | -1 (dark) → +1 (bright) |
| 14 | Compressor amount | 0 → 1.0 |
| 15 | Compressor color | 0 (fast) → 1.0 (slow) |

Default state: all send levels at 0 (delay/granular/reverb silent), saturation off, tilt neutral, compressor off. A limiter (0.95 ceiling) is always active with no user controls.

The per-step "Delay Send" parameter (page 1) controls how much of each voice is sent to the shared FX bus. The three parallel effects (delay, granular, reverb) all read from this bus.

The granular effect (MiClouds) receives a 3× input boost and per-parameter sample-and-hold modulation. When a step fires with delay send > 0, a trigger is sent to the granular synth, latching new random values. Columns 4-6 control modulation depth independently: size mod (random grain size variation around 0.5), position mod (random position variation around 0.5), and pitch range (quantized to musical intervals: unison, ±fifth, ±octave, ±octave+fifth). At 0 all parameters are fixed; raising the value increases the random spread per trigger. Density modulation is derived from the average of size and position mod depths.

### Transpose

- **Tap** col 4: Swap between the current transpose value and the previous one (the value before the last overlay selection).
- **Hold** col 4: Open the overlay to pick a new value. The previous value is saved each time a new selection is made.

Options appear vertically in the column above:

| Row | Interval | Ratio |
|-----|----------|-------|
| 0 | -octave - fifth | 0.333× |
| 1 | -octave | 0.5× |
| 2 | -fifth | 0.667× |
| 3 | Unity | 1.0× |
| 4 | +fifth | 1.5× |
| 5 | +octave | 2.0× |
| 6 | +octave + fifth | 3.0× |

The transpose button lights full when transposed away from unity. Transpose multiplies pitch globally across all tracks.

Tap (5, 7) to latch the transpose overlay open. The latch key pulses when engaged; tap again to close. While latched, releasing the held button does not close the overlay.

### Track Mutes

Tap columns 9-15 on the utility row to toggle mute for tracks 1-7. Mute toggles fire on release. Muted tracks show full brightness on their mute button; active steps on muted tracks display dim. Muting a track immediately silences its voice — long gates and looping sounds cut off at the moment of mute.

Hold a mute key to open the track parameter overlay for that track (see [Track Parameter Overlay](#track-parameter-overlay) below). Release to close.

### Global Reverse

- **Tap** col 3: Permanently toggle global reverse. When active (full brightness), all steps play in reverse — except steps that already have per-step reverse enabled, which flip back to forward playback. This is a global inversion of each step's individual reverse setting.
- **Hold** col 3: Temporarily invert the current reverse state while held. Releasing reverts to the prior state. Useful for momentary reverse effects during performance.

### Presets

Four preset buttons (columns 5-8 on the utility row) map to a 49-slot preset matrix (7×7). Each button can be remapped to any slot in the matrix.

- **Tap** (populated slot): Recall preset (or queue if quantized switching is enabled)
- **Hold** (empty slot): Save current state to the mapped slot
- **Hold** (populated slot): Open preset matrix overlay

Each preset captures: all track steps and parameters, start/end points, track mutes, clock division, FX parameters, transpose, and global reverse state.

LED brightness: active (last recalled) preset = full, populated but not active = medium, empty = off. Only one button shows full brightness at a time — the most recently recalled slot. Clearing the active preset's slot resets the active indicator. A pending quantized recall pulses the button at 1/4 the slowest pattern's period.

### Preset Matrix Overlay

Hold a populated preset button to open the 7×7 matrix overlay. Slots appear on cols 0-6, rows 0-6. Action keys on col 8:

| Row | Action |
|-----|--------|
| 0 | **Save** — save current state to selected slot (confirm-armed if slot is occupied and confirm mode is on) |
| 2 | **Clear** — clear selected slot (confirm-armed if confirm mode is on) |
| 4 | **Confirm toggle** — enable/disable overwrite protection (full = on) |
| 6 | **Quantize toggle** — enable/disable quantized preset switching (full = on) |

- Tap a slot to select it. Populated selected = full, populated unselected = medium, empty selected = medium, empty unselected = dim.
- Confirm-armed Save and Clear buttons pulse at 1/4 the slowest pattern's period — tap again to execute, or tap a different action to cancel.
- On release of the held utility button: the button remaps to the selected slot. Tap the button to recall (or queue if quantized).
- Tap the key one column right of the held preset button (cols 6-9, row 7) to latch the overlay open. The latch key pulses when engaged; tap again to close. While latched, releasing the held button does not close the overlay.

### Quantized Preset Switching

When the quantize toggle is enabled and the transport is playing, preset recalls are queued instead of firing immediately. The queued preset executes when the longest unmuted track's playhead wraps back to its start step — ensuring pattern-aligned transitions. All tracks reset to their start step on recall so patterns stay locked after the switch.

When the transport is stopped, presets always recall instantly regardless of the quantize setting. The quantize LED and state are preserved — quantized switching resumes when playback starts.

Tapping an already-queued preset cancels the queue and recalls it immediately.

## Parameter Overlay

Hold any active step to open the parameter overlay. The held step lights full brightness. The held step's column shows parameter selectors on all other rows (0-7). The selected parameter's row shows value positions.

Two 3×3 grids appear side-by-side on the far side of the held step:

- **Sub-seq grid** (cols 13-15 or 0-2): Shows the 9 sub-step cells for the held step
- **Action grid** (cols 9-11 or 4-6): Four corner keys:

```
[P] [ ] [C]    P = Page toggle     C = Copy
[ ] [ ] [ ]
[A] [ ] [L]    A = Audition        L = Latch
```

- **P (Page toggle)**: Switches between param page 1 and page 2. Medium = page 1, full = page 2.
- **C (Copy)**: Copies all params from the held step to the clipboard. Three brightness states: dim = clipboard empty, subtle glow = clipboard has data but differs from the held step, bright = clipboard matches the held step exactly.
- **A (Audition)**: Toggles step preview. Full = enabled. Only active when transport is stopped.
- **L (Latch)**: Keeps the overlay open after releasing the held step. Pulses when engaged. Tap again to disengage and close the overlay. Latch behavior extends to all utility overlays and the transport hold page — each has a dedicated latch key one column to the right of the held button on row 7.

Both grids share the same 3 rows, positioned to maximise gap from the value row. When the held step is in cols 0-7, grids appear on the right (cols 9-15). When in cols 8-15, grids appear on the left (cols 0-6).

### Copy/Paste

- **Copy**: While in the param overlay, tap the C button to copy the held step's parameters
- **Paste**: Hold an inactive (off) step — if the clipboard has data, the step is filled with clipboard params and activated. No param menu opens.
- Holding an active step always opens the param menu normally, regardless of clipboard state
- The clipboard persists across overlay sessions until overwritten

### Track Parameter Overlay

Hold a mute key (cols 9-15, row 7) to open the track parameter overlay for that track. The overlay closes when the mute key is released (unless latched). Tapping and releasing quickly still toggles mute — hold to enter the overlay.

The overlay uses `~overlayLayout` for layout computation, placing two 3x3 grids side-by-side on the far side of the held column. Because track mute keys are cols 9-15 (right side), the grids always appear on the left: action grid on cols 4-6, phantom sub-step grid on cols 0-2.

- **Param column**: The held mute key's column, rows 0-6. Tap a row to select a parameter.
- **Value row**: Appears at the selected parameter's row number. Tap a column to set the value. Value row has collision avoidance — action and sub grid cell positions are excluded.
- **Held mute key LED**: Lit while the overlay is open.
- **Scope**: Value changes apply to ALL steps in the track simultaneously.
- **Unanimous indicator**: If all steps share the same value for the selected parameter, the current position lights full brightness. If steps have mixed values, no bright indicator is shown.
- **Audition preview**: When audition is enabled and the transport is stopped, changing a parameter value automatically previews step 0 of the track with the new value applied.

**Action grid** (cols 4-6, 3 rows determined by layout):

```
[P] [ ] [S]    P = Page toggle     S = Slice stub
[ ] [M] [ ]    M = Mod stub
[A] [ ] [L]    A = Audition         L = Latch
```

- **P (Page toggle)**: Switches between param page 1 and page 2. Medium = page 1, full = page 2.
- **S (Slice stub)**: Placeholder for future slice mode toggle.
- **M (Mod stub)**: Center key, placeholder for future modulation overlay.
- **A (Audition)**: Toggles step preview. Full = enabled. Only active when transport is stopped.
- **L (Latch)**: Keeps the overlay open after releasing the mute key. Pulses when engaged. Tap again to disengage and close the overlay.

**Clear track** — center cell of the phantom sub-step grid (col 1, middle row): Two-tap confirmation. First tap arms the clear (LED pulses). Second tap confirms — resets all 16 steps on the track to defaults. Tapping any other button disarms. The clear state (`~trackClearArmed`) resets when the overlay closes.

Cannot open the step param overlay while the track overlay is active, and vice versa.

### Navigating Parameters

- Tap a row in the held column to select that parameter
- Tap a column in the selected parameter's row to set its value
- Tap the P button to toggle between page 1 and page 2

### Page 1 Parameters

| Param | Range | Notes |
|-------|-------|-------|
| Bank | 0-15 | Tap again when selected to cycle banks |
| Pitch | 0.125× - 4.0× | 15 preset values |
| Velocity | 1/15 - 1.0 | Affects LED brightness |
| Gate Length | 1/16 step - 16 steps | 15 exponential values, clock-relative |
| Filter | -1.0 - 1.0 | Negative=lowpass, positive=highpass, center=bypass (center dent at pos 7) |
| Pan | -1.0 - 1.0 | Stereo position, center=mono (center dent at pos 7) |
| Delay Send | 0.0 - 1.0 | Amount sent to FX bus (delay, granular, reverb) |

### Page 2 Parameters

| Param | Range | Notes |
|-------|-------|-------|
| Attack | 0.002s - 0.5s | Amp envelope attack time, 15 exponential values |
| Reverse | off/on | Plays sample backward |
| Loop Length | 0 - 8.0 | 0 = one-shot, 1/16-1.0 = sub-step fractions, 2/4/8 = multi-step loops. Clock-relative: scales with tempo and clock division. |
| Loop Region | 0.0 - 1.0 | Start position in buffer |
| Ratchet | 1-8 | Subdivisions per step |
| Probability | 1/15 - 1.0 | Chance step fires each pass |
| Bitcrush | 0.0 - 1.0 | Sample rate and bit depth reduction |

## Sub-Sequencing

Each of the 16 steps per track has a 3x3 grid of up to 9 sub-steps. Sub-steps cycle each time the parent step fires, adding variation without using more steps.

### How It Works

- Sub-steps use an **override/inherit** model: they only store parameters that differ from the parent step. Unset params inherit from the parent.
- Length is determined by the last **active** (toggled-on) sub-step position + 1. All positions in range play — active cells use their overrides, inactive cells play parent params.
- Cell [0] is always active (minimum length 1). A step with no sub-step edits behaves exactly as before.

### Grid Interaction

The 3×3 sub-grid appears in the parameter overlay as part of the side-by-side grid layout (see [Parameter Overlay](#parameter-overlay)). Both the sub-seq and action grids share the same rows, positioned to avoid the value row.

| Action | What happens |
|--------|-------------|
| **Tap** active sub-step | Toggle active off (deferred to release) |
| **Tap** inactive sub-step | Toggle active on |
| **Hold** active sub-step | Enter edit mode instead of toggling off (cell pulses) |
| **Release** sub-step in edit mode | Stays in edit mode |
| Edit params freely | Changes apply to the sub-step, not the parent |
| **Tap** pulsing sub-step | Exit edit mode |
| **Double-tap** sub-step | Clear all overrides (reset to parent) |
| Release parent step | Close overlay |

### LED Brightness

Sub-step cells use 4 brightness levels:

- **Full**: Active with overrides (customized)
- **Medium-high**: Active, no overrides (inherits parent)
- **Medium**: Inactive with overrides
- **Dim**: Inactive, no overrides (empty slot)

The currently-editing sub-step pulses. The value display resolves through the sub-step's overrides when in edit mode.

### Session Compatibility

Old sessions and presets without sub-step data load normally — missing fields are initialized to defaults during migration.

## Session Manager

Sessions persist the complete groovebox state to disk as `.gladiola` archives stored in `~/gladiola-sessions/`. The session manager GUI opens automatically on boot.

### GUI Window

The session manager window provides:

- **BPM display**: Current tempo, updated live
- **Samples display**: Folder name of the loaded sample directory
- **Grid status**: Shows "Grid: connected" or "Grid: —", updated live
- **Stereo level meters**: Amplitude of the main output bus (L/R), updated at 20Hz with peak hold
- **New**: Prompt for a session name and a folder picker for the sample directory, then initialize a blank session
- **Save**: Save to the current session name; prompts for a name first if none is set
- **Save As**: Prompt for a new name and save a copy
- **Load**: List all `.gladiola` files in `~/gladiola-sessions/` and load the selected one
- **Grid**: Connect to serialosc grid controller
- **Quit**: Shutdown with confirmation — stops transport, silences voices, kills FX tails, clears and frees the grid, closes the window, and quits the server

### What Sessions Capture

- All 7 tracks: steps, per-step parameters, sub-step data, start/end points, mute state
- BPM, clock division, FX parameters, transpose, global reverse
- All 49 preset slots, slot map, confirm mode, quantize mode
- Sample directory path

### Session Functions

| Function | Description |
|----------|-------------|
| `~buildSessionSnapshot.()` | Build a Dictionary snapshot of the current state |
| `~saveSession.()` | Save to the current session path (no-op if no name set) |
| `~saveSessionAs.(name)` | Save under a new name in `~/gladiola-sessions/` |
| `~loadSession.(name)` | Load session by name from `~/gladiola-sessions/` |
| `~newSession.(name, sampleDir)` | Initialize a blank session with the given name and sample folder |
| `~sessionGUI.()` | Open (or bring to front) the session manager window |

Loading a session stops transport, frees existing buffers (with a server sync to prevent buffer exhaustion), loads the new sample directory, then restores all track and global state.

## Functions

| Function | Description |
|----------|-------------|
| `~connectSerialosc.()` | Auto-detect hardware grid |
| `~connectGrid.(ip, port, osc, prefix)` | Connect manually |
| `~startTransport.()` | Start sequencer |
| `~stopTransport.()` | Stop sequencer |
| `~panicVoices.()` | Silence all voices immediately |
| `~setTempo.(bpm)` | Change tempo (20-300) |
| `~setClockDiv.(div)` | Clock division (0.0625-4.0) |
| `~setFxParam.(key, val)` | Set FX parameter (see FX Matrix for keys) |
| `~setDelayDiv.(div)` | Legacy wrapper: set delay division (0.0625-4.0) |
| `~setTrackStart.(track, step)` | Set track start point (0-15) |
| `~setTrackEnd.(track, step)` | Set track end point (0-15) |
| `~muteTrack.(idx)` | Mute track |
| `~unmuteTrack.(idx)` | Unmute track |
| `~loadSamples.(path, mode)` | Load samples (subdirectory/random/sequential) |
| `~clearPattern.()` | Clear all steps |
| `~savePreset.(slot)` | Save full state to preset slot (0-48) |
| `~recallPreset.(slot)` | Recall state from preset slot (0-48) |
| `~clearPreset.(slot)` | Clear preset slot (0-48) |
| `~buildSessionSnapshot.()` | Build snapshot Dictionary of current state |
| `~saveSession.()` | Save current session |
| `~saveSessionAs.(name)` | Save session under new name |
| `~loadSession.(name)` | Load session by name |
| `~newSession.(name, sampleDir)` | Create blank session |
| `~sessionGUI.()` | Open session manager window |
| `~cleanup.()` | Shutdown |

## File Structure

| File | Purpose |
|------|---------|
| `main.scd` | Boot, load order, cleanup, session auto-open |
| `sequencer.scd` | 7-track sequencer engine, transport, clock |
| `synthdefs/sample_voice.scd` | Sample playback SynthDef |
| `synthdefs/fx_chain.scd` | FX chain SynthDefs (delay, granular, reverb, saturation, tilt, compressor, limiter) |
| `fx_params.scd` | FX parameter definitions, value tables, lookup functions |
| `sample_loader.scd` | Bank-based sample loading; Server.sync after freeSamples prevents buffer exhaustion |
| `grid_params.scd` | Parameter definitions, value tables |
| `grid_leds.scd` | LED rendering for all modes |
| `grid_input.scd` | Grid input handling |
| `session.scd` | Session save/load/new and GUI window |

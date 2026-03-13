# 6DOF VR Drone Controller - Phase 1a Design

**Date**: 2026-03-13
**Status**: Approved for implementation

## Vision

Use a Quest 3 controller as an experimental 6DOF drone input device, with fast iteration on novel control schemes. Phase 1a is not a standalone controller product yet. It is a Linux-first simulator prototype optimized for trying, tuning, and comparing mappings quickly.

**Phase 1a**: Quest streams raw telemetry, PC runs mapping/editor/backend, Liftoff receives a virtual gamepad.
**Phase 1b**: Harden the experiment loop, add more presets, and evaluate a Windows backend.
**Phase 2**: Consider moving selected mapping/runtime pieces back to Quest for lower-latency standalone use.
**Phase 3**: Stretch goal for real-drone integration.

## Product Goals

- Make it easy to define and compare multiple embodied control schemes.
- Keep the authoring and debugging loop on the PC for rapid iteration.
- Reach a reliable first-flight benchmark using a standard Linux virtual gamepad.
- Leave enough architectural room for later Windows support and possibly Quest-side mapping.

## Non-Goals For Phase 1a

- No real-drone bridge.
- No Windows virtual-controller backend yet.
- No fully in-headset authoring UI.
- No custom per-template scripts. Templates must be expressible through normalized bindings.

## System Architecture

```text
Quest 3 (Android / OpenXR / passthrough)
  ├─ Godot XR sender app
  │   ├─ Explicit OpenXR action map
  │   ├─ Local reference space
  │   ├─ Grip-pose telemetry reader
  │   ├─ Calibration + recenter events
  │   ├─ UDP raw telemetry sender (90 Hz target)
  │   └─ Small TCP control/status client
  │       ├─ Active template name
  │       ├─ Template list
  │       ├─ Live tuning values
  │       └─ Connection / failsafe state
  │
  └─ Minimal Quest UI
      ├─ Template selector
      ├─ Calibrate / recenter
      ├─ Status / packet health / failsafe state
      └─ Limited tuning (sensitivity, deadzone, expo, integrator gain)

LAN / Wi-Fi
  ├─ UDP: RawControllerState stream
  └─ TCP: Control + status channel

Linux PC
  ├─ Godot desktop app
  │   ├─ UDP telemetry receiver
  │   ├─ Source derivation pipeline
  │   ├─ Mapping engine
  │   ├─ Desktop editor / telemetry visualizer
  │   ├─ Template library + live apply
  │   ├─ Failsafe supervisor
  │   └─ Backend abstraction
  │       └─ Linux gamepad backend
  │           └─ helper binary -> /dev/uinput
  │
  └─ Liftoff
      └─ Reads a standard SDL-friendly gamepad
```

## Key Decisions

- **PC-side mapping for Phase 1a**. Quest sends raw controller telemetry; mapping, tuning, logs, and gamepad injection happen on the PC.
- **Linux-first backend**. Build a backend interface now, but only implement the Linux uinput helper in Phase 1a.
- **Grip pose for flight**. The primary motion source uses the controller grip pose. Aim pose is not exposed in Phase 1a.
- **Local reference space**. This is the recommended OpenXR reference space for seated/vehicle experiences such as flight simulators.
- **Two separate channels**. Raw telemetry uses UDP for low latency. Template/status uses a small reliable TCP channel.
- **Failsafe is not hold mode**. Input loss enters a neutral + disarm-safe state after 200 ms. Hold/set-and-adjust behavior is provided through a mapping mode, not by connection-loss behavior.

## Raw Telemetry Contract

Quest sends `RawControllerState` at a fixed target rate of **90 Hz**.

### `RawControllerState`

| Field | Type | Notes |
|------|------|------|
| `magic` | bytes[4] | `"RCS1"` |
| `sequence` | uint32 | Monotonic packet counter |
| `timestamp_usec` | uint64 | Monotonic sender timestamp |
| `tracking_valid` | uint8 | `0` or `1` |
| `event_flags` | uint16 | Bit flags for calibrate/recenter requests |
| `buttons` | uint16 | Packed button state |
| `grip_position` | float32 x3 | Meters, in local reference space |
| `grip_orientation` | float32 x4 | Quaternion `x,y,z,w` |
| `linear_velocity` | float32 x3 | Meters / second |
| `angular_velocity` | float32 x3 | Radians / second |
| `trigger` | float32 | 0.0 - 1.0 |
| `grip` | float32 | 0.0 - 1.0 |
| `thumbstick` | float32 x2 | -1.0 - 1.0 |

### Event Flags

- `1 << 0`: calibrate requested
- `1 << 1`: recenter detected

## Control/Status Channel

The PC exposes a small TCP server. JSON lines are sufficient for Phase 1a.

### Quest -> PC Messages

- `hello`
- `select_template`
- `apply_tuning`
- `request_calibrate`

### PC -> Quest Messages

- `hello_ack`
- `template_catalog`
- `active_template`
- `status`
- `failsafe_state`

## Source Registry

The PC derives a canonical set of sources from raw telemetry before templates are applied.

### Pose and motion sources

- `pose_pitch_deg`
- `pose_yaw_deg`
- `pose_roll_deg`
- `pos_x_m`
- `pos_y_m`
- `pos_z_m`
- `angvel_x_rad_s`
- `angvel_y_rad_s`
- `angvel_z_rad_s`
- `linvel_x_m_s`
- `linvel_y_m_s`
- `linvel_z_m_s`
- `radius_xyz_m`
- `radius_xz_m`

### Direct analog sources

- `trigger`
- `grip`
- `thumbstick_x`
- `thumbstick_y`

### Boolean/button sources

- `button_south`
- `button_east`
- `button_west`
- `button_north`
- `button_thumbstick`
- `button_menu`

## Mapping Engine

Templates remain data-driven, but Phase 1a replaces ambiguous multi-source mixing with **normalized bindings**.

### Output Channels

- `throttle`
- `yaw`
- `pitch`
- `roll`
- `aux_analog_1`
- `aux_analog_2`
- `aux_button_1`
- `aux_button_2`
- `aux_button_3`
- `aux_button_4`

### Binding Model

Each output axis owns `bindings[]`. Each binding has:

- `source`
- `mode`: `absolute`, `delta`, or `integrator`
- `range_min`
- `range_max`
- `weight`
- `invert`
- `smoothing`
- `curve`: `linear`, `expo_soft`, or `expo_hard`

Each binding normalizes its own source to `[-1, 1]` before mixing. Mixed values then go through output-level processing:

- `deadzone`
- `expo`
- `sensitivity`
- `invert_output`
- `output_min`
- `output_max`

### Mode Semantics

- `absolute`: current normalized source value contributes directly.
- `delta`: frame-to-frame normalized change, using packet timestamps.
- `integrator`: accumulates normalized delta over time into a latched output, clamps it to the output range, and holds the value until counter-motion, template reset, calibration, recenter, or failsafe clears it.

## Failsafe

The failsafe supervisor enters failsafe when any of these occur:

- no valid telemetry for more than **200 ms**
- `tracking_valid == 0`
- the stream sequence becomes stale and no fresh telemetry arrives before timeout

Failsafe behavior:

- set analog outputs to neutral (`0.0`)
- clear all latched integrator state
- force aux buttons to disarm-safe values
- show the Quest and PC UI as disconnected / failsafe

Recovery occurs automatically on fresh valid telemetry. Integrator state remains cleared after recovery.

## Virtual Gamepad Contract

The Linux backend exposes a standard SDL-friendly gamepad with these mappings:

- `ABS_X` = `yaw`
- `ABS_Y` = `throttle`
- `ABS_RX` = `roll`
- `ABS_RY` = `pitch`
- `ABS_Z` = `aux_analog_1`
- `ABS_RZ` = `aux_analog_2`
- `BTN_SOUTH` = `aux_button_1`
- `BTN_EAST` = `aux_button_2`
- `BTN_WEST` = `aux_button_3`
- `BTN_NORTH` = `aux_button_4`

Extra buttons such as `BTN_START` or `BTN_SELECT` may be reserved for future use but are not needed by Phase 1a.

## Quest UX

The Quest app is intentionally small. It shows:

- current connection state
- active template name
- telemetry health / packet rate
- failsafe state
- template selector
- calibrate and recenter controls
- limited live tuning controls

It does **not** support full binding authoring or template structure changes.

## Desktop UX

The desktop app is the main experiment surface. It must support:

- create / rename / delete templates
- add / remove / reorder bindings per output
- source selection and mode selection
- per-binding range, weight, invert, smoothing, and curve
- per-output deadzone, expo, sensitivity, clamp
- raw telemetry preview
- derived-source preview
- mapped-output preview
- live apply to the backend and Quest status channel

## Bundled Templates

Phase 1a ships with seven bundled templates:

- `rate_direct`
- `hold_adjust`
- `attitude_tilt`
- `spatial_sculpt`
- `impulse_flick`
- `blend_precision`
- `blend_agile`

The benchmark template is `rate_direct`:

- throttle from `trigger`
- yaw from `pose_yaw_deg`
- pitch and roll from embodied wrist/controller motion
- no thumbstick-assisted fallback preset

## Project Structure

```text
6dof-drone-sim/
├── project.godot
├── addons/
│   └── gut/
├── docs/
│   └── plans/
├── scenes/
│   ├── quest_main.tscn
│   ├── pc_main.tscn
│   └── shared/
├── scripts/
│   ├── backend/
│   ├── input/
│   ├── mapping/
│   ├── network/
│   ├── telemetry/
│   └── ui/
├── templates/
├── test/
│   ├── unit/
│   └── integration/
└── tools/
    ├── linux_gamepad_helper.c
    └── Makefile
```

## Technology Stack

- **Godot**: 4.6 stable
- **Quest XR**: OpenXR with an explicit action map
- **Renderer for Quest**: Compatibility renderer
- **Languages**: GDScript + C helper
- **Testing**: GUT 9.6.0 for Godot 4.6
- **Virtual controller**: Linux `uinput`
- **Simulator target**: Liftoff on Linux

## Acceptance Criteria

- The desktop receiver can ingest raw Quest telemetry at the target rate.
- The mapping engine can derive sources, apply normalized bindings, and drive the Linux backend.
- The Linux helper is recognized as a standard gamepad by SDL/evdev.
- `rate_direct` is flyable in Liftoff.
- Template switching and limited Quest-side tuning work live.
- Failsafe engages within 200 ms and clears integrators.

## References

- [Godot OpenXR Settings](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_settings.html)
- [Godot Deploying to Android XR](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html)
- [GUT version matrix](https://github.com/bitwes/Gut)
- [Linux Gamepad Specification](https://docs.kernel.org/input/gamepad.html)

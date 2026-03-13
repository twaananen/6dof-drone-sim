# 6DOF VR Drone Controller - Phase 1a Implementation Plan

**Date**: 2026-03-13
**Goal**: Build the first working PC-mapped prototype for experimenting with Quest 3 embodied drone-control schemes in Liftoff on Linux.

**Design Doc**: `docs/plans/2026-03-10-6dof-drone-controller-design.md`

## Environment Prerequisites

- **Godot**: 4.6 stable or 4.6.1 stable
- **GUT**: 9.6.0
- **macOS dev host**: used for repo work and Quest export prep
- **Linux runtime host**: required for the uinput backend and Liftoff validation
- **Android XR**: Compatibility renderer, OpenXR enabled, explicit action map

## Delivery Milestones

### Milestone 1: Project Scaffold

- Create a Godot 4.6 project skeleton with `Compatibility` renderer defaults.
- Add GUT and a headless smoke test.
- Create the runtime folders: `backend`, `input`, `mapping`, `network`, `telemetry`, `ui`, `templates`, `test`, `tools`.

### Milestone 2: Core Data And Protocol

- Implement `RawControllerState` packet packing/unpacking for UDP.
- Implement the TCP JSON-line control/status channel.
- Add unit tests for packet validity, stale sequence handling, and basic control messages.

### Milestone 3: Mapping Core

- Implement the template data model around `outputs[]` with `bindings[]`.
- Implement source derivation from raw telemetry.
- Implement normalized binding processing with `absolute`, `delta`, and `integrator`.
- Implement the failsafe supervisor and integrator reset rules.
- Add unit tests for calibration offsets, source derivation, normalization, mixing, delta timing, integrator hold, and failsafe reset.

### Milestone 4: Linux Backend

- Implement a backend interface on the PC side.
- Implement a Linux backend adapter that talks to a helper binary over localhost UDP.
- Implement the helper binary using Linux `uinput` with standard gamepad codes.
- Add a Linux validation script or checklist proving SDL/evdev recognition.

### Milestone 5: Quest Sender

- Implement Quest-side OpenXR startup with explicit action map configuration.
- Use `Local` reference space and grip pose telemetry.
- Implement raw telemetry capture, event flag generation, UDP send, and TCP status client.
- Implement the minimal Quest UI for template selection, calibrate/recenter, status, and limited tuning.

### Milestone 6: Desktop Editor And Runtime

- Implement the PC main scene with telemetry health, raw/derived/mapped previews, template editing, and live apply.
- Persist template files as JSON resources in `templates/` and `user://templates/`.
- Apply active template changes immediately to the mapping engine and status channel.

### Milestone 7: Presets And Acceptance

- Ship the seven bundled templates.
- Validate `rate_direct` as the benchmark first-flight template.
- Run end-to-end checks for template switching, limited Quest tuning, failsafe, recovery, and benchmark flyability.

## File-Level Implementation Outline

### Project Setup

- `project.godot`
  - Godot 4.6 config
  - OpenXR enabled
  - Compatibility renderer
- `.gitignore`
- `.gutconfig.json`

### Mapping And Telemetry

- `scripts/telemetry/raw_controller_state.gd`
  - packet constants
  - pack / unpack helpers
- `scripts/telemetry/source_deriver.gd`
  - quaternion -> Euler
  - radii derivation
  - button expansion
- `scripts/mapping/mapping_template.gd`
  - outputs, bindings, serialization
- `scripts/mapping/mapping_engine.gd`
  - normalized binding evaluation
  - output post-processing
  - integrator state
- `scripts/mapping/failsafe_supervisor.gd`
  - timeout detection
  - reset semantics

### Networking

- `scripts/network/telemetry_sender.gd`
- `scripts/network/telemetry_receiver.gd`
- `scripts/network/control_client.gd`
- `scripts/network/control_server.gd`

Use:

- UDP for raw telemetry only
- TCP JSON lines for template catalog, active template, tuning deltas, and status

### Quest Runtime

- `scripts/input/xr_telemetry_reader.gd`
  - grip pose
  - velocities
  - trigger / grip / thumbstick / buttons
  - calibration and recenter event flags
- `scripts/quest_main.gd`
  - XR init
  - sender / client lifecycle
  - limited UI bindings
- `scenes/quest_main.tscn`

### PC Runtime

- `scripts/backend/gamepad_backend.gd`
  - backend interface
- `scripts/backend/linux_gamepad_backend.gd`
  - helper process lifecycle
  - localhost UDP writer
- `scripts/pc_main.gd`
  - receiver
  - source derivation
  - mapping engine
  - failsafe supervisor
  - backend output
  - UI integration
- `scenes/pc_main.tscn`

### Desktop UI

- `scripts/ui/template_manager.gd`
- `scripts/ui/template_editor.gd`
- `scripts/ui/telemetry_panel.gd`
- `scripts/ui/output_panel.gd`
- `scripts/ui/quest_status_panel.gd`
- `scenes/shared/*.tscn`

Desktop UI scope for Phase 1a:

- full template authoring
- live preview
- live apply
- save / delete

Quest UI scope for Phase 1a:

- template selection
- calibrate / recenter
- sensitivity / deadzone / expo / integrator gain
- status only

### Linux Helper

- `tools/linux_gamepad_helper.c`
- `tools/Makefile`

Requirements:

- create a standard gamepad
- expose `ABS_X`, `ABS_Y`, `ABS_RX`, `ABS_RY`, `ABS_Z`, `ABS_RZ`
- expose `BTN_SOUTH`, `BTN_EAST`, `BTN_WEST`, `BTN_NORTH`
- accept localhost UDP packets from the Godot PC app

## Protocol Details

### UDP `RawControllerState`

Fixed packet order:

1. magic `RCS1`
2. version `u8`
3. sequence `u32`
4. timestamp_usec `u64`
5. tracking_valid `u8`
6. event_flags `u16`
7. buttons `u16`
8. grip position `3 x f32`
9. grip orientation `4 x f32`
10. linear velocity `3 x f32`
11. angular velocity `3 x f32`
12. trigger `f32`
13. grip `f32`
14. thumbstick `2 x f32`

### TCP control/status

JSON lines with a top-level `type` field. Phase 1a message types:

- `hello`
- `hello_ack`
- `template_catalog`
- `active_template`
- `select_template`
- `apply_tuning`
- `status`
- `failsafe_state`

## Template Schema

Top-level fields:

- `template_name`
- `description`
- `outputs`

Each output contains:

- `bindings`
- `deadzone`
- `expo`
- `sensitivity`
- `invert_output`
- `output_min`
- `output_max`

Each binding contains:

- `source`
- `mode`
- `range_min`
- `range_max`
- `weight`
- `invert`
- `smoothing`
- `curve`

Allowed binding modes:

- `absolute`
- `delta`
- `integrator`

Allowed curves:

- `linear`
- `expo_soft`
- `expo_hard`

## Bundled Templates

Create these files:

- `templates/rate_direct.json`
- `templates/hold_adjust.json`
- `templates/attitude_tilt.json`
- `templates/spatial_sculpt.json`
- `templates/impulse_flick.json`
- `templates/blend_precision.json`
- `templates/blend_agile.json`

Benchmark behavior:

- `rate_direct`
  - throttle = trigger
  - yaw = pose yaw
  - pitch / roll = embodied wrist motion

## Test Plan

### Unit Tests

- `test/unit/test_raw_controller_state.gd`
  - roundtrip packet
  - invalid magic
  - stale sequence rejected
- `test/unit/test_source_deriver.gd`
  - Euler derivation
  - radius derivation
  - button expansion
- `test/unit/test_mapping_template.gd`
  - serialization
  - defaults
- `test/unit/test_mapping_engine.gd`
  - absolute normalization
  - multi-binding mixing
  - delta mode
  - integrator hold
  - integrator reset
- `test/unit/test_failsafe_supervisor.gd`
  - timeout trip
  - recovery clears hold state

### Integration Tests

- `test/integration/test_udp_loopback.gd`
  - sender -> receiver path
- `test/integration/test_control_channel.gd`
  - template catalog
  - active template update
- `test/integration/test_live_template_apply.gd`
  - change template while telemetry continues
- `test/integration/test_failsafe_flow.gd`
  - stop telemetry -> neutral output within 200 ms -> recover cleanly

### Manual Linux Validation

1. Build `tools/linux_gamepad_helper`.
2. Run the PC scene on Linux.
3. Confirm the device appears under `/dev/input/event*`.
4. Confirm `evtest` or SDL sees standard gamepad buttons/axes.
5. Confirm Liftoff can bind the controller.
6. Confirm losing telemetry trips failsafe within 200 ms.
7. Confirm `rate_direct` is stably flyable.

## Acceptance Definition

Phase 1a is complete when:

- the Quest app sends raw telemetry
- the PC app derives sources and applies templates
- the Linux backend presents a usable standard gamepad
- the benchmark template flies in Liftoff
- template selection and live tuning update both PC and Quest
- failsafe and recovery work reliably

## Notes

- If Godot is unavailable on the current machine, implementation may proceed by writing the project and tests, but execution must be deferred until Godot 4.6 is installed.
- Windows support is intentionally deferred, but the backend API must avoid Linux-specific assumptions outside the Linux backend implementation.

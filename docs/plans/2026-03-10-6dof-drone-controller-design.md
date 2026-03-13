# 6DOF VR Drone Controller - Design Document

**Date**: 2026-03-10
**Status**: Approved

## Vision

Control drones using a Quest 3 VR controller's 6 degrees of freedom (position + orientation). The core product is a configurable mapping engine that translates natural hand movements into drone control inputs, with saved templates for rapid experimentation.

**Phase 1** (this design): Virtual controller for drone simulators.
**Phase 2**: Refine control scheme through iteration.
**Phase 3** (stretch): Control a real drone, receive video feed in headset.

## System Architecture

```
Quest 3 (standalone, passthrough mode)
  ├─ Godot XR app
  │   ├─ XR Controller Tracker
  │   │   └─ Reads 6DOF pose: position (x,y,z) + orientation (quat)
  │   │       + angular velocity, linear velocity, button states
  │   │
  │   ├─ Mapping Engine (core shared code)
  │   │   ├─ Loads mapping template (JSON resource)
  │   │   ├─ Multi-source mixing per output axis
  │   │   ├─ Source modes: absolute, delta, velocity
  │   │   ├─ Per-axis: dead zone, expo curve, sensitivity, invert, range clamp
  │   │   ├─ Center-point calibration
  │   │   └─ Outputs: mapped axes (throttle, yaw, pitch, roll, aux1..n)
  │   │
  │   ├─ Config UI (AR overlay via passthrough)
  │   │   ├─ Template selector (load/save/create)
  │   │   ├─ Per-axis config with sliders
  │   │   ├─ Live axis visualization (raw input + mapped output)
  │   │   └─ Second controller optionally used for UI interaction
  │   │
  │   └─ UDP Sender (~100Hz)
  │
  ── WiFi (local network) ──
  │
Linux PC
  ├─ Same Godot project (Linux export)
  │   ├─ UDP Receiver
  │   ├─ uinput Virtual Gamepad (GDExtension)
  │   │   └─ Creates /dev/input/js* device
  │   └─ Status UI (connection, axes, latency)
  │
  └─ Liftoff (reads virtual gamepad via SDL2/evdev)
```

**Key decisions:**
- Single Godot project with platform-specific export targets (Quest/Linux/macOS)
- Mapping happens on Quest side; PC is a thin forwarder to virtual gamepad
- One controller for flying, second controller optionally for UI interaction
- Quest passthrough mode lets user see physical monitor while wearing headset
- macOS build for development/testing (UDP pipeline without virtual gamepad)

## Mapping Engine

### Input Sources (from one Quest controller)

| Source | Type | Description |
|--------|------|-------------|
| `tilt_x` | float | Pitch of controller (forward/back tilt) |
| `tilt_y` | float | Yaw of controller (left/right rotation about vertical) |
| `tilt_z` | float | Roll of controller (left/right tilt) |
| `pos_x` | float | Hand position left/right |
| `pos_y` | float | Hand position up/down |
| `pos_z` | float | Hand position forward/back |
| `angvel_x/y/z` | float | Angular velocity (rate of rotation) |
| `linvel_x/y/z` | float | Linear velocity (rate of movement) |
| `trigger` | float | Analog trigger (0.0 - 1.0) |
| `grip` | float | Analog grip (0.0 - 1.0) |
| `thumbstick_x/y` | float | Thumbstick axes |
| `button_a/b` | bool | Face buttons |
| `thumbstick_click` | bool | Thumbstick press |

### Output Axes (what the drone sim expects)

| Output | Range | Description |
|--------|-------|-------------|
| `throttle` | -1.0 to 1.0 | Vertical thrust |
| `yaw` | -1.0 to 1.0 | Rotation left/right |
| `pitch` | -1.0 to 1.0 | Tilt forward/back |
| `roll` | -1.0 to 1.0 | Tilt left/right |
| `aux1..aux4` | -1.0 to 1.0 | Auxiliary channels (arm, flight mode, etc.) |

### Multi-Source Mixing

Each output axis can blend multiple input sources with weights:

```json
{
  "throttle": {
    "sources": [
      {"source": "pos_y", "weight": 1.0, "mode": "absolute"},
      {"source": "pos_z", "weight": 0.3, "mode": "absolute"}
    ],
    "dead_zone": 0.05,
    "expo": 0.2,
    "sensitivity": 1.0,
    "invert": false,
    "range_min": -0.3,
    "range_max": 0.3,
    "output_min": -1.0,
    "output_max": 1.0
  }
}
```

### Source Modes

| Mode | Behavior | Use case |
|------|----------|----------|
| `absolute` | Current position/tilt = stick deflection | Standard: deflection maps to rate (acro) or angle (level) |
| `delta` | Change in source since last frame = stick change | "Set and hold" - nudge hand to adjust |
| `velocity` | Speed of movement = stick deflection | Responsive, natural for fast movements |

### Expo Curve

`output = sign(input) * (expo * input^3 + (1 - expo) * input)`

Fine control near center, faster response at extremes. Note: drone sim firmware also applies its own expo/rates. Our expo is for *ergonomic* tuning of the controller feel, not flight dynamics. For initial testing, start with linear (expo=0) and let the sim handle flight tuning.

### Calibration

1. Hold controller in neutral position, press calibrate button
2. System records center orientation and position as reference point
3. All subsequent readings are relative to calibration center
4. Calibration saved per template

### Bundled Templates

- `simple_tilt.json` - 1:1 tilt-to-axis mapping, no mixing. Easiest to understand.
- `position_fly.json` - Position-based with throttle+pitch coupling.
- `rate_mode.json` - Angular velocity based.

## UDP Protocol

Binary protocol optimized for low latency. Quest sends, PC receives.

### Packet Format

```
Field           Size    Type      Description
─────────────────────────────────────────────────
magic           4B      bytes     "6DOF"
sequence        4B      uint32    Monotonic counter (detect drops)
timestamp       8B      uint64    Microseconds since epoch
axis_count      1B      uint8     Number of axis values
axes            N*4B    float32[] [throttle, yaw, pitch, roll, aux1..n]
button_state    2B      uint16    Bitmask of button states
```

Total: ~53 bytes per packet at 8 axes. Sent at ~100Hz over UDP. No acknowledgment - stale data is replaced by next packet in 10ms.

### Heartbeat

PC sends a 4-byte "ALIVE" packet back every second. Quest UI shows connection status based on heartbeat presence.

### Discovery

Phase 1: Manual IP configuration in Quest app.
Future: mDNS/broadcast auto-discovery.

## uinput Virtual Gamepad (Linux)

A GDExtension (C) that:
1. Opens `/dev/uinput`
2. Registers a virtual gamepad with 8 axes (ABS_X through ABS_RZ + 2 aux) and 16 buttons
3. Writes axis values received from UDP each frame
4. Device appears as `/dev/input/eventN`, visible to SDL2, evdev, and Proton

On macOS (dev mode), the extension is not loaded. The PC app still runs and shows axis visualization without a real virtual device.

## Config UI (Quest AR Overlay)

Floating panel in passthrough view:

- **Template selector**: Load, save, create, delete templates
- **Per-axis config**: Source selector, weight slider, mode toggle, dead zone, expo, sensitivity, invert, range
- **Live visualization**: Raw input bars (from controller) + mapped output bars (sent to PC) side by side
- **Calibration button**: Sets current controller pose as neutral reference
- **Connection status**: PC connected/disconnected, latency, packet rate, packet drops
- **Second controller**: Optionally used as a pointer to interact with UI while dominant hand flies

## Project Structure

```
6dof-drone-sim/
├── project.godot
├── addons/
│   └── uinput/                  # GDExtension for Linux virtual gamepad
│       ├── uinput.gdextension
│       └── src/                 # C source for uinput wrapper
├── scenes/
│   ├── quest_main.tscn          # Quest entry: XR + passthrough + config UI
│   ├── pc_main.tscn             # PC entry: UDP receiver + status UI
│   └── shared/
│       ├── config_panel.tscn    # Reusable config UI (AR or desktop)
│       └── axis_visualizer.tscn # Live axis bars
├── scripts/
│   ├── mapping/
│   │   ├── mapping_engine.gd    # Core: multi-source -> processing -> outputs
│   │   ├── mapping_template.gd  # Template resource class
│   │   └── calibration.gd       # Center-point calibration
│   ├── network/
│   │   ├── udp_sender.gd        # Quest side
│   │   └── udp_receiver.gd      # PC side
│   ├── input/
│   │   ├── xr_controller_reader.gd  # Quest: reads 6DOF from XR runtime
│   │   └── uinput_writer.gd         # PC/Linux: writes to virtual gamepad
│   └── ui/
│       ├── template_manager.gd
│       └── config_ui.gd
├── templates/                   # Bundled mapping presets
│   ├── simple_tilt.json
│   ├── position_fly.json
│   └── rate_mode.json
├── docs/
│   └── plans/
└── export_presets.cfg           # Quest (Android) + Linux + macOS targets
```

## Technology Stack

- **Engine**: Godot 4.x (latest stable with XR support)
- **Quest XR**: Godot OpenXR plugin + Meta XR toolkit
- **Language**: GDScript (main), C (uinput GDExtension)
- **Virtual gamepad**: Linux uinput kernel module via GDExtension
- **Network**: UDP via Godot's PacketPeerUDP
- **Templates**: JSON files
- **Target sim**: Liftoff (Steam, Linux native or Proton)

## Open Questions for Iteration

- Optimal send rate (100Hz may be overkill; 50Hz might suffice with interpolation)
- Whether ergonomic expo is needed or if sim-side expo is sufficient
- Best default template for first-time experience
- Whether position-based mappings need gravity compensation (controller "resting" position drifts)
- Steam Input interaction (may need to disable per-game to avoid double-mapping)

## Research References

- **Godot XR Tools**: github.com/GodotVR/godot-xr-tools - physics-based XR movement/interaction
- **DorsalVR**: github.com/MichaelJW/DorsalVR - VR motion to gamepad (Unity, prior art)
- **elrs-joystick-control**: github.com/kaack/elrs-joystick-control - USB joystick to ELRS TX (real drone bridge)
- **python-evdev**: python-evdev.readthedocs.io - uinput reference implementation
- **VR hexacopter control paper**: arxiv.org/html/2505.22599v2 - academic validation of Quest 3 drone control
- **Godot PacketPeerUDP**: docs.godotengine.org - UDP networking in Godot

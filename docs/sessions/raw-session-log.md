# Session Log: Initial Brainstorming & Design (2026-03-10)

## User's Initial Brief

> This is a completely new project around quad drones, VR and 6dof controllers. The end goal is to able to control a real drone using a 6dof controller. A stretch goal is to have the drone camera feed received and shown directly into the glasses, with an overlay of the controller positioning and inputs. So you could have the VR glasses on, the VR controller in hand, arm the drone with the controller and move the drone by moving your hand. AMAZING! I'm thinking we should leverage open source software where it exists and makes sense to use, either by using a project as is, or loaning some parts of them.
>
> This is the rough approach that I have been thinking, but if there is a better approach, we should iterate, definitely. I have many commercial drone simulators on my PC, that work with normal hid controllers and dedicated drone controllers.
>
> I was thinking that instead of building our own drone simulator, we could just build a virtual smart controller, that would translate the 6dof controls of the VR controller into normal hid inputs that the commercial games expect. That way we would only have to build the controller software first. I was thinking we could use godot and it's VR mode tools for this, because godot games and the editor itself support the Quest 3 VR headset that I happen to own. So we would stream the game to the headset via steam link for example and then the headset would also run the virtual controller software and would send the mapped inputs to the drone simulator. I think we could get a setup that allows for pretty fast iteration this way.
>
> Then if we get a very good control scheme developed and if we enjoy flying the virtual drone with this system we would look into the more complex parts, like how to control a real drone with this, send inputs to it and receive real video feed in the headset.
>
> But lets research, brainstorm and lay out plans on how to do do this. Lets write down the plan and research findings and iterate and update as we go.

## Research Findings

### Godot + Quest 3 XR

- **Godot runs natively on Quest 3** (Horizon OS). The editor itself is on the Meta Horizon Store.
- **Godot XR Tools** (`GodotVR/godot-xr-tools`): physics-based XR movement, hand/controller interaction.
- **Godot Meta Toolkit** (MIT license, maintained by W4 Games + Meta): exposes Meta Platform SDK for Quest-specific features.
- Godot 4.5+ supports universal OpenXR APK for Android headsets. Godot supports **95 official OpenXR extensions**.
- **6DOF controller tracking fully supported** via OpenXR: grip pose and aim pose (position + orientation as quaternion), velocity, angular velocity. Hand tracking also supported.
- Built-in `PacketPeerUDP` and `UDPServer` work on Quest standalone (Android under the hood) for local network communication.
- Passthrough is enabled via the Godot OpenXR Vendors plugin + `XR_ENV_BLEND_MODE_ALPHA_BLEND`.

### Virtual Gamepad / HID Emulation

- **Windows: vJoy** (most maintained), **ViGEmBus** (retired Nov 2023, LizardByte fork also archived Aug 2025). Python bindings: `pyvjoystick`.
- **Linux: uinput** kernel module. Creates virtual input devices from userspace. Appears as `/dev/input/eventN`, visible to SDL2, evdev, and Proton. Much simpler than Windows options.
- **XOutput** (`csutorasa/XOutput`): DirectInput-to-XInput converter for Windows.
- All major drone sims accept standard DirectInput joystick input, so a virtual joystick device works with all of them.

### Drone Simulators

| Simulator | Platform | Notes |
|-----------|----------|-------|
| Velocidrone | Win/Mac | Most accurate physics, competitive standard |
| Liftoff | Win/Mac/Linux | Multiple flight modes, Steam |
| DRL Simulator | Win/Mac | Cheapest, cross-platform |
| Uncrashed | Win | Modern graphics, Unreal Engine |
| DCL | Win | Supports keyboard, controller, transmitter |
| TRYP FPV | Win | Freestyle focused |

- All use **standard DirectInput joystick interface**. 4 axes (Throttle, Yaw, Pitch, Roll) + aux channels.
- Any device registering as USB HID joystick works. **Virtual joystick via uinput will work with all these sims.**
- Gamepad axes: raw signed 16-bit integers (-32768 to 32767).

### Existing Prior Art

- **DorsalVR** (`MichaelJW/DorsalVR`): Windows VR app, captures VR controller motion via OpenXR, outputs DSU (DualShock over UDP). Written in Unity. ~77 stars, somewhat dormant (Oct 2021). Closest existing project to our concept.
- **VirZOOM Gamepad Emulator** (Steam): Translates VR position tracking into standard joystick inputs for non-VR games. Proves VR-to-gamepad translation works.
- **OpenVR-InputEmulator** (`matzman666/OpenVR-InputEmulator`): Virtual controller creation/remapping for SteamVR.
- **Meta Gamepad Emulation with Touch**: Official Meta API for emulating gamepad input using Touch controllers in PC VR.
- **VR-Based Control of Multi-Copter** (academic paper, arxiv.org/html/2505.22599v2): Quest 3 controllers controlling a real hexacopter. Validates the core concept.
- **elrs-joystick-control** (`kaack/elrs-joystick-control`): Reads USB joystick input, converts to CRSF protocol, sends to ExpressLRS TX module for real drone control. This is the "virtual gamepad to real drone" bridge for the stretch goal.
- **CRSFJoystick** (`mikeneiderhauser/CRSFJoystick`): Reverse direction - CRSF receiver to USB HID joystick.

### Quest 3 Standalone vs PC Streaming

**Key constraint discovered: Quest Link/Steam Link can't reliably run alongside a standalone Quest app.** When Quest Link is active, Quest acts as a display/input device for PC. Running a separate standalone app simultaneously is not supported.

Architecture options evaluated:
- **Option A: Quest standalone + monitor** - Quest runs controller app, sends UDP to PC. Watch sim on physical monitor. Simplest, lowest latency. **But can't see sim in VR.**
- **Option B: PC-only via OpenXR** - Quest Link mode, PC reads controller data via OpenXR. Single device but OpenXR focus conflicts (only one app at a time).
- **Option C: Quest standalone + passthrough** - Same as A, but with video passthrough so user sees real world (and their physical monitor) through the headset. Can overlay AR info. **Selected approach.**

Latency numbers:
- Quest 3 native motion-to-photon: ~10-20ms
- WiFi UDP for controller data: ~1-5ms
- Quest Link adds ~20-40ms to video (controller data path is faster)

### Real Drone Control Protocols (Stretch Goal)

| Protocol | Used By | Control Capable? |
|----------|---------|-----------------|
| MSP | Betaflight, INAV | Yes (with caveats) |
| MAVLink | ArduPilot, PX4 | Yes |
| CRSF | ExpressLRS, TBS Crossfire | Yes (radio link) |
| SBUS/IBUS | FrSky, FlySky | Yes (radio link) |

- **MSP_SET_RAW_RC** sets RC channels on Betaflight. USB timing issues - UART recommended.
- **INAV supports MSP_RC_OVERRIDE**: external system overrides specific channels while real TX handles safety (important).
- `elrs-joystick-control` demonstrates the full pipeline: USB joystick -> CRSF -> serial to ELRS TX module -> radio to drone.
- **Highly feasible** for INAV/ArduPilot. Feasible with caveats for Betaflight. Safety recommendation: keep real transmitter as primary with MSP override as secondary.

## Brainstorming Q&A

### Q: Architecture for Phase 1?

Given that Quest Link/Steam Link can't reliably run alongside a standalone Quest app, three options were presented:

1. **Quest standalone + monitor** - Quest runs controller app natively, sends 6DOF data via UDP to PC. Watch sim on physical monitor.
2. **PC-only via OpenXR** - Quest connects via Quest Link. PC app reads controller data directly via OpenXR. Risk: OpenXR focus conflicts.
3. **Quest standalone + passthrough** - Same as #1 but with video passthrough enabled so user sees real world through headset. Can overlay AR controller info.

**Answer: Quest standalone + passthrough** (option 3)

### Q: How to map 6DOF controller motion to drone controls?

Three approaches offered: tilt-to-fly (intuitive), virtual stick (precise), or hybrid (configurable).

**User declined the question and clarified:**

> The control scheme is of course the most important question and there is no clear answer. The point of this project is to find a scheme that works the best and feels most natural. So we will have to build a system where we can test different schemes, have saved templates, and build new templates with the maximum amount of control over mappings dead zones, rates and everything.

### Q: Which drone simulator to target first?

**Answer: Liftoff**

### Q: Language preference for the PC-side receiver app?

Options: Python, C#/.NET, or Godot on PC too.

**Answer: Godot on PC too**

> If we can work with godot on both sides, it might be easier to combine the tools in future phases of the project where we could control a real drone and not the simulator.

### Q: Where should the mapping configuration UI live?

Options: Quest-side AR overlay, PC-side Godot app, or both (synced).

**Answer: Quest-side AR overlay**

### Q: One controller or two?

Options: One (dominant hand), two (split like RC transmitter), or configurable per template.

**Answer: One controller (dominant hand)**

> I was thinking just one controller for controlling everything for the drone. But in the app we could use the other controller to change the mapping values, so I don't have to lose control of the drone to tweak some values. But using second controller optional I think. Coffee in hand is also a good option, then you just restart the sim after changing settings with main hand controller.

### Q: Dev environment and PC platform?

Claude assumed the PC ran Windows (drone sims). User corrected:

> I'm on macos now and most development I expect to happen here. But my PC with the drone sim games actually runs Linux, and I often develop there too. So the development environment should support both macos and linux and connecting the virtual joystick/controller to the game should use a linux compatible approach. The drone sim runs either a linux native version or using steam play (proton). Steam input is also a consideration, although it can be turned off for the game if needed.

This changed the virtual gamepad approach from vJoy (Windows-only) to **uinput** (Linux kernel module).

### Q: Test the data pipeline on macOS too?

**Answer: Yes, test data pipeline on Mac too** (without sim/virtual gamepad). Full end-to-end testing only on Linux.

### Q: Project structure approach?

Three approaches presented:
- A: Single Godot project, platform-specific export targets (recommended)
- B: Two separate Godot projects
- C: Quest Godot app + Python helper on PC

**Answer: A (single Godot project)**

### Q: Architecture review — does it look correct?

**Answer: Looks good, continue**

### Q: Mapping engine design review

Initial design showed simple 1:1 source-to-output mapping. User gave detailed feedback:

> The inputs and outputs look correct. The mapping might need some rethinkin. It might need to be even more complex. The example at least is only displaying one flight mode type mapping. So the idea that from one source axis we do some mapping and map it to one output axis could be one testable control scheme. But then we also want totally different schemes like what you mentioned earlier, so just moving the controller forward from neutral position would make the drone move forward, so it would have to increase throttle AND apply some pitch at the same time. And the pitch would perhaps just send pitch outputs when the controller position moves, because if we send it continuously when the controller is pushed forward from neutral position, the drone would interpret it as the user is asking for a certain rotation speed (degrees per second). .... Oh, you actually included the tilt_to_fly and virtual_stick and rate_mode in the templates so maybe this is actually covered in the design?
>
> Another note is that most often the rate modes, expo curves and such are in the drone firmware controller itself, which has different flight modes and does the heavy lifting, and it might expect just the simple inputs of "how much stick deflection is happening currently". So that is something we have to consider too. But we will of course iterate on this and it will not be perfect on first try.

This led to three key revisions:
1. **Multi-source mixing per output axis** - each output can blend multiple sources with weights
2. **Source modes** (absolute/delta/velocity) - different ways to interpret the raw signal
3. **Clear separation of concerns** - our expo is ergonomic tuning, the sim handles flight dynamics

### Q: Revised mapping engine review

**Answer: Yes, continue to next section**

### Q: Full design review (UDP, uinput, config UI, project structure)

**Answer: Looks good, write it up**

---

## Decisions Made

### Architecture: Quest standalone + passthrough + UDP to Linux PC

```
Quest 3 (standalone, passthrough mode)
  ├─ Godot XR app
  │   ├─ XR Controller Tracker (6DOF pose, velocity, buttons)
  │   ├─ Mapping Engine (configurable, template-based)
  │   ├─ Config UI (AR overlay via passthrough)
  │   └─ UDP Sender (~100Hz mapped axis values)
  │
  ── WiFi ──
  │
Linux PC
  ├─ Same Godot project (Linux export)
  │   ├─ UDP Receiver
  │   ├─ uinput Virtual Gamepad (C helper binary)
  │   └─ Status UI
  │
  └─ Liftoff (reads virtual gamepad)
```

### Control mapping: Fully configurable, not hardcoded

The **entire point** of this project is to experiment with different mapping schemes. The system must support:
- Saved/loadable mapping templates (JSON)
- Multi-source mixing per output axis (e.g. hand-forward = throttle + pitch)
- Source modes: absolute, delta, velocity
- Per-axis: dead zones, expo curves, sensitivity, invert, range clamp
- Center-point calibration per template

**Separation of concerns**: our expo/dead zones are ergonomic tuning (making the controller feel comfortable). The drone sim/firmware handles flight dynamics (rates, PIDs). Templates should start with linear/no-deadzone and let the sim handle it, adding ergonomic tuning only as needed.

### Project structure: Single Godot project, three export targets

- Quest (Android/XR): controller tracking + mapping + config UI + UDP sender
- Linux: UDP receiver + uinput virtual gamepad + status UI
- macOS: UDP receiver + axis visualization (no uinput, dev/test mode)

### Input: One controller for flying, second optional for UI

- Dominant hand controls the drone (all 6DOF + buttons)
- Second controller optionally used as a pointer for the config UI while still flying with the main hand
- Or just put the headset down, tweak settings with the main hand, restart the sim

### Target sim: Liftoff

- Linux native or Proton via Steam Play
- Standard DirectInput joystick input
- Steam Input may need to be disabled per-game to avoid double-mapping

### Development: macOS + Linux

- Primary dev on macOS (this machine)
- Full end-to-end testing on Linux PC (uinput + Liftoff)
- UDP pipeline testable on Mac without the sim or virtual gamepad
- Virtual gamepad uses Linux **uinput** (not vJoy, which is Windows-only)

### PC side: Godot (not Python)

Keeping both sides in Godot for code sharing and future extensibility. For the real drone control phase, could potentially run the whole pipeline on Quest standalone (no PC needed) by adding serial/WiFi communication to the drone directly.

## Open Questions for Iteration

- Optimal UDP send rate (100Hz may be overkill; 50Hz might suffice)
- Whether ergonomic expo is needed or if sim-side expo is sufficient
- Best default template for first-time experience
- Whether position-based mappings need gravity compensation (controller drift)
- Steam Input interaction with the virtual joystick
- For the real drone stretch goal: direct MSP over WiFi from Quest, or PC as relay?

## Research References

- **Godot XR Tools**: github.com/GodotVR/godot-xr-tools
- **DorsalVR**: github.com/MichaelJW/DorsalVR (closest prior art)
- **elrs-joystick-control**: github.com/kaack/elrs-joystick-control (real drone bridge)
- **python-evdev**: python-evdev.readthedocs.io (uinput reference)
- **VR hexacopter paper**: arxiv.org/html/2505.22599v2
- **CRSFJoystick**: github.com/mikeneiderhauser/CRSFJoystick
- **DroidDrone**: github.com/IvanSchulz/DroidDrone (INAV/ArduPilot/Betaflight over internet)
- **Meta OpenXR SDK**: github.com/meta-quest/Meta-OpenXR-SDK
- **Godot OpenXR Vendors**: godotvr.github.io/godot_openxr_vendors

## Artifacts Produced

- `docs/plans/2026-03-10-6dof-drone-controller-design.md` - Approved design document
- `docs/plans/2026-03-10-6dof-drone-controller-implementation.md` - 14-task TDD implementation plan

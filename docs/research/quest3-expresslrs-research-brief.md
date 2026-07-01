# Quest 3 to Air65 Native Command Research Brief

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Domain glossary](../../CONTEXT.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)
- [Architecture decisions](../adr/)
- [Quest-Only Command Synthesis](./quest-only-command-synthesis.md)
- [Deep Research Synthesis](./deep-research-synthesis.md)
- [Quest-Only Hard Paths](./quest-first-hard-paths.md)
- [Command Path Architecture](./command-path-architecture.md)
- [Video Integration Plan](./video-integration-plan.md)
- [Codebase Integration Plan](./codebase-integration-plan.md)

## Mission

Prove whether the Quest 3 can become a reliable pilot input source for the BetaFPV Air65 using only Quest hardware and the Air65's onboard receiver/flight-controller path.

The research win is not "a packet was sent." The research win is an End-to-End Pilot Loop: Quest controller movement becomes stable pilot intent, travels through the Quest-Air65 Native Command Path, is accepted as real drone control input, and feels trustworthy enough to arm in a contained setting.

## Hard Constraint

The live product command loop must not require:

- A traditional RC transmitter.
- An external ExpressLRS TX module.
- A microcontroller bridge.
- USB-UART adapters, bench receivers, or logic analyzers.
- A PC, phone, or second machine in the command path.

External tools may be used only for evidence, recovery, or comparison. They are not the product answer in this research branch.

## Current Recommendation

Research order:

1. Identify the exact Air65 receiver/FC architecture and recovery route.
2. Probe the stock receiver Wi-Fi MSP tunnel on TCP `5761` from Quest while disarmed and props-off.
3. Measure Quest receiver-AP networking, OpenXR focus, controller tracking, and lifecycle behavior.
4. If stock probing fails and recovery is credible, design receiver-native firmware that accepts Quest UDP and outputs Betaflight control input.
5. Build endpoint-neutral Quest app dry-run, readiness, and diagnostics in parallel.

The current command target is:

```text
Quest Godot/OpenXR app
  -> Quest Wi-Fi networking
  -> Air65 onboard receiver path
  -> Betaflight accepts pilot control input
```

Direct Quest Wi-Fi/Bluetooth to native ExpressLRS RF is rejected for product planning unless hard primary evidence appears. External command hardware is out of scope for this pass.

Use HDMI Link only as a Control-First Validation video aid while in-app UVC capture is researched separately.

## Product Constraints

- Build Product-Shaped Slices, not throwaway demos.
- Preserve Simulator-to-Real Continuity for control feel and Flight Session language.
- Keep the Quest app responsible for the Live Pilot Station, not flight-controller behavior.
- Treat ExpressLRS as the product boundary while honestly tracking whether receiver-native firmware weakens the normal ExpressLRS RF assumption.
- Use physical Quest controllers for flight.
- Keep tuning disarmed-only, immediate, auto-saved, and in-headset.
- Keep readiness limited to programmatically checkable app state.
- Keep Control-First Validation separate from Video Integration Research.

## Primary Track: Quest-Air65 Native Command Research

Answer this question first:

Can Quest controller input become reliable Air65 control input without external command hardware?

### Command Research Questions

- What exact receiver/FC architecture is on the physical Air65 unit?
- Does the receiver expose stock ExpressLRS Wi-Fi mode from the Air65?
- Does TCP `5761` reach a working MSP tunnel from Quest to Betaflight?
- Can the MSP tunnel carry safe RC-input probes, or is it configuration-only in practice?
- If stock paths fail, can the onboard receiver firmware be modified to receive Quest UDP and output CRSF to Betaflight?
- What recovery path exists before any firmware experiment?
- How should high-level pilot intent map to RC channels at the receiver endpoint boundary?
- What app-side checks can determine receiver endpoint readiness?
- What controller tracking, focus, connection, or input conditions constitute Input Authority Risk?
- What should be logged during command research so failures can be diagnosed in-headset?
- Which automatic response policies to Input Authority Risk are safe, unsafe, or still unknown under the measured receiver/Betaflight behavior?

### Command Research Deliverables

- A short technical option map for Quest-Air65 native command paths.
- A physical Air65 identity and recovery note.
- A stock MSP tunnel probe result.
- A Quest receiver-AP networking and focus measurement result.
- A receiver-native firmware feasibility note, if warranted.
- A fake/dry-run command adapter that lets the Control Workbench and Flight Cockpit advance before live aircraft output is safe.
- A real receiver endpoint prototype only after the path is selected.
- A readiness model for command-path health.
- A diagnostic logging plan focused on command transport, input authority, timing, and mapping.
- A contained Control-First Validation plan using the Air65 and Stick Control Scheme.

## Secondary Track: Video Integration Research

Integrated FPV video inside the Quest app is the final target, but it should not block command research.

### Video Research Questions

- Can the analog video receiver's USB/HDMI capture path be accessed inside a Quest app with acceptable latency?
- If the standalone HDMI capture app works, can it run concurrently with the control app in a usable Control-First Validation arrangement?
- What Quest/Android APIs, permissions, or app lifecycle constraints affect USB video capture?
- What app-side checks can honestly report video presence?
- How should the Integrated Flight View present the Drone OSD without duplicating critical status?
- What latency, resolution, and stability trade-offs are acceptable for short-range micro FPV flight?

### Video Research Deliverables

- A concise feasibility note for in-app analog FPV capture on Quest.
- A fallback note for the HDMI capture app compromise during Control-First Validation.
- A recommendation for the first Integrated Flight View prototype.
- A list of app-side video readiness checks that are programmatically honest.

## First Product-Shaped Slice To Aim For

Build toward a Control-First Validation slice:

- Quest Control Workbench with Tunable Control Profiles, Drone Profile, Flight Binding, Channel Mapping Setup, Channel Debug Panel, Dry-Run Output Test, and Diagnostic Log View.
- Quest Flight Cockpit with passthrough default, world-locked FPV placeholder or external-video compromise, Command Visualization, RC-Style Arming state, and disarmed-only Workbench return.
- Stick Control Scheme as the first real-flight control profile.
- Real-drone Session Environment using the selected Quest-Air65 Native Command Path.
- Air65 contained flight through takeoff, maneuver, landing, and disarm.

## Keep Out Of This Research Branch

- External command bridge hardware as the product answer.
- External ELRS TX modules as the product answer.
- Traditional RC radio in the live product command loop.
- Raw Wi-Fi injection, root, bootloader unlock, or driver exploit strategies.
- Rich Natural Spatial Control exploration beyond preserving the model for later.
- FPV recording.
- Betaflight configuration as a product workflow.
- Autopilot, stabilization, navigation, or autonomous guardrails.
- Manual physical safety checklists in the app.
- Radio-agnostic abstractions.
- Multi-user or cloud profile systems.

## Success Bar

The command branch succeeds when a solo pilot can use a product-shaped Quest flow to enter the Flight Cockpit, arm with RC-Style Arming, fly the Air65 in a contained setting with Trustworthy Control Feel, land, disarm, and diagnose issues from logs if needed.

The video branch succeeds when live analog FPV appears inside the Quest app with enough latency and stability to be the normal Integrated Flight View.

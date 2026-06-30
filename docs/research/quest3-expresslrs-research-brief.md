# Quest 3 to ExpressLRS Research Brief

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Domain glossary](../../CONTEXT.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)
- [Architecture decisions](../adr/)

## Mission

Prove that the Quest 3 can become a reliable ExpressLRS pilot input source for ExpressLRS micro FPV drones, using the BetaFPV Air65 as the current Validation Aircraft.

The research win is not "a packet was sent." The research win is an End-to-End Pilot Loop: Quest controller movement becomes stable pilot intent, travels through the Command Path, is accepted as real drone control input, and feels trustworthy enough to arm in a contained setting.

## Product Constraints

- Build Product-Shaped Slices, not throwaway demos.
- Preserve Simulator-to-Real Continuity for control feel and Flight Session language.
- Keep the Quest app responsible for the Live Pilot Station, not flight-controller behavior.
- Treat ExpressLRS as the product boundary.
- Use physical Quest controllers for flight.
- Keep tuning disarmed-only, immediate, auto-saved, and in-headset.
- Keep readiness limited to programmatically checkable app state.
- Keep Control-First Validation separate from Video Integration Research.

## Primary Track: Command Research

Answer this question first:

Can Quest controller input become reliable ExpressLRS control input with Trustworthy Control Feel?

Research should identify and evaluate viable Command Path options from Quest app to ExpressLRS-controlled drone. The output should be a recommended path plus enough proof to implement a product-shaped real-drone Session Environment.

### Command Research Questions

- What ExpressLRS command-ingest options can plausibly be driven from a Quest app or Quest-adjacent bridge?
- Can the Quest's Wi-Fi/network capabilities reach the chosen command bridge with acceptable latency, jitter, reliability, and operational simplicity?
- What parts of the Command Path live inside the Quest app, and what parts require an external ExpressLRS-capable transmitter/bridge?
- How should high-level pilot intent map to RC channels at the adapter boundary?
- How should Drone Profiles represent Channel Mapping Setup without becoming Betaflight configuration?
- What app-side checks can determine Command Path readiness?
- What controller tracking, focus, connection, or input conditions constitute Input Authority Risk?
- What should be logged during command research so failures can be diagnosed in-headset?
- Which automatic response policies to Input Authority Risk are safe, unsafe, or still unknown under ExpressLRS/Betaflight behavior?

### Command Research Deliverables

- A short technical option map for Quest-to-ExpressLRS command paths.
- A recommended Command Path for the first product-shaped implementation.
- A fake or simulated command adapter that lets the Control Workbench and Flight Cockpit advance before hardware is fully solved.
- A real command adapter prototype once the path is selected.
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
- Real-drone Session Environment using the selected Command Path.
- Air65 contained flight through takeoff, maneuver, landing, and disarm.

## Keep Out Of This Research Branch

- Rich Natural Spatial Control exploration beyond preserving the model for later.
- FPV recording.
- Betaflight configuration.
- Autopilot, stabilization, navigation, or autonomous guardrails.
- Manual physical safety checklists in the app.
- Radio-agnostic abstractions.
- Multi-user or cloud profile systems.

## Success Bar

The command branch succeeds when a solo pilot can use a product-shaped Quest flow to enter the Flight Cockpit, arm with RC-Style Arming, fly the Air65 in a contained setting with Trustworthy Control Feel, land, disarm, and diagnose issues from logs if needed.

The video branch succeeds when live analog FPV appears inside the Quest app with enough latency and stability to be the normal Integrated Flight View.

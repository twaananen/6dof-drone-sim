# Quest-Native Flight Station PRD

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Domain glossary](../../CONTEXT.md)
- [Architecture decisions](../adr/)
- [Quest 3 to Air65 Native Command Research Brief](../research/quest3-expresslrs-research-brief.md)

## Problem Statement

The current drone simulator workflow uses a multi-machine setup and does not yet let a solo pilot fly a real ExpressLRS micro FPV drone using only a Quest 3 headset and Quest controllers. The target pilot wants the Quest 3 to become the primary Live Pilot Station: the place where control input, FPV video, cockpit presentation, tuning, readiness, and session flow all live.

The immediate technical ambition is hard: the Quest must become a reliable ExpressLRS pilot input source, and the app should eventually ingest the analog FPV video feed directly. The product ambition is larger than a technical demo. The Quest-Native Flight Station should eventually replace the normal FPV radio and goggles for ordinary short-range ExpressLRS micro FPV flights.

## Solution

Build a Quest-Native Flight Station for Solo Pilot Operation of ExpressLRS micro FPV drones. The first Validation Aircraft is the BetaFPV Air65, but the product boundary is ExpressLRS rather than Air65-specific.

The app provides two main spatial surfaces:

- A rich, world-locked Control Workbench for setup, tuning, dry-run testing, readiness inspection, diagnostics, and profile management.
- A quiet, world-locked Flight Cockpit for active flight, using passthrough by default, keeping FPV video dominant, and treating Quest controllers as Flight Instruments.

The Command Research Track is the primary next risk: prove an End-to-End Pilot Loop where Quest controller movement becomes stable pilot intent, traverses the Quest-Air65 Native Command Path, is accepted as real drone control input, and feels predictable enough to arm in a contained setting. The current hard research constraint is that the live product command path uses Quest hardware and the existing Air65 onboard receiver/flight-controller path, not an external bridge, TX module, PC, phone, or traditional radio. The Video Integration Research Branch runs separately: live FPV inside the app is the target, but Control-First Validation may temporarily use a separate HDMI capture app for video.

## Goals

- Replace the normal radio plus goggles for ExpressLRS micro FPV flights within the target short-range use case.
- Preserve Simulator-to-Real Continuity for Quest Control Schemes, Tunable Control Profiles, calibration concepts, Command Visualization, and Flight Session language.
- Support both simulator and real-drone Session Environments, while respecting that command and video mechanisms differ between them.
- Start with Stick Control Scheme for real-flight proof and familiar control feel.
- Make Natural Spatial Control the long-term differentiator, with experimentation treated as normal product usage.
- Keep tuning, setup, diagnostics, and readiness fully usable in-headset with Quest controllers.
- Keep active flight quiet, stable, and focused.
- Store profiles durably on device across reboots and application updates.

## User Stories

1. As a solo pilot, I want to fly an ExpressLRS micro FPV drone from the Quest 3, so that I can replace the normal radio and goggles for short-range flights.
2. As a solo pilot, I want the Quest app to feel like a complete Live Pilot Station, so that I do not need a laptop or desktop companion during normal operation.
3. As a solo pilot, I want the BetaFPV Air65 to be the first Validation Aircraft, so that the product has a concrete real-drone target.
4. As a solo pilot, I want the product to target ExpressLRS micro FPV drones broadly, so that the work is not locked to one Air65.
5. As a solo pilot, I want a simulator Session Environment and a real-drone Session Environment, so that shared control feel can exist across different command and video mechanisms.
6. As a solo pilot, I want the same Quest Control Schemes in simulator and real-drone sessions, so that practice transfers.
7. As a solo pilot, I want Tunable Control Profiles to work in both simulator and real-drone sessions, so that I can refine control feel in either environment.
8. As a solo pilot, I want a Control Workbench, so that I can tune, inspect, test, and diagnose the system without leaving the headset.
9. As a solo pilot, I want the Control Workbench to be world-locked, so that setup feels spatial and stable rather than like a flat settings screen.
10. As a solo pilot, I want setup to be fully usable with Quest controllers, so that no keyboard, mouse, desktop companion, or hand tracking is required.
11. As a solo pilot, I want hand tracking to be optional future exploration, so that the current product has one reliable interaction model.
12. As a solo pilot, I want a Flight Cockpit, so that active flight has a dedicated quiet surface separate from setup.
13. As a solo pilot, I want a Cockpit Transition before arming, so that entering the Flight Cockpit is a calm shift rather than a surprise at arming time.
14. As a solo pilot, I want RC-Style Arming in the Flight Cockpit, so that arming and disarming feel familiar and low-friction.
15. As a solo pilot, I want no arming ceremony, so that real flight is not slowed by modal confirmations.
16. As a solo pilot, I want to disarm before returning to the Control Workbench, so that setup UI cannot steal inputs during active flight.
17. As a solo pilot, I want manual return to the Control Workbench after disarming, so that disarm does not yank me out of the cockpit.
18. As a solo pilot, I want to re-arm from the Flight Cockpit after disarming, so that I can fly another attempt without returning to setup.
19. As a solo pilot, I want a passthrough cockpit by default, so that the Quest flight environment preserves awareness of my real space.
20. As a solo pilot, I want an immersive cockpit option later, so that I can choose a more focused FPV environment when useful.
21. As a solo pilot, I want the FPV view to be world-locked, so that the flight picture feels stable in space.
22. As a solo pilot, I want to move and resize the FPV view while disarmed, so that I can place it comfortably.
23. As a solo pilot, I want the FPV view to lock while armed, so that it cannot move accidentally during flight.
24. As a solo pilot, I want FPV View Placement to persist globally, so that cockpit comfort is remembered across sessions.
25. As a solo pilot, I want Command Visualization to show outgoing pilot intent, so that I can see roll, pitch, yaw, and power being sent.
26. As a solo pilot, I want Command Visualization placement to be adjustable while disarmed and locked while armed, so that it is useful without becoming unstable.
27. As a solo pilot, I want the Drone OSD to remain the primary source of flight-critical status, so that the app does not create competing truths.
28. As a solo pilot, I want Cockpit Extras to be configured from the Control Workbench, so that the Flight Cockpit stays quiet.
29. As a solo pilot, I want active-flight UI to stay quiet unless action is needed now, so that alerts do not become noise.
30. As a solo pilot, I want critical active-flight alerts to be visible even if I look away, so that urgent command, video, or input failures are not missed.
31. As a solo pilot, I want sparse Critical Audio Cues for critical state changes, so that important transitions are noticeable without constant audio clutter.
32. As a solo pilot, I want no haptics requirement for now, so that the current control feel does not depend on vibration feedback.
33. As a solo pilot, I want physical Quest controllers to be required for flight, so that Flight Instruments have reliable buttons, sticks, triggers, and tracking.
34. As a solo pilot, I want a Stick Control Scheme first, so that the first real flight uses familiar FPV controls.
35. As a solo pilot, I want Spatial Control Schemes to be first-class later, so that the Quest can become more natural than a radio.
36. As a solo pilot, I want Natural Spatial Control experimentation to be normal product usage, so that experiments are not hidden behind a developer mode.
37. As a solo pilot, I want new Spatial Control profiles to default to an Experimental Label, so that exploratory profiles are lightly marked in setup.
38. As a solo pilot, I want the Experimental Label to be removable, so that a trusted tuned profile can become ordinary.
39. As a solo pilot, I want Tunable Control Profiles, so that sensitivities and control parameters can be refined in-headset.
40. As a solo pilot, I want Tuning Controls with sliders and exact numeric entry, so that tuning is both fast and precise.
41. As a solo pilot, I want tuning changes to apply immediately while disarmed, so that the tuning loop is quick.
42. As a solo pilot, I want previous slider values visible after a change, so that accidental edits can be manually reverted.
43. As a solo pilot, I want tuning to be disallowed while armed, so that active flight remains predictable.
44. As a solo pilot, I want profile edits to auto-save, so that I do not lose tuned values between sessions.
45. As a solo pilot, I want profiles to survive reboots and application updates, so that tuning remains trustworthy.
46. As a solo pilot, I want incompatible profiles to be marked clearly after updates, so that unsafe migration is not hidden.
47. As a solo pilot, I want to duplicate profiles, so that I can branch a control feel or drone setup before experimenting.
48. As a solo pilot, I want profile deletion to require confirmation, so that tuned profiles are not deleted accidentally.
49. As a solo pilot, I want generated profile names with optional rename, so that setup minimizes typing while still allowing organization.
50. As a solo pilot, I want future export of Tunable Control Profiles, so that good control feel can be shared across devices or pilots.
51. As a solo pilot, I do not want Drone Profiles exported by default, so that aircraft-specific channel mappings are not casually reused.
52. As a solo pilot, I want Drone Profiles, so that each already-configured drone can have its own channel expectations.
53. As a solo pilot, I want Channel Mapping Setup, so that Quest controls can match the channels configured in Betaflight.
54. As a solo pilot, I want Channel Mapping Setup to stay in the Control Workbench, so that raw channel complexity does not appear in the Flight Cockpit.
55. As a solo pilot, I want a Channel Debug Panel, so that I can verify live raw channel values during setup.
56. As a solo pilot, I want a Dry-Run Output Test, so that I can inspect intended outputs without sending them to the simulator or real drone.
57. As a solo pilot, I want Dry-Run Output Test to use the same Command Visualization as the Flight Cockpit, so that setup rehearses flight-time interpretation.
58. As a solo pilot, I want a Flight Binding, so that one Drone Profile and one Tunable Control Profile are selected for the session.
59. As a solo pilot, I want the Last Good Binding restored per Drone Profile, so that good UX does not require repeated profile selection.
60. As a solo pilot, I want the current Flight Binding visible before arming, so that consequential choices are not hidden.
61. As a solo pilot, I want readiness to show only programmatically checkable state, so that the app does not perform fake safety theater.
62. As a solo pilot, I want Automated Readiness Checks to inform me about app-detectable readiness, so that setup mistakes are easier to catch.
63. As a solo pilot, I do not want manual physical safety checkboxes in the app, so that physical operating discipline stays outside the UI.
64. As a solo pilot, I want command-path details inspectable in setup, so that I can diagnose readiness without thinking about plumbing during flight.
65. As a solo pilot, I want Input Authority Risk to be treated as urgent, so that unreliable controller input is not mistaken for minor UI degradation.
66. As a solo pilot, I want automatic response to Input Authority Risk deferred until researched, so that the app does not choose a harmful failsafe policy prematurely.
67. As a solo pilot, I want Control-First Validation to be allowed with a separate HDMI capture app, so that command research is not blocked by video integration.
68. As a solo pilot, I want live FPV video integrated into the Quest app eventually, so that the final product is not a two-app cockpit.
69. As a solo pilot, I want real-drone sessions without integrated video to be labeled as Control-First Validation, so that the product remains honest about completeness.
70. As a solo pilot, I want no FPV recording scope for now, so that low-latency display and control remain the focus.
71. As a solo pilot, I want a Diagnostic Log file, so that command, video, tuning, and readiness issues can be diagnosed.
72. As a solo pilot, I want a collapsed-by-default Diagnostic Log View, so that I can inspect and filter logs in-headset when needed.
73. As a solo pilot, I want the Diagnostic Log View outside the Flight Cockpit, so that active flight is not polluted by log panels.
74. As a solo pilot, I want the app to avoid Betaflight configuration, so that drone bench setup remains outside the Live Pilot Station.
75. As a solo pilot, I want the app to use already-configured drone functions through control channels, so that arming and Drone Flight Mode selection can be controlled without becoming a configurator.
76. As a solo pilot, I want early research to produce Product-Shaped Slices, so that hard technical work stays attached to the final experience.
77. As a solo pilot, I want the First Real-Flight Demo to prove the integrated spine, so that success means more than sending packets.
78. As a solo pilot, I want Control-First Validation to prove the End-to-End Pilot Loop, so that the Quest feels safe enough to arm in a contained setting.
79. As a solo pilot, I want External Safety Fallback available during experiments but outside the product workflow, so that validation can be careful without shaping the app around test scaffolding.
80. As a solo pilot, I want no multi-user account system, so that the headset remains a Single-Pilot Device for now.

## Product Model

### Surfaces

- **Control Workbench**: the rich world-locked Setup Surface. It contains profile lists, profile tuning, Flight Binding selection, Channel Mapping Setup, Channel Debug Panel, Dry-Run Output Test, environment-specific readiness, Diagnostic Log View, and placement controls for cockpit visuals.
- **Flight Cockpit**: the quiet flight-time surface. It uses passthrough by default, presents the FPV view and Flight Instruments as world-locked surfaces, keeps Cockpit Extras sparse, and supports RC-Style Arming.
- **Cockpit Transition**: a separate enter-cockpit action before arming. It visually quiets the environment and signals that Quest controllers are becoming Flight Instruments.

### Session Environments

- **Simulator**: shares Quest Control Schemes, Tunable Control Profiles, Command Visualization, Control Workbench, and Flight Cockpit concepts with real flight. It uses simulator-specific command and video mechanisms.
- **Real drone**: uses Drone Profiles, Channel Mapping Setup, real Command Path readiness, real video readiness, and the same control-profile/tuning concepts.

### Profiles And Binding

- **Tunable Control Profile**: captures control feel for a Quest Control Scheme. It is adjustable in-headset, auto-saved, device-persistent, duplicable, optionally experimental, and eventually exportable.
- **Drone Profile**: captures an already-configured drone's expected channel mapping and related drone-specific expectations. It is device-persistent and duplicable, but not exported by default.
- **Flight Binding**: pairs one Drone Profile and one Tunable Control Profile for a Flight Session.
- **Last Good Binding**: restored per Drone Profile and shown before arming.

### Readiness

Readiness must be limited to programmatically checkable app state. It may include selected Flight Binding, selected Session Environment, control calibration, command-path health, app-side video presence, controller tracking/input state, emergency command availability, and profile compatibility. It must not include manual physical safety checkboxes.

### Control

The Quest app owns the pilot station, not the flight controller. It maps pilot intent, presents controls and status, expresses arming/mode intent through configured channels, and surfaces urgent command/input/video issues. It does not stabilize the drone, become an autopilot, configure Betaflight, flash firmware, or maintain the aircraft.

### Video

The final target is an Integrated Flight View with live FPV inside the app. Control-First Validation may use a separate HDMI capture app as a temporary compromise. No FPV recording is in scope for now.

## Implementation Decisions

- Use Product-Shaped Slices for research and implementation. Even rough prototypes should exercise Flight Session, Quest Control Scheme, Flight Cockpit, Readiness State, and profile concepts.
- Treat the Command Research Track as the main risk. The first research target is the Quest-Air65 Native Command Path and the End-to-End Pilot Loop, not a whole-cockpit build or an external command-hardware workaround.
- Keep Video Integration Research separate from command validation. Integrated video remains the product target but should not block Control-First Validation.
- Preserve Simulator-to-Real Continuity at the product model and control-feel level while allowing Session Environment-specific command and video adapters.
- Introduce or evolve a high-level Flight Session orchestration seam that can bind Session Environment, Flight Binding, readiness, cockpit/workbench state, and armed/disarmed transitions.
- Introduce or evolve a profile persistence seam for Tunable Control Profiles, Drone Profiles, Last Good Bindings, duplication, deletion confirmation, generated names, auto-save, migration, and incompatibility marking.
- Keep Quest Control Scheme and Tunable Control Profile separate from Drone Profile and Channel Mapping Setup.
- Model cockpit command intent in high-level terms such as roll, pitch, yaw, power, arm, and mode intent, then map to channels at the drone/adapter boundary.
- Keep Channel Mapping Setup, raw channel display, and Diagnostic Log View in the Control Workbench.
- Keep the Flight Cockpit stable and sparse. Cockpit Extras are configured from the Control Workbench for now.
- Treat physical Quest controllers as the current required Flight Instruments. Hand tracking may be additive later but should not be required.
- Treat profile tuning as disarmed-only, immediately applied, auto-saved, and supported by visible previous-value hints.
- Make RC-Style Arming available in the Flight Cockpit without a modal ceremony.
- Enter the Flight Cockpit before arming. Require disarm before returning to the Control Workbench. Do not auto-return after disarm.
- Use world-locked surfaces across both Control Workbench and Flight Cockpit. Only truly critical active-flight alerts may briefly follow view.
- Use passthrough as the default Flight Cockpit environment, with an immersive cockpit option deferred.
- Trust Drone OSD as the primary flight-critical status source for early real flights. Avoid duplicate Quest-rendered truth for armed state, Drone Flight Mode, and battery unless later justified.
- Defer automatic failsafe, disarm, or command-hold response to Input Authority Risk until the real ExpressLRS and Betaflight behavior is researched.
- Avoid issue-tracker or desktop-only workflows for normal pilot operation. Development tooling may exist, but the product workflow is in-headset.

## Testing Decisions

- Test product behavior at the highest practical seam. Prefer tests that exercise Flight Session state transitions, profile persistence, command mapping, and readiness outcomes rather than implementation details.
- Extend existing Godot/GUT unit and integration test style.
- Keep mapping tests focused on external behavior: input state plus selected Tunable Control Profile plus Drone Profile should produce expected pilot intent and channel output.
- Add profile-store tests for auto-save, generated names, duplication, deletion confirmation state, migration, incompatible-profile marking, Last Good Binding restoration, and reboot/update durability assumptions.
- Add session tests for Workbench to Cockpit transition, arming/disarming state, re-arm behavior, disarmed-only tuning, and disarmed-only Workbench return.
- Add readiness tests for simulator and real-drone Session Environments, verifying that only programmatically checkable state contributes to readiness.
- Add command-path adapter tests with fake transports before hardware integration, verifying command shape, rate behavior, connection state, and diagnostics.
- Add input-authority tests for controller tracking/input/focus degradation, verifying urgent surfacing while leaving automatic response policy undecided.
- Add UI scene or integration checks for world-locked Control Workbench and Flight Cockpit composition where practical.
- Add Diagnostic Log tests for file writing, collapsed-by-default view state, and search-term filtering.
- Add manual hardware validation scripts or runbooks for the Air65 only after command-path research identifies the actual transport path.
- Do not treat contained real flight as a substitute for automated tests. Automated tests should protect app behavior; real flight validates control feel and hardware reality.

## First Product-Shaped Slices

1. **Workbench profile slice**: in-headset Control Workbench with Tunable Control Profile list, generated names, duplicate/delete, immediate tuning controls, auto-save, and Dry-Run Output Test.
2. **Binding and channel slice**: Drone Profile, Channel Mapping Setup, Flight Binding, Last Good Binding, and Channel Debug Panel.
3. **Simulator continuity slice**: same Tunable Control Profile and Command Visualization used in simulator Session Environment.
4. **Cockpit state slice**: Cockpit Transition, Flight Cockpit, RC-Style Arming UI state, disarmed-only return, cockpit re-arm, and locked visual placement while armed.
5. **Command research slice**: real-drone Session Environment with a receiver endpoint adapter capable of proving the End-to-End Pilot Loop against the selected Quest-Air65 Native Command Path.
6. **Control-First Validation slice**: contained Air65 flight with Quest control, Stick Control Scheme, RC-Style Arming, and video supplied by the HDMI capture app if integrated video is not ready.
7. **Video integration slice**: analog FPV feed appears inside the Quest app as the Integrated Flight View without blocking command validation.

## Out Of Scope

- Radio-agnostic drone support.
- Non-ExpressLRS control ecosystems.
- Long-range flight, autonomous flight, cinematic missions, or outdoor polish beyond short-range ordinary use.
- Drone stabilization, autopilot behavior, navigation, or autonomous guardrails.
- Betaflight configuration, firmware flashing, bench setup, maintenance, battery handling, and physical safety checklists.
- Mandatory arming ceremonies.
- Manual pilot-confirmed checklist items inside the app.
- FPV video recording or DVR/file-management features.
- Multi-user accounts or team pilot management.
- Cloud-first profiles.
- Drone Profile export by default.
- Required hand tracking.
- Required haptic feedback.
- User-facing flight history, replay, or analytics.

## Open Questions

- Can the existing Air65 onboard receiver path become a reliable Quest-Air65 Native Command Path while preserving Trustworthy Control Feel?
- Does the stock receiver MSP tunnel provide a no-flash command ingress, or is receiver-native firmware required?
- What ExpressLRS/Betaflight behavior should drive the eventual response to Input Authority Risk?
- What is the lowest-latency feasible path for analog FPV capture inside the Quest app?
- Can the HDMI capture app and the Quest control app run in a useful split arrangement during Control-First Validation?
- What app-side video presence checks are possible and meaningful on Quest?
- What command-rate, latency, jitter, and loss characteristics are acceptable for contained real flight and normal short-range use?
- What Natural Spatial Control profiles feel promising enough to become non-experimental?

## Further Notes

The project should stay ambitious without becoming vague. The long-term vision is a Complete FPV Station Replacement for ExpressLRS micro FPV flights. The near-term research should stay product-shaped: every useful prototype should look like part of the eventual Quest-Native Flight Station, not a disconnected packet demo.

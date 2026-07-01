# Quest-Native Drone Flight

This context describes the target experience for flying a real micro drone from a Quest headset. It defines the product and domain language, not the implementation plan.

## Language

**Quest-Native Flight Station**:
A headset-centered flight setup where the Quest 3 is the pilot's primary control and video environment for real drone flight. It replaces the normal laptop and traditional RC transmitter during the ordinary flight session.
_Avoid_: multi-machine setup, companion headset, simulator-only station

**Complete FPV Station Replacement**:
The product ambition that the Quest-Native Flight Station replaces the normal FPV radio and goggles for ExpressLRS micro FPV flights. The pilot should be able to conduct an ordinary short-range Flight Session without wishing they had brought the traditional FPV stack.
_Avoid_: experimental controller, companion display, partial FPV station

**Live Pilot Station**:
The part of the FPV workflow the Quest-Native Flight Station replaces: goggles, radio controls, cockpit presentation, control feel, and the active Flight Session experience. It does not include drone maintenance, battery handling, Betaflight configuration, firmware flashing, or bench setup tools.
_Avoid_: maintenance station, Betaflight configurator, all-drone workstation

**Contained Real Flight**:
A safety-bounded live flight used to prove the Quest-Native Flight Station can command and monitor the drone in the real world. It may be physically constrained or closely supervised, but it must exercise the core controls needed for ordinary short-range flight.
_Avoid_: lab demo, bench test, simulator validation

**Short-Range Outdoor Flight**:
An ordinary nearby FPV flight where the drone stays close enough for conservative visual, radio, and recovery assumptions. It is the practical design target beyond the first contained validation.
_Avoid_: long-range flight, expedition flight, cinematic mission

**External Safety Fallback**:
A separate controller or human safety arrangement available during early validation flights. It is outside the Quest-Native Flight Station product surface, is not an alternate product Command Path, and should not shape the normal Quest app workflow.
_Avoid_: built-in fallback, product safety mode, secondary control path, product fallback transport

**Stick Control Scheme**:
A Quest control scheme that preserves the normal FPV sticks-and-switches mental model. It is the first proof control experience for real flight and a durable fallback control style.
_Avoid_: basic mode, legacy mode, simulator mode

**Spatial Control Scheme**:
A Quest control scheme that uses headset or controller movement as part of the flight input experience. It is the long-term focus of the product after the Stick Control Scheme proves the real flight path.
_Avoid_: gesture gimmick, motion-only control, replacement for validation

**Natural Spatial Control**:
The long-term goal for Spatial Control Schemes: a way of flying ExpressLRS micro FPV drones that feels more natural, embodied, or learnable than a traditional FPV radio for the target short-range flights. It is expected to require experimentation in either simulator or real-drone Session Environments.
_Avoid_: radio imitation, novelty gesture control, one-shot control design

**Experimental Control Profile**:
A Tunable Control Profile that is still being explored or tuned, especially for Natural Spatial Control. It is part of normal product usage and flows through the same setup, binding, tuning, and flight surfaces as other profiles, with light labeling in setup rather than active-flight warning noise.
_Avoid_: developer mode, hidden test path, lab-only profile

**Experimental Label**:
An optional label on a Tunable Control Profile indicating that the profile is still being explored. New Spatial Control profiles should default to this label, while the pilot can remove it when the tuned profile is trusted.
_Avoid_: maturity ladder, certification status, flight warning

**Drone Flight Mode**:
A flight-controller behavior mode such as Angle, Horizon, or Acro that changes how the drone interprets pilot commands. It belongs to the drone and flight-controller domain, not the Quest input mapping domain.
_Avoid_: Quest mode, control scheme

**Quest Control Scheme**:
A mapping from Quest headset and controller inputs into pilot commands. It belongs to the Quest-Native Flight Station and is distinct from Drone Flight Mode.
_Avoid_: flight mode, Betaflight mode

**Pilot Station Responsibility**:
The responsibilities owned by the Quest-Native Flight Station: presenting video and status, mapping pilot inputs, expressing arming and mode-selection intent, and issuing explicit emergency commands. It does not include stabilizing, navigating, or autonomously controlling the drone.
_Avoid_: autopilot responsibility, flight-controller responsibility

**Integrated Flight View**:
The in-app Quest experience where live FPV video, control state, and essential flight status appear together. A separate HDMI capture app can support investigation, but it is not the target pilot experience.
_Avoid_: two-app cockpit, external video viewer, capture-app-only flight

**FPV View Placement**:
The global cockpit setting for positioning and sizing the live FPV view on the headset. The pilot can adjust placement while disarmed, and the view locks while armed to prevent accidental movement during flight.
_Avoid_: fixed-only screen, armed resizing, accidental video movement

**World-Locked Cockpit Surface**:
A cockpit visual surface anchored in the pilot's surrounding space rather than attached to head movement. FPV view and flight instruments should be world-locked by default, with only truly critical active-flight alerts allowed to briefly follow view before settling back into the cockpit surface.
_Avoid_: head-locked cockpit, face-attached screen, drifting instrument surface

**Flight Cockpit**:
The flight-time surface of the Quest-Native Flight Station. It keeps live FPV video dominant and shows only information or controls that are useful during active flight.
_Avoid_: full dashboard, settings view, configuration mode

**Passthrough Cockpit**:
The default Flight Cockpit environment where the live FPV feed and flight instruments appear over Quest passthrough instead of a fully dark or purely virtual room. It supports solo-pilot awareness while keeping FPV video dominant.
_Avoid_: black-box cockpit, VR-only cockpit, fully occluded environment

**Immersive Cockpit Option**:
A future optional Flight Cockpit environment that reduces or removes passthrough for a more focused FPV view. It is not the default direction.
_Avoid_: default VR cockpit, first-scope environment, passthrough replacement

**Setup Surface**:
The non-flight surface of the Quest-Native Flight Station where the pilot configures control schemes, inspects details, and prepares for flight. It may expose richer controls and information than the Flight Cockpit.
_Avoid_: flight mode, cockpit, debug panel

**Control Workbench**:
The rich world-locked Setup Surface area for designing, tuning, testing, and diagnosing Quest Control Schemes and profiles. It should support profile lists, tuning controls, dry-run preview, channel debugging, and diagnostics while remaining usable with Quest controllers.
_Avoid_: simple settings page, desktop workbench, cockpit dashboard

**Cockpit Transition**:
The clear visual and interaction shift from the Control Workbench into the Flight Cockpit. It should make the environment quiet down and signal that Quest controllers are becoming Flight Instruments.
_Avoid_: abrupt context switch, hidden state change, decorative-only transition

**Disarmed Workbench Return**:
The rule that the pilot must disarm before leaving the Flight Cockpit for the Control Workbench, and then return manually through a subtle disarmed-only affordance. It protects Flight Instrument behavior without forcing an automatic workbench return after disarm.
_Avoid_: armed workbench, mid-flight tuning return, cockpit escape while armed, automatic workbench return

**Controller-Only Setup**:
The requirement that normal setup tasks can be completed entirely in-headset with Quest controllers. Hand tracking may be additive later, but profile tuning, channel mapping, dry-run testing, readiness inspection, and diagnostics should not require keyboard, mouse, desktop companion tools, or hand tracking.
_Avoid_: desktop-required setup, keyboard-only tuning, companion-tool workflow, hand-tracking-required setup

**Tuning Control**:
A setup UI control for adjusting Tunable Control Profile values, using sliders as the primary interaction and selectable numeric fields for exact virtual-keyboard entry. Changes apply immediately while disarmed, and the slider may show the previous value in a different color to support manual reversion.
_Avoid_: code-only parameter, desktop numeric edit, imprecise-only slider, apply-only tuning

**Channel Mapping Setup**:
The first-time or occasional setup step where Quest pilot controls are mapped to the RC channels expected by the drone's Betaflight configuration. It belongs in the Setup Surface and should not be exposed as cockpit complexity during active flight.
_Avoid_: flight-time channel tuning, Betaflight configuration, cockpit channel table

**Channel Debug Panel**:
A setup-only tool that shows live raw channel values for verifying Channel Mapping Setup before flight. It is separate from Command Visualization and should not appear in the Flight Cockpit by default.
_Avoid_: cockpit channel table, flight-time mapping UI, Betaflight configurator

**Dry-Run Output Test**:
A setup tool where Quest controls produce intended pilot commands and channel values without sending them to the simulator or real drone. It uses the same Command Visualization as the Flight Cockpit while setup can also show raw channel details.
_Avoid_: bench flight, hidden test mode, simulator replacement

**Flight Session**:
A complete use of the Quest-Native Flight Station in either simulator or real-drone Session Environment, from setup and preflight through active flight and postflight review. The session lifecycle determines which information and controls belong on screen at each moment.
_Avoid_: app run, video session, hidden runtime

**Session Environment**:
The selected environment for a Flight Session, either simulator or real drone. Simulator and real-drone sessions share Quest Control Schemes, Tunable Control Profiles, and cockpit concepts, but use different command and video mechanisms.
_Avoid_: drone profile, transport mode, hidden runtime

**Drone OSD**:
Flight-controller status rendered into the FPV video feed before the Quest receives it. It may include armed state, Drone Flight Mode, battery, and other flight-critical information.
_Avoid_: Quest overlay, app telemetry, external dashboard

**Cockpit Extras**:
Optional information or controls shown by the Quest app during active flight beyond the dominant FPV video and Drone OSD. They are configured from the Control Workbench rather than adjusted inside the Flight Cockpit for now.
_Avoid_: mandatory overlays, default clutter, debug readouts

**Trustworthy Control Feel**:
The pilot's confidence that Quest inputs produce predictable, low-latency, recoverable drone behavior during real flight. It includes centering, dead zones, arming friction, loss-of-input behavior, and the subjective feel needed to fly without thinking about the command transport.
_Avoid_: channel output, input plumbing, technical control

**Flight Instrument**:
A Quest controller role during armed or active flight where input is dedicated to flying and critical commands. A Flight Instrument should not unexpectedly behave like a menu pointer, configuration control, or general UI device.
_Avoid_: UI controller, pointer, menu hand

**Quest Controller Requirement**:
The current requirement that real flight uses physical Quest controllers as Flight Instruments. Hand tracking may be explored later but is not part of the current flight control assumption.
_Avoid_: hand-tracking flight, controller-optional flight, gesture-only input

**Command Visualization**:
A flight-time visual aid showing the current Quest controller posture and outgoing pilot intent, such as roll, pitch, yaw, and power. Its placement is globally adjustable while disarmed and locked while armed, and it earns its place by improving Trustworthy Control Feel rather than acting as telemetry from the drone.
_Avoid_: decorative controller model, confirmed telemetry, full dashboard

**Command Path**:
The end-to-end route by which pilot intent from the Quest reaches the drone as control input. It should be invisible during active flight but inspectable during setup and preflight.
_Avoid_: Wi-Fi plumbing, transport details, radio implementation

**Quest-Air65 Native Command Path**:
The strict research target where the Quest 3 uses only its built-in hardware and app-accessible OS APIs to send pilot intent to the existing Air65 onboard receiver or receiver-adjacent firmware, without external command hardware in the live command loop.
_Avoid_: bridge architecture, TX module accessory, PC-assisted command path, traditional radio path

**Receiver-Native Command Mode**:
A possible Air65 receiver-side mode where the onboard receiver accepts Quest-originated network commands and outputs normal control input to Betaflight, such as CRSF channel frames or a verified MSP control path. It may be stock, if the receiver's existing Wi-Fi/MSP tunnel can do it, or custom firmware if the hardware and recovery story are proven.
_Avoid_: Quest RF transmission, Betaflight configuration mode, external bridge mode

**Stock MSP Tunnel Probe**:
A no-flash research experiment that tests whether the Air65's stock ExpressLRS receiver Wi-Fi mode exposes an MSP-over-TCP path to Betaflight that can carry safe RC-input probes while disarmed and props-off. It is evidence-gathering, not a product decision to make the app a Betaflight configurator.
_Avoid_: configurator workflow, proof of live RC by assumption, firmware flash prerequisite

**Out-of-Product Command Hardware**:
Hardware such as external ELRS TX modules, microcontroller bridges, USB-UART adapters, bench receivers, or logic analyzers that may help with evidence, recovery, or comparison, but is excluded from the Quest-Air65 Native Command Path and must not become the normal product command loop without a new product decision.
_Avoid_: hidden product bridge, shopping-list research, fallback architecture by default

**Readiness State**:
The pilot-facing answer to whether the Quest-Native Flight Station is prepared for flight. It summarizes the pieces needed for safe operation without exposing low-level plumbing during active flight.
_Avoid_: debug status, connection details, implementation state

**Preflight Checklist**:
A pilot-visible readiness summary before arming, limited to things the Quest app can check programmatically, such as app-side video presence, Command Path health, control calibration, emergency command availability, and selected Quest Control Scheme. It guides the pilot without requiring a mandatory click-through before every arm.
_Avoid_: arming wizard, forced checklist, manual safety checklist, blocking setup flow

**RC-Style Arming**:
A familiar arming and disarming interaction modeled after ordinary RC transmitter use. It should be deliberate and visually clear, but not require a modal confirmation ceremony.
_Avoid_: arming ceremony, confirmation dialog, click-through arming

**Cockpit Re-Arm**:
The ability to arm again from the Flight Cockpit after disarming, without returning to the Control Workbench. Returning to the workbench is only needed when the pilot wants to change setup or tuning.
_Avoid_: forced setup return, one-arm cockpit, mandatory preflight loop

**Flight Attention Policy**:
The rule that active-flight UI stays quiet unless the pilot needs to act now. Degradation should appear as calm peripheral status when possible, while urgent loss of command, video, or controller input may interrupt attention.
_Avoid_: alert-heavy cockpit, silent failure, debug-first alerts

**Critical Audio Cue**:
A sparse sound used for critical state changes such as arm/disarm, Input Authority Risk, or command/video loss. It supports attention without becoming constant audio clutter or voice-driven guidance.
_Avoid_: decorative UI audio, constant alerts, voice prompt system

**Input Authority Risk**:
An urgent active-flight condition where the Quest app can no longer trust controller tracking, controller connection, app focus, or input sampling as a reliable source of pilot commands. It means the pilot's command surface may no longer be trustworthy.
_Avoid_: degraded UX, minor tracking issue, cosmetic warning

**Simulator-to-Real Continuity**:
The expectation that Quest Control Schemes, calibration concepts, Command Visualization, and Flight Session language transfer between the simulator and real drone flight even though command and video mechanisms differ by Session Environment. The simulator is the proving ground for Trustworthy Control Feel before live flight.
_Avoid_: separate simulator UX, real-only controls, throwaway sim mappings

**First Real-Flight Demo**:
The first ambitious proof of the Quest-Native Flight Station: simulator-proven controls, a Quest Flight Cockpit, live real-drone FPV in the app if possible, RC-Style Arming, Stick Control Scheme, and a contained Air65 flight through takeoff, maneuver, landing, and disarm.
_Avoid_: bench demo, channel test, two-app proof

**Validation Aircraft**:
The concrete drone used to prove the product in real flight. The BetaFPV Air65 is the current Validation Aircraft, while the broader target is ExpressLRS micro FPV drones.
_Avoid_: only supported drone, product boundary, aircraft lock-in

**ExpressLRS Micro FPV Drone**:
A small FPV drone controlled through ExpressLRS. This is the broader aircraft class the Quest-Native Flight Station should support beyond the current Validation Aircraft.
_Avoid_: Air65-only drone, simulator drone, long-range platform

**ExpressLRS Product Boundary**:
The product scope that the Quest-Native Flight Station targets ExpressLRS as its control ecosystem. Other radio systems are outside the current product definition.
_Avoid_: radio-agnostic product, all-drone support, generic RC ecosystem

**Control-First Validation**:
An early real-flight validation that focuses on the Quest Command Path and Trustworthy Control Feel while allowing video to come from a separate HDMI capture app. It is a legitimate milestone but not the final Integrated Flight View.
_Avoid_: full cockpit demo, product-complete flight, video integration proof

**Normal Real-Drone Session**:
A real-drone Flight Session where video is available as part of the pilot station. If video is absent or only available through a separate HDMI capture app, the session belongs to Control-First Validation rather than normal product use.
_Avoid_: video-free flight, command-only product session, blind cockpit

**Video Integration Research Branch**:
The separate research branch for bringing the analog FPV feed into the Quest app itself. It supports the Integrated Flight View target but should not block Control-First Validation.
_Avoid_: control prerequisite, first-flight blocker, capture-app dependency

**No FPV Recording Scope**:
The boundary that the Quest-Native Flight Station focuses on live low-latency video display and does not record FPV video for now.
_Avoid_: DVR feature, flight recorder, video file management

**Command Research Track**:
The primary research track for proving the Quest can become a reliable ExpressLRS pilot input source for ExpressLRS micro FPV drones, using the current Validation Aircraft for practical testing. It focuses on the Command Path and Trustworthy Control Feel before broader cockpit completeness.
_Avoid_: whole-cockpit research, video-first research, generic connectivity

**End-to-End Pilot Loop**:
The complete loop where Quest controller movement becomes stable pilot intent, travels through the Command Path, is accepted as real drone control input, and feels predictable enough to arm in a contained setting. It is the success bar for the Command Research Track.
_Avoid_: packet proof, channel smoke test, transport-only success

**Product-Readiness Orientation**:
The principle that design, research, and implementation should be shaped by the final Quest-Native Flight Station experience from the beginning. Early work may be incomplete, but it should still exercise product-shaped decisions rather than isolated technical proofs.
_Avoid_: evidence ladder, throwaway validation, demo-only milestone

**Product-Shaped Slice**:
An early milestone that uses the concepts and interaction shape of the final Quest-Native Flight Station even when the underlying implementation is rough or incomplete. It should exercise the real Flight Session, Quest Control Scheme, Flight Cockpit, and Readiness State concepts rather than a disconnected technical demo.
_Avoid_: throwaway prototype, bench-only proof, research toy

**Solo Pilot Operation**:
The normal workflow where one pilot prepares, flies, lands, and reviews a short-range Flight Session from inside the Quest headset. External helpers or fallback equipment may be used during experiments but are not part of the product workflow.
_Avoid_: two-person operation, ground-station operator, assisted flight workflow

**Single-Pilot Device**:
The assumption that one pilot owns and uses the headset's local profiles and settings. Multi-user accounts are outside the current product definition.
_Avoid_: user accounts, shared household profiles, team pilot management

**Automated Readiness Check**:
An app-generated assessment that informs the solo pilot whether programmatically detectable parts of the Preflight Checklist appear ready. It assists preparation when possible but does not include manual pilot-confirmed items or turn preflight into a mandatory ritual.
_Avoid_: forced gate, arming ceremony, autonomous safety approval, pilot-confirmed checklist

**Tunable Control Profile**:
A saved Quest Control Scheme configuration whose sensitivities, parameters, and optional experimental label can be adjusted in-headset during setup. It supports quick iteration toward Trustworthy Control Feel.
_Avoid_: fixed preset, hidden tuning, desktop-only profile

**Profile Duplication**:
The setup action of copying a Tunable Control Profile or Drone Profile before experimentation or reuse. It supports auto-save and immediate tuning by giving the pilot a simple way to branch a control feel or drone setup without a full history system.
_Avoid_: version history, unsaved draft, destructive experimentation

**Profile Naming**:
The profile-labeling behavior where new profiles receive generated names and can be renamed with the Quest virtual keyboard. It minimizes typing during Controller-Only Setup while still allowing meaningful organization.
_Avoid_: required naming step, unnamed profile, desktop rename

**Profile Deletion Confirmation**:
A deliberate confirmation modal required before deleting a Tunable Control Profile or Drone Profile. It protects persistent tuning and drone setup data without implying that flight controls such as arming should use modal ceremonies.
_Avoid_: accidental delete, no-confirm destructive action, arming ceremony

**Profile Portability**:
The future ability to export and share Tunable Control Profiles across devices or pilots. It does not include Drone Profiles by default, because drone channel mappings are tied to a specific aircraft's Betaflight setup.
_Avoid_: drone profile export, cloud-first profiles, first-demo requirement, headset-locked assumption

**Device-Persistent Profile**:
A Tunable Control Profile or Drone Profile stored on the Quest headset so it survives reboots and application updates. Profile changes should auto-save because tuning and Last Good Binding depend on durable profile state.
_Avoid_: session-only profile, volatile tuning, update-lost settings, unsaved profile edits

**Profile Migration**:
The app-update behavior that preserves Device-Persistent Profiles when profile formats change. Profiles should migrate automatically when possible and be clearly marked incompatible in setup when safe migration is not possible.
_Avoid_: silent profile mutation, deleted tuning, hidden incompatibility

**Diagnostic Log**:
A file-level record the app may write for troubleshooting command, video, tuning, or readiness behavior. It may be viewed in the Setup Surface through a simple searchable log view, but it is not a flight history or analytics feature.
_Avoid_: flight history, replay log, profile usage timeline, cockpit log panel

**Diagnostic Log View**:
A collapsed-by-default Setup Surface panel for viewing Diagnostic Log lines in-headset and filtering them by a search term such as errors or warnings. It supports debugging and diagnosis without entering the Flight Cockpit.
_Avoid_: active-flight log, analytics dashboard, full observability console

**Drone Profile**:
A saved configuration for an already-configured drone, including the Channel Mapping Setup needed to match that drone's Betaflight channel expectations. It is separate from Tunable Control Profiles so the same control feel can be reused across different drones.
_Avoid_: control profile, Betaflight config, per-drone control feel

**Flight Binding**:
The selected pairing of one Drone Profile and one Tunable Control Profile for a Flight Session. It should be visible in setup and preflight because both the drone's expected channels and the pilot's control feel are required for safe control.
_Avoid_: hidden defaults, merged profile, flight mode

**Last Good Binding**:
The most recently successful Flight Binding for a Drone Profile. The app should restore it for good solo-pilot UX while still making the selected pairing visible before arming.
_Avoid_: forced profile selection, hidden pairing, blank default

**Quick Tuning Loop**:
The short cycle of adjusting a Tunable Control Profile while disarmed, trying it, and refining it without leaving the Quest headset. It is a core way the solo pilot dials in control feel and should work for both simulator and real-drone sessions.
_Avoid_: offline tuning, long edit-test cycle, code-only tuning, simulator-only tuning

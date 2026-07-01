# Codebase Integration Plan

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Quest-Only Command Synthesis](./quest-only-command-synthesis.md)
- [Deep Research Synthesis](./deep-research-synthesis.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)
- [Quest 3 to Air65 Native Command Research Brief](./quest3-expresslrs-research-brief.md)

## Goal

Map the current Godot codebase onto the first product-shaped slices for the Quest-Native Flight Station.

The current codebase is a strong simulator-control foundation. The next phase should evolve it into product-level seams rather than overloading existing simulator concepts.

## Existing Reusable Seams

### Input And Telemetry

Relevant files:

- [raw_controller_state.gd](../../scripts/telemetry/raw_controller_state.gd)
- [xr_telemetry_reader.gd](../../scripts/input/xr_telemetry_reader.gd)
- [source_deriver.gd](../../scripts/telemetry/source_deriver.gd)

Use these as the raw input spine for pilot intent. They already represent controller state, event flags, and derived control sources. They may need to expand beyond Phase 1a/right-controller assumptions as Stick Control Scheme and Spatial Control Scheme mature.

### Mapping

Relevant files:

- [mapping_template.gd](../../scripts/mapping/mapping_template.gd)
- [mapping_engine.gd](../../scripts/mapping/mapping_engine.gd)
- [failsafe_supervisor.gd](../../scripts/mapping/failsafe_supervisor.gd)

Use `MappingTemplate` and `MappingEngine` as the starting point for Tunable Control Profile behavior. Keep the mapping engine focused: selected profile plus input sources produces high-level pilot intent and channel-intent outputs.

Do not put Drone Profile or Betaflight-like channel expectations into Tunable Control Profile.

### Network

Relevant files:

- [telemetry_sender.gd](../../scripts/network/telemetry_sender.gd)
- [telemetry_receiver.gd](../../scripts/network/telemetry_receiver.gd)
- [control_client.gd](../../scripts/network/control_client.gd)
- [control_server.gd](../../scripts/network/control_server.gd)
- [discovery_protocol.gd](../../scripts/network/discovery_protocol.gd)

Existing networking serves simulator and PC/Quest coordination. Reuse patterns for message flow, diagnostics, and discovery, but add a new Command Path adapter rather than putting ExpressLRS behavior into existing simulator channels.

### Backend Adapter Pattern

Relevant files:

- [gamepad_backend.gd](../../scripts/backend/gamepad_backend.gd)
- [linux_gamepad_backend.gd](../../scripts/backend/linux_gamepad_backend.gd)

The backend pattern is useful, but the output contract is simulator/gamepad-specific. Treat it as inspiration for `scripts/command`, not as the ExpressLRS abstraction itself.

### Workflow And Persistence

Relevant files:

- [session_profile.gd](../../scripts/workflow/session_profile.gd)
- [session_profile_store.gd](../../scripts/workflow/session_profile_store.gd)
- [session_run_store.gd](../../scripts/workflow/session_run_store.gd)
- [session_report_exporter.gd](../../scripts/workflow/session_report_exporter.gd)

Reuse persistence and diagnostics patterns. Do not carry forward manual checklist mechanics into product readiness; readiness must be programmatic.

### Quest UI And Runtime

Relevant files:

- [quest_main.gd](../../scripts/quest_main.gd)
- [quest_template_controller.gd](../../scripts/quest/quest_template_controller.gd)
- [quest_session_controller.gd](../../scripts/quest/quest_session_controller.gd)
- [quest_flight_runtime_controller.gd](../../scripts/quest/quest_flight_runtime_controller.gd)
- [quest_status_controller.gd](../../scripts/quest/quest_status_controller.gd)

The refactor has separated Quest orchestration into controllers. Keep using that shape. Add product-level controllers rather than pushing all product behavior back into `quest_main.gd`.

### XR And Composition Layers

Relevant files:

- [openxr_bootstrap.gd](../../scripts/xr/openxr_bootstrap.gd)
- [quest_panel_layer.gd](../../scripts/xr/quest_panel_layer.gd)
- [quest_main.tscn](../../scenes/quest_main.tscn)

Keep composition layers as direct children of `XROrigin3D`. Preserve the existing passthrough and composition-layer startup patterns.

## New Product Seams

### `scripts/command`

Purpose:

- Command packet dry-run adapter.
- Receiver AP endpoint connection and probing.
- Stock MSP tunnel probe.
- Receiver-native UDP endpoint adapter, if custom receiver firmware becomes viable.
- Command packet serialization.
- Receiver endpoint health parsing.
- Command-path diagnostics.

Candidate interface:

- `connect()`
- `disconnect()`
- `start_streaming(binding)`
- `stop_streaming()`
- `send_intent(intent_snapshot)`
- `send_emergency_disarm()`
- `get_health()`
- `get_diagnostics()`

### `scripts/profiles`

Purpose:

- `TunableControlProfile` evolution from `MappingTemplate`.
- `DroneProfile`.
- Profile stores.
- Profile duplication and deletion confirmation state.
- Device-persistent profile migration and compatibility.
- Last Good Binding storage.

### `scripts/session`

Purpose:

- Flight Session orchestration.
- Session Environment.
- Flight Binding.
- Readiness State.
- Workbench/Cockpit state transitions.
- Armed/disarmed state.
- Input Authority Risk state.

### `scripts/video`

Purpose:

- Video presence abstraction.
- Fake video source.
- HDMI Link compromise readiness hooks.
- Future Android UVC plugin bridge.
- Stale-frame detection.

### `scripts/debug`

Purpose:

- Persistent Diagnostic Log.
- Filterable Diagnostic Log View backing data.
- Event categories for command, video, tuning, readiness, input authority, and mapping.

## Product-Shaped Implementation Slices

### 1. Workbench Profile Slice

Scope:

- Tunable Control Profile list.
- Generated names and rename.
- Duplicate/delete.
- Immediate tuning controls.
- Auto-save.
- Experimental Label.
- Dry-Run Output Test.

Tests:

- Profile duplication.
- Generated names.
- Auto-save.
- Compatibility version.
- Disarmed-only edit enforcement.

### 2. Binding And Channel Slice

Scope:

- Drone Profile.
- Channel Mapping Setup.
- Flight Binding.
- Last Good Binding.
- Channel Debug Panel.

Tests:

- Channel mapping output.
- Binding restoration.
- Drone/control profile separation.
- Deletion confirmation behavior.

### 3. Readiness Slice

Scope:

- Programmatic Readiness State.
- Simulator-specific readiness.
- Real-drone readiness.
- No manual physical checklist items.

Tests:

- Readiness includes only detectable state.
- Receiver endpoint unavailable means not ready.
- Incompatible profile means not ready.
- Focus loss becomes Input Authority Risk when armed.

### 4. Cockpit State Slice

Scope:

- Cockpit Transition.
- Flight Cockpit state.
- RC-Style Arming UI state.
- Disarmed Workbench Return.
- Cockpit Re-Arm.
- Locked FPV and Command Visualization placement while armed.

Tests:

- Cannot return to Workbench while armed.
- Disarm does not auto-return.
- Re-arm can happen from cockpit.
- Tuning disabled while armed.

### 5. Command Research Slice

Scope:

- Fake command endpoint.
- Receiver AP endpoint probe.
- MSP tunnel probe contract.
- Receiver-native UDP endpoint contract.
- Receiver endpoint status parsing.
- Diagnostic counters.
- Product-shaped dry-run to endpoint.

Tests:

- Packet serialization.
- Latest-command-wins behavior.
- Receiver endpoint health to readiness.
- Input Authority Risk surfacing.

### 6. Diagnostic Log Slice

Scope:

- Persistent log file.
- Collapsed-by-default Workbench panel.
- Search/filter by term.
- Event categories.

Tests:

- Writes events.
- Filters lines.
- Does not appear in Flight Cockpit.

### 7. Video Integration Slice

Scope:

- Fake video source.
- Video readiness state.
- HDMI Link/focus compromise experiment hooks.
- Future Android UVC plugin status bridge.

Tests:

- Fresh frame means video ready.
- Stale frame means video degraded/lost.
- Video absence differentiates Normal Real-Drone Session from Control-First Validation.

## Test Strategy

Use existing GUT patterns and keep tests at product seams.

Existing test references:

- [test_mapping_engine.gd](../../test/unit/test_mapping_engine.gd)
- [test_mapping_template.gd](../../test/unit/test_mapping_template.gd)
- [test_session_profile_store.gd](../../test/unit/test_session_profile_store.gd)
- [test_control_channel.gd](../../test/integration/test_control_channel.gd)
- [test_udp_loopback.gd](../../test/integration/test_udp_loopback.gd)
- [test_quest_main_scene.gd](../../test/unit/test_quest_main_scene.gd)

Preferred test style:

- Assert external behavior.
- Use fake adapters for command and video.
- Avoid testing UI implementation details unless scene composition is the behavior.
- Preserve XR composition-layer scene invariants.

## Current Branch Notes

At the time of research, the branch was `research-quest-native-real-drone-control`, based on current `origin/main`, with prior context/PRD/ADR work already committed. Local modified `AGENTS.md` and `CLAUDE.md` were present and should be treated as unrelated unless the user says otherwise.

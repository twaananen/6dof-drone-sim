# Deep Research Orchestration

Status: Quest-only reports synthesized
Started: 2026-06-30

Related documents:

- [Domain glossary](../../CONTEXT.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)
- [Quest 3 to Air65 Native Command Research Brief](./quest3-expresslrs-research-brief.md)
- [Quest-Only Command Synthesis](./quest-only-command-synthesis.md)
- [Deep Research Synthesis](./deep-research-synthesis.md)
- [Quest-Only Hard Paths](./quest-first-hard-paths.md)
- [Command Path Architecture](./command-path-architecture.md)
- [Video Integration Plan](./video-integration-plan.md)
- [Codebase Integration Plan](./codebase-integration-plan.md)
- [Architecture decisions](../adr/)

## Research Goal

Lead a deep research phase for the Quest-Native Flight Station that turns the product ambition into a concrete technical approach. The immediate target is to prove whether a product-shaped Command Path can run from Quest 3 controller input to the existing Air65 onboard receiver/flight-controller path, while separately researching in-app analog FPV capture.

The research should stay ambitious and product-shaped: every recommendation should support Solo Pilot Operation, Complete FPV Station Replacement, Simulator-to-Real Continuity, and Control-First Validation with the Air65 as the current Validation Aircraft.

Correction: conventional bridge hardware is not the ambition. The current pass uses a hard Quest-only command constraint: no external command bridge, ELRS TX module, microcontroller, PC, phone, or traditional radio in the live product command loop.

## Operating Rules

- Prefer primary or authoritative sources for technical claims.
- Return synthesized reports with links, confidence, risks, and recommended experiments.
- Do not preserve raw search-result dumps in project docs.
- Keep Command Research separate from Video Integration Research.
- Treat ExpressLRS as the product boundary.
- Keep the Quest app responsible for the Live Pilot Station, not flight-controller behavior.
- Treat Stick Control Scheme as the first real-flight proof and Natural Spatial Control as the long-term differentiator.
- Keep readiness limited to programmatically checkable state.
- Keep normal product workflow in-headset with Quest controllers.

## Research Lanes

### A. Air65 Receiver-Side Command Ingress

Question: Can a Quest app make pilot intent become accepted Air65 control input through the stock receiver MSP tunnel or receiver-native firmware?

Expected output:

- Air65 receiver/FC architecture summary.
- Stock ExpressLRS receiver Wi-Fi and MSP tunnel behavior.
- Receiver-native UDP-to-CRSF firmware possibility.
- Recommended first Quest-Air65 Native Command Path.
- Falsifiers and recovery unknowns.

### B. Quest Platform And APIs

Question: What does Quest 3 hardware, Quest OS, Android, OpenXR, and Godot allow or constrain?

Expected output:

- Wi-Fi and socket assumptions.
- App lifecycle and foreground constraints.
- Controller input and passthrough implications.
- USB access and permission constraints.
- Product assumptions for a foreground OpenXR app.

### C. USB / HDMI FPV Capture

Question: Can analog FPV video from a USB/HDMI capture receiver become an Integrated Flight View inside the Quest app?

Expected output:

- In-app UVC/USB feasibility.
- Separate HDMI capture app compromise feasibility.
- Latency and permission risks.
- Recommended video experiment sequence.

### D. Quest-To-Air65 Wi-Fi Command Networking

Question: What command transport contract should connect the Quest app to the Air65 receiver-side endpoint?

Expected output:

- UDP/TCP recommendation.
- Packet contract proposal.
- Timing, jitter, loss, watchdog, and diagnostic strategy.
- Receiver-AP and OpenXR focus acceptance targets.

### E. Codebase Integration

Question: Which existing Godot seams should carry the first product-shaped slices?

Expected output:

- Existing input, mapping, network, telemetry, workflow, UI, and XR seams.
- Reuse/evolution plan for profiles, bindings, workbench, cockpit, readiness, diagnostics, and command adapters.
- Test strategy using existing GUT patterns.

### F. Air65 Identity, Firmware, And Recovery Plan

Question: What exact Air65 hardware facts and recovery paths are required before stock MSP probing or custom receiver firmware can be trusted?

Expected output:

- Receiver target, FC target, UART/protocol, and firmware identity.
- Stock MSP tunnel probe plan.
- Receiver-native firmware spike plan.
- No-extra-command-hardware pass/fail criteria.
- Product decisions unlocked by each experiment.

## Integration Output

Synthesized outputs:

- [Quest-Only Command Synthesis](./quest-only-command-synthesis.md)
- [Deep Research Synthesis](./deep-research-synthesis.md)
- [Quest-Only Hard Paths](./quest-first-hard-paths.md)
- [Command Path Architecture](./command-path-architecture.md)
- [Video Integration Plan](./video-integration-plan.md)
- [Codebase Integration Plan](./codebase-integration-plan.md)

# Receiver-Native Command Path Architecture

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Quest-Only Command Synthesis](./quest-only-command-synthesis.md)
- [Deep Research Synthesis](./deep-research-synthesis.md)
- [Quest-Only Hard Paths](./quest-first-hard-paths.md)
- [Quest 3 to Air65 Native Command Research Brief](./quest3-expresslrs-research-brief.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)

## Goal

Prove an End-to-End Pilot Loop where Quest controller input becomes accepted Air65 control input with Trustworthy Control Feel, using only the Quest 3 and the existing Air65 onboard receiver/flight-controller hardware in the live command path.

The active target is:

```text
Quest Godot/OpenXR app
  -> Quest Wi-Fi networking
  -> Air65 receiver-side endpoint
  -> Betaflight control input
```

The receiver-side endpoint may be:

- The stock ExpressLRS receiver TCP MSP tunnel, if it can carry safe RC-input probes.
- Custom receiver-native firmware that accepts Quest UDP and emits CRSF channel frames.
- A fake or dry-run endpoint inside the Quest app while live hardware is still unsafe.

External command bridges, TX modules, and traditional radios are outside this architecture.

## Architecture Roles

### Quest App Owns

- Quest Control Scheme.
- Tunable Control Profile.
- Drone Profile and Channel Mapping Setup.
- Flight Binding.
- RC-Style Arming intent.
- Command Visualization.
- Readiness State presentation.
- Diagnostic Log View.
- Detection of input focus, controller tracking, app lifecycle, and app-side Input Authority Risk.
- Receiver endpoint connection state and health presentation.
- Dry-run command packet generation.

### Receiver Endpoint Owns

For the stock MSP tunnel probe:

- TCP connection acceptance on the receiver Wi-Fi network.
- MSP frame forwarding toward Betaflight.
- Any stock receiver Wi-Fi state transitions.

For receiver-native custom firmware:

- Quest command packet ingestion.
- Command freshness and sequence validation.
- CRSF frame serialization or other verified Betaflight control output.
- Receiver-side stale-command behavior.
- Receiver endpoint diagnostics, if the firmware can report them.
- A recovery/update path.

### Betaflight Owns

- Flight stabilization.
- Drone Flight Mode behavior.
- Motor control.
- OSD.
- Failsafe behavior inside the flight controller.
- Interpretation of receiver input according to the configured drone profile.

The Quest app must not become a Betaflight configurator. The stock MSP tunnel probe is a research experiment to test command ingress, not a normal product setup workflow.

## Endpoint Types

### `CommandPacketDryRun`

Purpose: exercise the product command loop without sending live aircraft commands.

Responsibilities:

- Accept mapped pilot intent from the app.
- Serialize the exact command snapshot that would be sent to a real endpoint.
- Log timing, profile hashes, channel values, input authority, and readiness.
- Feed the Channel Debug Panel and Command Visualization.

### `MspTunnelProbe`

Purpose: test the stock no-flash receiver loophole.

Responsibilities:

- Connect to the receiver AP from the disarmed Control Workbench.
- Open TCP `5761`.
- Send safe MSP identity/status requests.
- If identity works, attempt a props-off RC-input probe.
- Log response timing, failures, and Betaflight-visible state.

Non-goals:

- General Betaflight configuration.
- Firmware flashing.
- Active flight before repeatable props-off evidence.

### `ReceiverNativeUdpEndpoint`

Purpose: support a custom receiver firmware path if stock probing fails and recovery is credible.

Responsibilities:

- Send complete command snapshots over UDP.
- Use latest-complete-command-wins semantics.
- Avoid retransmission of old command snapshots.
- Surface receiver health and command age.
- Support explicit emergency/disarm intent.

## Command Transport

### Stock MSP Tunnel Probe

Use TCP because the stock receiver tunnel is TCP-based. The probe should begin with identity/status requests and only move to RC-input attempts when the tunnel is proven to reach Betaflight.

The app must treat this as disarmed research:

- No arming from the tunnel until props-off behavior is understood.
- No tuning while armed.
- No user-facing OS Wi-Fi prompts during active flight.
- No assumption that MSP response means RC command viability.

### Receiver-Native UDP

Use UDP unicast for active command packets if custom receiver firmware becomes viable. One datagram is one complete command snapshot:

- Drop old sequence numbers.
- Count missing and out-of-order packets.
- Do not retransmit command packets.
- Do not wait for ACKs before sending newer commands.
- Do not process delayed bursts of stale commands.

Use reliable request/response only for setup/status/logs:

- Receiver identity.
- Version negotiation.
- Readiness.
- Diagnostic pull.
- Safe mode and recovery state.

## Recommended `CMD_DRY_RUN_V1` / `CMD_V1` Fields

Fields:

- `magic`
- `version`
- `msg_type`
- `session_id`
- `sequence`
- `input_sample_time_us`
- `send_time_us`
- `control_profile_crc`
- `drone_profile_crc`
- `channel_map_crc`
- `flags`
- `channel_count`
- `channels_us[16]`
- `role_map_hash`
- `crc32c`

Initial flags:

- `armed_intent`
- `emergency_disarm`
- `dry_run_only`
- `calibration_valid`
- `input_authority_valid`
- `cockpit_focused`

Channel values should use the RC microsecond domain unless hardware evidence favors raw CRSF ticks:

- Typical low: `988`
- Typical center: `1500`
- Typical high: `2012`
- Arm channel low: disarmed
- Arm channel high: armed

The receiver endpoint can translate microseconds to CRSF channel ticks at the receiver boundary.

## Recommended `RECEIVER_ENDPOINT_STATE_V1`

If custom receiver firmware can report health, send state back to Quest at 10-20 Hz:

- `endpoint_state`: idle, ready, streaming, stale_hold, stale_drop, emergency_disarm, recovery, fault.
- `last_accepted_sequence`.
- `packets_received`.
- `packets_missing`.
- `packets_duplicate`.
- `packets_out_of_order`.
- `interarrival_min_ms`.
- `interarrival_mean_ms`.
- `interarrival_p95_ms`.
- `interarrival_p99_ms`.
- `estimated_rtt_ms`.
- `command_age_ms`.
- `receiver_output_rate_hz`.
- `serial_error_count`.
- `watchdog_transition_count`.
- `firmware_identity`.

The stock MSP tunnel may not expose this packet. In that case, the Quest app must infer endpoint health from MSP response timing, command age, socket state, app focus, and controller input validity.

## Initial Timing Targets

These targets are hypotheses to measure, not product claims:

- Quest command send cadence: 90 Hz minimum, 120 Hz target.
- Receiver CRSF output cadence, if custom firmware is used: 250 Hz initial target.
- Quest-to-receiver UDP one-way latency: median below 5 ms, p95 below 10 ms, p99 below 20 ms on the receiver AP.
- Quest input sample to receiver output write: p95 below 20 ms, p99 below 30 ms.
- Packet loss: below 0.1 percent over a 10 minute disarmed run, with no loss burst over 50 ms during readiness qualification.

The stock MSP tunnel may not meet these targets. If it cannot, it may still be useful evidence but not a flight command path.

## Watchdog Research Policy

The current product ADR deliberately defers automatic response to Input Authority Risk. The following is a receiver-endpoint hypothesis, not a final product decision.

Initial receiver-native firmware policy to evaluate:

- Fresh: command age <= 25 ms. Emit latest command normally.
- Short gap: 25-50 ms. Continue emitting latest command and log counters.
- Stale hold: 50-100 ms. Center roll, pitch, and yaw; set throttle low; keep arm unchanged for bench measurement; surface Input Authority Risk.
- Hard stale: >100-150 ms. Drive arm channel low for at least 500 ms and remain disarmed until a new RC-Style Arming action occurs.
- Emergency packet: immediately drive arm low and throttle low.

This must be validated against Betaflight behavior before becoming product policy.

## Hardware Posture

The live command path for this pass contains only:

- Quest 3 headset and controllers.
- Air65 onboard receiver and flight controller.

Out-of-product hardware may be useful for evidence or recovery, but it is not part of this architecture:

- Existing RC controller: External Safety Fallback only.
- ELRS TX module: out-of-scope comparison path.
- Microcontroller bridge: out-of-scope comparison path.
- Logic analyzer / USB-UART / RP2040 / ESP32-S3 / bench receiver: evidence or recovery tooling only.

## Experiment Sequence

### 1. Air65 Receiver Hardware And Firmware Identification

Objective: know whether receiver-side Quest Wi-Fi control is thinkable.

Setup:

- Identify exact Air65 FC/receiver variant.
- Identify receiver MCU, RF chip, firmware target, and upload/recovery path.
- Confirm Betaflight receiver protocol and UART configuration.
- Confirm whether receiver Wi-Fi mode exists on the actual unit.

Pass criteria:

- Clear map of receiver firmware/hardware.
- Clear answer on whether receiver firmware is separate from Betaflight.
- Recovery path documented before any firmware experiment.

### 2. Stock Receiver MSP Tunnel Probe

Objective: test the only no-flash Quest-only loophole.

Setup:

- Air65 props removed.
- Receiver in ELRS Wi-Fi mode.
- Quest app connected to receiver AP.
- TCP `5761` opened from a disarmed Workbench test panel.

Pass criteria:

- MSP identity/status responses are received.
- Safe RC-input probe can be observed or read back.
- Required Betaflight state changes are understood.

Fail criteria:

- No receiver AP, no TCP tunnel, no MSP response, RC input rejected, or timing too poor.

### 3. Quest-To-Receiver AP Transport Test

Objective: measure Quest networking and lifecycle behavior against the real receiver AP.

Setup:

- Foreground Godot/OpenXR app.
- Receiver AP as the Wi-Fi network.
- Timed packet/MSP loop.
- Explicit focus, controller, sleep/wake, and reconnect events.

Pass criteria:

- The app can classify receiver endpoint readiness honestly.
- Focus loss and controller/input degradation become Input Authority Risk.
- No active-flight network prompts are required.

### 4. Receiver-Native Firmware Design Spike

Objective: design the custom firmware path without flashing.

Setup:

- ExpressLRS receiver source and actual target metadata.
- No live aircraft output.
- Explicit recovery plan.

Pass criteria:

- UDP input path, CRSF output path, watchdog behavior, and recovery strategy are documented.
- A minimal props-off validation path is defined.

### 5. Product-Shaped Workbench Integration

Objective: keep research attached to the product surface.

Setup:

- Control Workbench selects Drone Profile, Tunable Control Profile, and Flight Binding.
- Channel Debug Panel shows raw outgoing channels.
- Diagnostic Log View shows command endpoint events.
- Dry-run mode does not transmit live aircraft commands.

Pass criteria:

- A pilot can calibrate, dry-run, bind, and inspect command readiness in-headset with Quest controllers.

### 6. Air65 Props-Off Rehearsal

Objective: prove the actual Validation Aircraft accepts the selected endpoint.

Setup:

- Air65 props removed.
- Quest app in real-drone Session Environment.
- Selected receiver endpoint active.

Pass criteria:

- Betaflight-observable roll, pitch, yaw, throttle, arm, and mode channels behave as expected.
- Loss and stale-command cases do not create surprise motor commands.

### 7. Contained Control-First Validation

Objective: fly the product-shaped slice.

Setup:

- Netted or carefully contained area.
- External Safety Fallback present but outside the product workflow.
- HDMI Link or external video compromise allowed if integrated video is not ready.

Pass criteria:

- Takeoff, controlled maneuver, landing, and disarm.
- No unexplained channel jumps.
- Pilot does not need the traditional radio for basic control feel.
- Logs explain any issue.

## Sources

- [ExpressLRS Wi-Fi updating](https://www.expresslrs.org/software/updating/wifi-updating/)
- [ExpressLRS Web UI](https://www.expresslrs.org/quick-start/webui/)
- [ExpressLRS receiver wiring](https://www.expresslrs.org/quick-start/receivers/wiring-up/)
- [ExpressLRS configuring flight controllers](https://www.expresslrs.org/quick-start/receivers/configuring-fc/)
- [ExpressLRS TCP MSP connector](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/lib/WIFI/TcpMspConnector.cpp)
- [ExpressLRS Wi-Fi device code](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/lib/WIFI/devWIFI.cpp)
- [ExpressLRS receiver main loop](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/src/rx_main.cpp)
- [ExpressLRS CRSF serial output](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/src/rx-serial/SerialCRSF.cpp)
- [BETAFPV Air65](https://betafpv.com/products/air65-brushless-whoop-quadcopter)
- [RFC 8085 UDP usage guidelines](https://datatracker.ietf.org/doc/rfc8085/)
- [RFC 9293 TCP](https://datatracker.ietf.org/doc/rfc9293/)

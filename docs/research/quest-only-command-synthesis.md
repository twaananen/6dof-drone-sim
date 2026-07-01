# Quest-Only Command Synthesis

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Domain glossary](../../CONTEXT.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)
- [Quest 3 to Air65 Native Command Research Brief](./quest3-expresslrs-research-brief.md)
- [Quest-Only Hard Paths](./quest-first-hard-paths.md)
- [Command Path Architecture](./command-path-architecture.md)
- [Codebase Integration Plan](./codebase-integration-plan.md)

## Hard Constraint

This research pass assumes the product command path has only:

- The Quest 3 headset hardware, controllers, Wi-Fi/Bluetooth radios, app runtime, and app-accessible Android/OpenXR APIs.
- The existing BetaFPV Air65 aircraft hardware, including its onboard receiver and Betaflight flight controller.
- Receiver or flight-controller configuration already present on the aircraft.

This pass excludes product command paths that require:

- A traditional RC transmitter.
- An external ExpressLRS TX module.
- A microcontroller bridge.
- USB-UART adapters, RP2040/ESP32 boards, logic analyzers, or bench receivers.
- A PC or phone in the live command loop.

Those tools may be useful as out-of-product evidence or recovery tooling, but they must not become the answer to the product question.

## Lead Conclusion

The Quest 3 should be treated as an application/network computer, not as a programmable ExpressLRS RF transmitter. Direct Quest-to-Air65 ExpressLRS RF is not a credible product path with current evidence.

The remaining Quest-only command question is narrower and more interesting:

```text
Quest app
  -> Quest Wi-Fi networking
  -> Air65 onboard receiver or receiver-adjacent firmware
  -> Betaflight control input
```

There are two paths worth pursuing:

1. **Stock MSP tunnel loophole**: test whether the Air65's stock ExpressLRS receiver Wi-Fi mode exposes the receiver-side TCP MSP tunnel on port `5761`, whether that tunnel reaches Betaflight, and whether Betaflight can accept RC-like input through it while disarmed and props-off.
2. **Receiver-native command firmware**: if the Air65 has a recoverable serial ESP8285/SX1280-style onboard receiver, research custom receiver firmware that receives Quest UDP packets over Wi-Fi and emits CRSF channel frames to Betaflight.

Everything else is either outside the hard constraint or useful only as comparison evidence.

## Feasibility Map

| Path | Status | Product Meaning |
| --- | --- | --- |
| Quest Wi-Fi/Bluetooth emits native ExpressLRS RF | Rejected unless disproven by hard radio evidence | Quest radios expose certified Wi-Fi/Bluetooth networking behavior, not arbitrary ELRS/LoRa/FLRC modulation or packet timing. |
| Quest talks to stock receiver Web UI/update mode as live RC | Low confidence | ExpressLRS receiver Wi-Fi is documented and implemented as update/config mode, not live command ingress. |
| Quest talks to stock receiver TCP MSP tunnel on port `5761` | Highest-value no-flash probe | If Betaflight accepts RC input through this path, it is the fastest Quest-only command breakthrough. |
| Quest talks to modified Air65 receiver firmware over Wi-Fi | Main radical path | Coherent if the receiver is serial, Wi-Fi-capable, independently flashable, and recoverable; high risk until proven. |
| Quest talks to modified external ELRS TX module | Out of scope for this pass | Technically promising, but violates the Quest-plus-existing-Air65 command constraint. |
| Quest talks to conventional bridge hardware | Out of scope for this pass | Useful historical fallback or instrumentation, but not the current product research answer. |
| Quest USB cable to flight controller MSP | Out of scope for flight | May be a setup/debug curiosity, but it is not a wireless flight command path. |

## What The Agents Converged On

### Quest Radio Boundary

Quest 3 has Wi-Fi/Bluetooth networking hardware and app-facing Android networking APIs. It does not expose a supported SDR-like interface, raw baseband interface, LoRa/FLRC modem controls, or ExpressLRS packet scheduler.

Frequency overlap is not protocol compatibility. Wi-Fi, Bluetooth, and ExpressLRS can all operate around 2.4 GHz, but an ExpressLRS receiver expects the ExpressLRS PHY, hopping behavior, packet shape, and timing. A Quest app can send UDP/TCP packets over Wi-Fi; it cannot make the Wi-Fi chip become an ELRS transmitter.

### Stock ExpressLRS Receiver Behavior

Stock receiver Wi-Fi is not documented as RC command ingress. ExpressLRS receiver Wi-Fi mode is primarily for update/configuration. Source review found that Wi-Fi update mode changes receiver state, stops RF operation, and starts web/update services. Normal CRSF channel output is fed by decoded ELRS RF channel data, not by Wi-Fi packets from an app.

The important loophole is receiver-side MSP-over-TCP. ExpressLRS receiver Wi-Fi code starts a TCP MSP connector on port `5761` for Betaflight Configurator-style access through the receiver. That connector routes MSP frames toward the flight controller. It may be configuration-only in practice, but it is the one stock path that might let Quest-originated packets reach Betaflight without flashing firmware.

### Air65 Hardware Reality

Public BETAFPV material points toward current Air65 variants using a G473 5-in-1 AIO with onboard serial ELRS 2.4 GHz receiver, Betaflight target `BETAFPVG473`, and CRSF on a UART boundary. ExpressLRS target metadata includes BETAFPV 2.4 GHz AIO receiver targets based on `Unified_ESP8285_2400_RX`.

That is promising for a receiver-native firmware path, but it must be proven on the actual aircraft. Older or variant-specific SPI receiver architectures would collapse the custom receiver firmware idea because there would be no separate ExpressLRS receiver firmware to repurpose.

### Quest OS And App Runtime

Android/Quest networking is not the main blocker if the receiver exposes a normal IP endpoint. A foreground Godot/OpenXR app can use sockets, and a Godot Android plugin can own the platform-specific pieces: Wi-Fi network selection, binding sockets to a no-internet receiver AP, low-latency Wi-Fi lock, multicast lock if needed, and app/network lifecycle reporting.

The product cannot tolerate user-facing Wi-Fi prompts or OS focus transitions during active flight. Network association and permission flows belong in the disarmed Control Workbench.

## Decisions For This Research Branch

### Adopt Now

- Treat the **Quest-Air65 Native Command Path** as the primary command research target.
- Use endpoint-neutral command code in the Quest app: `ReceiverCommandEndpoint`, `CommandEndpointHealth`, `CommandPacketDryRun`, and `ReceiverApEndpoint` language rather than `CommandBridge`.
- Treat direct Quest-to-ELRS RF as rejected for product planning unless new primary evidence appears.
- Test the stock MSP tunnel before any firmware flashing because it is the only no-flash loophole.
- Require an Air65 identity and recoverability audit before any receiver firmware experiment.
- Keep external radios, bridges, and bench electronics out of the product command path.

### Defer Until Evidence

- Whether MSP tunnel control can satisfy Trustworthy Control Feel.
- Whether Betaflight must be switched to MSP receiver mode for the tunnel probe.
- Whether custom receiver firmware can keep Wi-Fi packet handling and CRSF output stable on the Air65 receiver MCU.
- Whether a custom receiver firmware path still fits the broader ExpressLRS Product Boundary or becomes an Air65-specific firmware fork.
- Any automatic command-hold, neutralize, or disarm response policy.

### Reject For This Pass

- Buying or designing an external command bridge as the first answer.
- Modified TX modules as the product command path.
- Raw Wi-Fi injection, monitor mode, root, bootloader unlock, or driver exploits as product architecture.
- Treating ExpressLRS Web UI access as proof of live RC control.
- Making the Quest app a Betaflight configurator. MSP probing is a research experiment, not a product setup workflow.

## First Experiments

### 1. Air65 Identity And Recoverability Audit

Goal: determine whether receiver-native control is physically possible before touching firmware.

Use the existing aircraft to capture:

- Betaflight target and version.
- Betaflight serial receiver configuration, especially CRSF provider and UART.
- ExpressLRS receiver Web UI target, firmware version, and device name.
- Whether the receiver enters Wi-Fi mode reliably.
- Whether the receiver Web UI exposes target files such as hardware/options data.
- Board markings and visible receiver architecture if available.
- Whether USB-only or LiPo-only power changes receiver Wi-Fi availability.
- Any documented recovery route for the receiver target.

Pass condition: the actual Air65 appears to have a serial, Wi-Fi-capable, separately flashable receiver with a credible recovery path.

Fail condition: the receiver is SPI/integrated in Betaflight, target identity is unclear, or recovery depends on tools we cannot accept for a risky firmware spike.

### 2. Stock Receiver MSP Tunnel Probe

Goal: prove or kill the only stock no-flash command loophole.

Steps:

- Put the Air65 receiver into ELRS Wi-Fi mode.
- Connect the Quest to the receiver AP from a disarmed Control Workbench test.
- Open TCP `5761`.
- Send MSP identity/version requests.
- If the tunnel responds, try the safest possible RC-input probe with props removed, throttle low, and arm channel disarmed.
- Read back MSP status/RC data if available.

Pass condition: Quest-originated control values can be observed by Betaflight through the stock receiver Wi-Fi tunnel with repeatable timing.

Fail condition: no receiver AP, no TCP tunnel, no MSP response, Betaflight rejects RC input, or the required Betaflight receiver configuration would undermine normal Air65 setup.

### 3. Quest Receiver-AP Timing And Focus Test

Goal: learn whether Quest foreground networking can act like a trustworthy command source while connected to the receiver AP.

Steps:

- Build a small Godot/Android receiver endpoint tester.
- Connect to the receiver AP while disarmed.
- Send timed TCP/UDP packets or MSP requests at realistic command rates where possible.
- Log send timing, response timing, packet gaps, Wi-Fi reconnects, app focus, OpenXR session state, controller tracking, and headset sleep/resume.

Pass condition: app focus and Wi-Fi behavior are observable enough to feed Command Path readiness and Input Authority Risk.

Fail condition: Quest Wi-Fi or OpenXR lifecycle behavior is too opaque or unstable to support honest readiness.

### 4. Receiver-Native Firmware Design Spike

Goal: design before flashing.

If experiments 1-2 justify it, inspect ExpressLRS receiver source and draft a minimal firmware fork that:

- Starts receiver Wi-Fi as an AP or joins a configured network.
- Accepts a small Quest command packet over UDP.
- Validates freshness, sequence, profile hashes, and input-authority flags.
- Emits CRSF RC channel frames to Betaflight over the existing receiver UART.
- Drives a conservative stale-command state.
- Preserves an obvious recovery/update path.

Pass condition: the design has a clear target, build path, flash path, recovery path, and props-off validation path.

Fail condition: Wi-Fi and CRSF output cannot coexist, resources are too tight, or recovery is too fragile.

### 5. Product Dry-Run Slice

Goal: keep research attached to the final product shape.

Build the Quest-side command pipeline before live transmission:

- Stick Control Scheme maps Quest controller input to pilot intent.
- Drone Profile maps intent to channel values.
- `CMD_DRY_RUN_V1` serializes the outgoing command snapshot.
- Control Workbench shows channel values, command visualization, readiness, and logs.
- Flight Cockpit shows only pilot intent visualization and critical command status.

Pass condition: the app can exercise the End-to-End Pilot Loop shape without needing the hardware answer to be solved first.

## Source Trail

- [Meta Quest device specs](https://developers.meta.com/horizon/resources/compare-devices/)
- [Qualcomm Snapdragon XR2 Gen 2](https://www.qualcomm.com/xr-vr-ar/products/vr-mr-series/snapdragon-xr2-gen-2-platform)
- [BETAFPV Air65](https://betafpv.com/products/air65-brushless-whoop-quadcopter)
- [BETAFPV Air Brushless Flight Controller](https://betafpv.com/products/air-brushless-flight-controller)
- [BETAFPV Matrix 1S Brushless Flight Controller](https://betafpv.com/products/matrix-1s-brushless-flight-controller)
- [ExpressLRS Wi-Fi updating](https://www.expresslrs.org/software/updating/wifi-updating/)
- [ExpressLRS Web UI](https://www.expresslrs.org/quick-start/webui/)
- [ExpressLRS receiver wiring](https://www.expresslrs.org/quick-start/receivers/wiring-up/)
- [ExpressLRS configuring flight controllers](https://www.expresslrs.org/quick-start/receivers/configuring-fc/)
- [ExpressLRS TCP MSP connector](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/lib/WIFI/TcpMspConnector.cpp)
- [ExpressLRS Wi-Fi device code](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/lib/WIFI/devWIFI.cpp)
- [ExpressLRS receiver main loop](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/src/rx_main.cpp)
- [ExpressLRS CRSF serial output](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/src/rx-serial/SerialCRSF.cpp)
- [Android Wi-Fi stack overview](https://source.android.com/docs/core/connect/wifi-overview)
- [Android Wi-Fi network specifier](https://developer.android.com/reference/android/net/wifi/WifiNetworkSpecifier)
- [Android network operations](https://developer.android.com/develop/connectivity/network-ops/connecting)
- [OpenXR session state](https://registry.khronos.org/OpenXR/specs/1.0/man/html/XrSessionState.html)

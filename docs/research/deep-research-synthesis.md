# Deep Research Synthesis

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Domain glossary](../../CONTEXT.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)
- [Quest 3 to Air65 Native Command Research Brief](./quest3-expresslrs-research-brief.md)
- [Quest-Only Command Synthesis](./quest-only-command-synthesis.md)
- [Quest-Only Hard Paths](./quest-first-hard-paths.md)
- [Command Path Architecture](./command-path-architecture.md)
- [Video Integration Plan](./video-integration-plan.md)
- [Codebase Integration Plan](./codebase-integration-plan.md)
- [Deep Research Orchestration](./deep-research-orchestration.md)

## Executive Summary

This synthesis supersedes the earlier bridge-first framing. The active research constraint is strict: the product command path must use the Quest 3 and the existing Air65 onboard receiver/flight-controller hardware, with no external command bridge, ELRS TX module, microcontroller, PC, phone, or traditional radio in the live command loop.

The central research question is now:

```text
Can Quest controller intent reach Betaflight through the Air65's onboard receiver path
using only Quest networking and existing or modified receiver-side firmware?
```

The answer is not proven yet, but the feasibility map is clear:

- Direct Quest-to-ExpressLRS RF should be treated as rejected for product planning. Quest Wi-Fi/Bluetooth radios expose certified networking behavior, not arbitrary ELRS/LoRa/FLRC packet generation.
- Quest app networking is plausible if the aircraft side exposes a normal IP endpoint. The Quest OS/API side is not the main blocker.
- Stock ExpressLRS receiver Wi-Fi is likely update/config oriented, not live RC command ingress.
- The stock receiver TCP MSP tunnel on port `5761` is the best no-flash loophole to test first.
- Custom Air65 receiver firmware that receives Quest UDP and emits CRSF to Betaflight is the main radical path, but only after actual Air65 receiver identity and recovery are proven.

Video integration remains a separate branch. HDMI Link can remain a Control-First Validation compromise, while in-app UVC/USB capture remains the product target.

## Recommended Direction

### Command

Prioritize the Quest-Air65 Native Command Path:

1. Identify the actual Air65 receiver/FC architecture and recovery route.
2. Probe the stock receiver Wi-Fi MSP tunnel from a Quest app while disarmed and props-off.
3. Measure Quest receiver-AP timing, focus, controller, and lifecycle behavior.
4. If stock paths fail and recovery is credible, design receiver-native firmware that converts Quest UDP to Betaflight control input.
5. Build a product-shaped command dry-run pipeline in the app so Control Workbench, Flight Binding, Channel Mapping Setup, readiness, and diagnostics can progress without waiting for live control.

Do not advance external command hardware as the product path in this branch. External radios, bridge boards, UART adapters, logic analyzers, and bench receivers can be mentioned only as out-of-product evidence or recovery aids.

### Platform

Treat the Quest-Native Flight Station as one foreground, focus-owning Godot/OpenXR app. It owns controller input, passthrough, cockpit state, networking, readiness, and diagnostics. Any loss of OpenXR focus, app focus, controller tracking, or active action input is Input Authority Risk.

A Godot Android plugin is likely needed for receiver-AP connection and lifecycle control: Wi-Fi network requests, no-internet network binding, low-latency Wi-Fi lock, optional multicast lock, and Android/Quest lifecycle reporting.

### Video

Proceed on two tracks:

- Use HDMI Link as a temporary Control-First Validation aid only if the control app can retain the needed input authority.
- Build an in-app UVC spike through Android USB/Camera2/direct-UVC APIs and a Godot Android plugin.

### Codebase

Do not overload the existing simulator/gamepad backend with real-drone control. Add an endpoint-neutral command seam that can support:

- `CommandPacketDryRun`
- `ReceiverApEndpoint`
- `MspTunnelProbe`
- `ReceiverNativeUdpEndpoint`
- `CommandEndpointHealth`

Avoid `CommandBridge` naming in first-path code. It suggests the wrong architecture for the current research constraint.

## Decision Map

### Adopt Now

- Quest app remains the Live Pilot Station.
- Physical Quest controllers remain the current Flight Instruments.
- Quest Wi-Fi is the only command transport surface for this pass.
- Air65 remains the first Validation Aircraft.
- Betaflight configuration remains outside normal product workflow.
- Stock receiver MSP tunnel probing is the first no-flash command experiment.
- Receiver-native firmware is the main hard path if stock probing fails.
- Product-shaped slices remain mandatory: dry-run, readiness, profiles, cockpit, and diagnostics should all use final product language.

### Defer Until Evidence

- Whether MSP-over-TCP can carry RC control with acceptable latency and Betaflight semantics.
- Whether Betaflight must be reconfigured into MSP receiver mode for the tunnel test.
- Whether the actual Air65 receiver is an ESP8285/SX1280 serial receiver with recoverable flashing.
- Whether Wi-Fi and CRSF output can coexist inside receiver firmware at useful rates.
- Whether receiver-native custom firmware still fits the broader ExpressLRS Product Boundary.
- Any automatic response to Input Authority Risk.
- In-app USB video implementation details.

### Reject For This Research Pass

- External TX modules as command path.
- Microcontroller bridge hardware as command path.
- Traditional RC radio as hidden command path.
- Raw Wi-Fi injection, monitor mode, root, bootloader unlock, or driver exploit strategies.
- Treating ExpressLRS Web UI/update mode as live RC control without proof.
- Making the Quest app a general Betaflight configurator.
- Manual safety checklists or fake readiness theater.

## Main Risks

### Receiver Endpoint May Not Exist

The Air65 may expose receiver Wi-Fi only for update/configuration, and the stock MSP tunnel may not support RC input in a useful way. If so, stock firmware cannot satisfy the Quest-only command goal.

### Receiver Firmware Risk

Custom receiver firmware may be possible but risky. The actual hardware might not be a separately flashable serial receiver, recovery might be fragile, Wi-Fi and CRSF output might contend for limited MCU resources, or range/latency might be unacceptable.

### Product Boundary Tension

A custom receiver firmware path may stop being ExpressLRS RF control in the normal sense. It can still preserve the Air65's onboard receiver-to-Betaflight boundary, but product wording must be honest if the drone becomes a custom Quest Wi-Fi receiver rather than a stock ExpressLRS aircraft.

### Quest Lifecycle And Focus

The Quest app can probably send network packets, but active flight needs reliable foreground focus, controller tracking, app lifecycle state, and no user-facing OS prompts during flight. These conditions must feed Readiness State and Input Authority Risk.

### Video Permissions

Android USB host APIs and Meta HDMI Link prove UVC-style hardware paths are plausible, but app permissions, lifecycle, and Horizon OS review constraints make in-app USB camera/video a separate high-risk branch.

## First Experiments

1. **Air65 identity and recoverability audit**: capture Betaflight target/version, receiver protocol, UART, ELRS Web UI target, receiver Wi-Fi behavior, board markings, and recovery path.
2. **Stock receiver MSP tunnel probe**: connect the Quest to receiver Wi-Fi, open TCP `5761`, request MSP identity, then attempt the safest possible RC-input probe with props removed and disarmed.
3. **Quest receiver-AP timing and focus test**: send timed packets or MSP requests from a foreground Godot/OpenXR app while logging Wi-Fi state, OpenXR focus, controller tracking, and lifecycle transitions.
4. **Receiver-native firmware design spike**: design UDP-to-CRSF receiver firmware without flashing until target identity and recovery are proven.
5. **Product dry-run command slice**: implement command packet serialization, channel preview, readiness, and diagnostic logs with no live aircraft output.
6. **Video branch continuation**: keep HDMI Link/focus testing and in-app UVC research separate from command-path proof.

## Research Agent Results

Six focused research lanes converged on the same boundary:

- Quest radios cannot be assumed to emit ELRS RF.
- Quest networking can support UDP/TCP to an IP endpoint if the aircraft side provides one.
- Stock ExpressLRS receiver firmware does not appear to expose receiver-side Wi-Fi RC command ingress.
- The ExpressLRS receiver MSP-over-TCP connector is the most interesting stock loophole.
- Current Air65 public documentation points toward serial ELRS on a G473 AIO, but the actual unit must be identified.
- The codebase should use receiver-endpoint language, not bridge-first language.

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
- [Android USB host](https://developer.android.com/develop/connectivity/usb/host)
- [Android external USB cameras](https://source.android.com/docs/core/camera/external-usb-cameras)
- [OpenXR session state](https://registry.khronos.org/OpenXR/specs/1.0/man/html/XrSessionState.html)

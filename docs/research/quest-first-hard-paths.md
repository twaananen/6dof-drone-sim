# Quest-Only Hard Paths

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Quest-Only Command Synthesis](./quest-only-command-synthesis.md)
- [Deep Research Synthesis](./deep-research-synthesis.md)
- [Command Path Architecture](./command-path-architecture.md)
- [Video Integration Plan](./video-integration-plan.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)

## Purpose

This document keeps the hard research question honest. The project is not trying to solve Quest-native flight by buying conventional RC command hardware and wiring it together. The active question is whether the Quest 3 can control the existing Air65 using only Quest hardware and the aircraft's onboard receiver/flight-controller path.

External command hardware is outside this pass. It can be used only as evidence, recovery tooling, or historical comparison, not as the product command path.

## Core Constraint

The product command path must fit this shape:

```text
Quest 3 app and built-in Wi-Fi
  -> Air65 onboard receiver or receiver-adjacent firmware
  -> Betaflight control input
```

The Air65 uses ExpressLRS hardware, but ExpressLRS is not ordinary Wi-Fi control. Stock ExpressLRS flight control normally uses dedicated RF hardware and firmware, then forwards CRSF to Betaflight.

That creates the hard boundary:

```text
Quest Wi-Fi radio
  -> 802.11 Wi-Fi packets

Air65 ELRS receiver radio
  -> expects ExpressLRS RF packets through ELRS radio hardware
```

Frequency overlap is not compatibility. The Quest Wi-Fi chip should be assumed unable to transmit native ExpressLRS RF directly to the Air65 receiver unless hard radio/driver evidence proves otherwise.

## Path A: Quest Wi-Fi Or Bluetooth Emits ELRS RF

Question: Can Quest built-in radios directly control the Air65's stock ELRS receiver over native ExpressLRS RF?

Current stance: rejected for product planning.

Why:

- Quest app APIs expose Wi-Fi/Bluetooth networking behavior, not arbitrary RF waveforms.
- ExpressLRS 2.4 GHz receivers expect the ExpressLRS PHY, packet timing, hopping behavior, and receiver firmware semantics.
- Raw Wi-Fi monitor/injection, root, driver exploits, or bootloader unlock paths are not product architecture.
- Regulatory approval for Quest radios covers their certified Wi-Fi/Bluetooth behavior, not custom ELRS-like emissions.

What could reopen it:

- Primary evidence that Quest 3 exposes a supported, legal, app-accessible radio interface capable of ELRS-compatible modulation and timing.

## Path B: Stock Receiver Wi-Fi MSP Tunnel

Question: Can the Air65's stock receiver Wi-Fi mode route Quest-originated control input to Betaflight through its TCP MSP tunnel?

Current stance: low-confidence, highest-value no-flash probe.

Why it is interesting:

- It uses only Quest and Air65 hardware.
- It avoids receiver flashing.
- ExpressLRS receiver source contains an MSP-over-TCP connector on port `5761`.
- If Betaflight accepts RC-like input through that path, it could unlock a Quest-only Control-First Validation path quickly.

Why it may fail:

- Stock receiver Wi-Fi is designed for update/configuration, not live RC input.
- Wi-Fi mode appears to stop normal RF operation.
- MSP tunneling may support configuration traffic but not usable RC input.
- Betaflight may require MSP receiver mode or reject `MSP_SET_RAW_RC` in the current CRSF receiver configuration.
- Latency and update rate may be unacceptable for Trustworthy Control Feel.

Research questions:

- Does the actual Air65 receiver expose an ELRS Wi-Fi AP and TCP `5761`?
- Can Quest connect to that AP from a foreground app and keep app/input focus?
- Do MSP identity/status requests work through the tunnel?
- Can a safe props-off RC-input probe move Betaflight receiver values or be read back through MSP?
- What receiver and Betaflight state changes occur when entering Wi-Fi mode?

Product interpretation:

This is a research loophole, not a decision to make the Quest app a Betaflight configurator. It should be tested because it is stock and no-flash. If it works, it must still pass latency, safety, and product-boundary review.

## Path C: Receiver-Native Command Firmware

Question: Can the Air65 onboard serial ELRS receiver be repurposed so Quest UDP commands become CRSF channel frames to Betaflight?

Current stance: insane but coherent; main radical path after identity/recovery proof.

Why it is interesting:

- It keeps the live command loop to Quest plus the existing aircraft hardware.
- It uses the receiver-to-Betaflight boundary already expected by the drone.
- It can keep Betaflight seeing normal RC-style channel values if CRSF output is preserved.

Why it is dangerous/hard:

- The actual Air65 receiver may not be a separately flashable serial ESP receiver.
- Recovery may require out-of-product tools or board access.
- Wi-Fi packet handling and CRSF output timing may not coexist cleanly on the receiver MCU.
- Receiver Wi-Fi range and antenna performance may be poor compared with ELRS RF.
- It may stop being ExpressLRS RF control and become a custom Quest receiver firmware.

Research questions:

- What exact receiver MCU, RF chip, firmware target, and upload methods exist on the actual Air65?
- Is the receiver independent from Betaflight or an SPI/integrated receiver path?
- Can the receiver output CRSF to Betaflight while Wi-Fi is active?
- Can a minimal firmware fork preserve a recovery/update path?
- What stale-command behavior can be implemented without taking over Betaflight's job?

Product interpretation:

This is the best remaining Quest-only hard path if stock probing fails. It should be researched before retreating to external command hardware, but it must not be flown until recovery, stale-command behavior, and props-off validation are boring.

## Out-Of-Scope Comparison Paths

The following paths may remain useful for future comparison or recovery planning, but they are outside the active product command constraint:

- Modified external ExpressLRS TX module firmware.
- Conventional UDP-to-CRSF bridge hardware.
- RP2040/ESP32 command bridges.
- USB-UART or FTDI-driven CRSF generators.
- Bench receivers for RF/channel inspection.
- Traditional radio/controller in the product command loop.
- Quest USB cable to the flight controller as a flight path.

## Revised Research Priority

1. Identify the actual Air65 receiver and recovery path.
2. Probe the stock receiver TCP MSP tunnel from Quest.
3. Measure Quest app focus, controller input, and Wi-Fi behavior against the receiver AP.
4. Design receiver-native UDP-to-CRSF firmware only if the Air65 hardware and recovery story support it.
5. Build endpoint-neutral app dry-run and diagnostics so the product-shaped pilot loop can progress in parallel.
6. Keep video integration separate.

## What Counts As A Win

The best win is:

```text
Quest app
  -> Quest Wi-Fi
  -> Air65 onboard receiver path
  -> Betaflight accepts pilot control input
```

The win must be more than packet movement. It must support the End-to-End Pilot Loop: stable pilot intent, mapped channels, command readiness, controller/input authority visibility, and enough feel to justify contained props-off and eventually contained props-on validation.

## What To Avoid

- Treating hardware purchases as the research plan.
- Treating a bridge as the answer while calling the product Quest-native.
- Assuming stock ELRS Wi-Fi is live RC input without proving it.
- Treating direct Quest RF as plausible because both systems use 2.4 GHz.
- Hiding a PC, phone, traditional radio, or TX module in the command loop.
- Flashing receiver firmware before identifying recovery.

## Source Trail

- [Meta Quest device specs](https://developers.meta.com/horizon/resources/compare-devices/)
- [Qualcomm Snapdragon XR2 Gen 2](https://www.qualcomm.com/xr-vr-ar/products/vr-mr-series/snapdragon-xr2-gen-2-platform)
- [ExpressLRS Wi-Fi updating](https://www.expresslrs.org/software/updating/wifi-updating/)
- [ExpressLRS Web UI](https://www.expresslrs.org/quick-start/webui/)
- [ExpressLRS receiver wiring](https://www.expresslrs.org/quick-start/receivers/wiring-up/)
- [ExpressLRS configuring flight controllers](https://www.expresslrs.org/quick-start/receivers/configuring-fc/)
- [ExpressLRS TCP MSP connector](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/lib/WIFI/TcpMspConnector.cpp)
- [ExpressLRS Wi-Fi device code](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/lib/WIFI/devWIFI.cpp)
- [ExpressLRS receiver main loop](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/src/rx_main.cpp)
- [ExpressLRS CRSF serial output](https://github.com/ExpressLRS/ExpressLRS/blob/e95b9507f624e4782ea454598457518b878d2b9d/src/src/rx-serial/SerialCRSF.cpp)
- [BETAFPV Air65](https://betafpv.com/products/air65-brushless-whoop-quadcopter)

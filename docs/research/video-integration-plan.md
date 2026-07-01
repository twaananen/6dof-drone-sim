# Video Integration Plan

Status: Draft
Last updated: 2026-06-30

Related documents:

- [Deep Research Synthesis](./deep-research-synthesis.md)
- [Quest 3 to Air65 Native Command Research Brief](./quest3-expresslrs-research-brief.md)
- [Quest-Native Flight Station PRD](../prd/quest-native-flight-station.md)

## Goal

Bring analog FPV video into the Quest-Native Flight Station as an Integrated Flight View while keeping Control-First Validation unblocked.

## Bottom Line

In-app FPV video is plausible enough to spike, but it is not trivial. The Quest can host UVC HDMI capture hardware, and Meta HDMI Link proves that a Quest 2/3/Pro can display UVC capture video. Our app cannot consume HDMI Link's private video stream, so the product path requires our own UVC/camera integration.

Temporary HDMI Link use is acceptable for Control-First Validation only if the Godot control app retains input focus. If focus moves to HDMI Link or system UI while armed, that is Input Authority Risk.

## Video Paths

### Temporary Compromise: HDMI Link

Use Meta HDMI Link as a visible video panel while the Quest control app owns input.

Pros:

- Works today with supported UVC capture cards.
- Lets command research proceed before in-app video is solved.
- Keeps analog FPV in the headset during Control-First Validation.

Risks:

- Only one app has input focus.
- Interacting with HDMI Link can steal controller input from the control app.
- The Quest app cannot inspect video presence, frame freshness, or latency.
- It does not validate Integrated Flight View behavior.

Required experiment:

- Run the Godot Quest app and HDMI Link together.
- Confirm the HDMI Link panel remains visible and updating while the Godot app owns controller input.
- Log focus, controller sampling, command send cadence, and app pause/resume events.

### Product Path: In-App UVC Capture

Likely chain:

```text
Analog FPV receiver
  -> HDMI/composite output
  -> UVC USB capture card
  -> Quest USB-C
  -> Android USB/camera stack
  -> Godot Android plugin
  -> world-locked Integrated Flight View
```

Candidate implementation routes:

- Camera2 external camera route.
- Direct USB/UVC route using `UsbManager`, UVC interface negotiation, and a native/Java/Kotlin capture stack.
- Android `SurfaceTexture` or external texture path into Godot/OpenXR.

The direct UVC route is probably the research spine because it gives the most control over frame timestamps, format choice, stale-frame detection, and diagnostics.

## Godot Integration Shape

Avoid GDScript frame polling. Use a Godot Android plugin:

```text
Android plugin
  -> USB/UVC stack
  -> SurfaceTexture / Android Surface / GL external texture
  -> thin Godot status API

Godot scene
  -> world-locked video surface
  -> readiness state
  -> stale-frame warnings
  -> disarmed placement and armed lock
```

Godot should see status and a renderable surface/texture, not raw decoded frame loops.

Status exposed to GDScript:

- `is_device_present`
- `has_usb_permission`
- `has_camera_permission`
- `is_streaming`
- `format`
- `fps`
- `frame_width`
- `frame_height`
- `last_frame_age_ms`
- `dropped_frame_count`
- `disconnect_count`
- `focus_state`

## Readiness Checks

Programmatically check only what the app can observe:

- USB device attached.
- App has device permission.
- Capture interface opened.
- Format/fps negotiated.
- Frames are arriving.
- Last frame is fresh.
- No frame starvation in recent readiness window.
- App is focused and eligible for controller input.

Do not include manual physical video checklist items.

## Latency Measurement

Measure glass-to-glass or source-to-display latency, not just app FPS.

Initial measurements:

- HDMI Link baseline at 720p60 and 1080p60.
- In-app UVC at YUY2/YUYV 720p60 and 1080p60.
- In-app UVC at MJPEG 720p60 and 1080p60.
- USB 2.0 versus USB 3.0 cable behavior.
- Frame-time jitter and stale-frame events.

For micro FPV, choose the format with lowest stable latency and jitter, not the prettiest frame.

## Experiment Sequence

### 1. HDMI Link Baseline

Objective: prove current hardware path on Quest.

Setup:

- Analog FPV receiver to UVC HDMI capture card.
- Capture card to Quest.
- HDMI Link app visible.

Evidence:

- Recognized device.
- Stable 720p60 or 1080p60.
- Measured latency.
- USB 3.0/SuperSpeed behavior where visible.

### 2. Concurrent App And Focus Test

Objective: decide whether HDMI Link is safe enough for Control-First Validation.

Setup:

- Godot control app running in cockpit mode.
- HDMI Link panel visible.
- Control app logs focus and controller input.

Pass criteria:

- Godot app keeps input focus while HDMI Link remains visible.
- Any focus loss is detected and logged as Input Authority Risk.

### 3. Native Android UVC Spike

Objective: prove Quest OS allows our own app to open and render the device.

Setup:

- Minimal native Android/Quest app outside Godot.
- Try Camera2 external camera route first.
- Try direct UVC route if Camera2 is unavailable or too slow.

Pass criteria:

- Enumerate device.
- Request and receive permission.
- Select stream format.
- Display live frames.
- Log fps, frame timestamps, disconnects, and reconnects.

### 4. Godot Android Plugin Spike

Objective: integrate the working video path with the Quest app.

Setup:

- Godot Android plugin wraps native video path.
- Godot scene displays live video as a world-locked surface.

Pass criteria:

- Godot receives video status.
- Video renders in headset.
- Command loop remains independent from video thread.
- Stale-frame detection works.

### 5. Cockpit Integration Slice

Objective: validate product behavior.

Setup:

- Integrated video in Flight Cockpit.
- FPV View Placement adjustable while disarmed.
- View locked while armed.
- Passthrough cockpit remains default.

Pass criteria:

- Pilot can place the FPV view.
- App detects stale/lost video.
- No FPV recording.
- Command input remains authoritative.

## Key Risks

- Meta/Horizon OS permission restrictions around camera or USB camera access.
- Android external camera path not available or too slow on Quest.
- UVC library integration conflicts with Godot/OpenXR rendering.
- USB capture card adds unacceptable latency or jitter.
- HDMI Link compromise steals focus during Control-First Validation.
- USB capture and Wi-Fi command endpoint interactions create power or cable ergonomics problems.

## Sources

- [Meta Quest HDMI Link](https://www.meta.com/blog/hdmi-link-launch/)
- [Meta lifecycle handling](https://developers.meta.com/horizon/documentation/unity/unity-lifecycle/)
- [Meta unsupported permissions](https://developers.meta.com/horizon/documentation/android-apps/unsupported-permissions/)
- [Android USB host](https://developer.android.com/develop/connectivity/usb/host)
- [Android CameraCharacteristics](https://developer.android.com/reference/android/hardware/camera2/CameraCharacteristics)
- [Android external USB cameras](https://source.android.com/docs/core/camera/external-usb-cameras)
- [Android app sandbox](https://source.android.com/docs/security/app-sandbox)
- [Godot Android plugin](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html)
- [Godot OpenXR composition layers](https://docs.godotengine.org/en/latest/tutorials/xr/openxr_composition_layers.html)
- [Godot OpenXR Android Surface example](https://github.com/GodotVR/godot-openxr-android-surface-plugin-example)
- [UVCCamera library](https://github.com/saki4510t/UVCCamera)
- [AndroidUSBCamera/AUSBC library](https://github.com/jiangdongguo/AndroidUSBCamera)
- [Meta Research Ocean External Camera Quest demo](https://facebookresearch.github.io/ocean/docs/demoapps/questapps/externalcamera/)

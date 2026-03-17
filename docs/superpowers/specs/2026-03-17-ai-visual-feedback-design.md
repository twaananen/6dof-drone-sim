# AI Visual Feedback Loop — Approach A Design

## Problem

The AI agent (Claude Code) has no visual access to the running Quest 3 application. After code changes, the user must verbally describe what they see in the headset. This creates a slow, lossy feedback loop — especially for spatial/visual issues that are hard to convey in words.

## Solution: Screenshot on Demand

Give the AI agent the ability to capture and view screenshots from the Quest 3 over wireless ADB. The user says "take a look" and the agent grabs a frame, reads the image, and reasons about what it sees.

### Architecture

```
Quest 3 ──wireless ADB──→ adb screencap ──PNG──→ .screenshots/latest.png ──→ Claude reads image
                    └──→ scrcpy (live mirror + fallback capture)
```

### Step 0: Validate screencap captures VR content

`adb exec-out screencap -p` captures the Android compositor output. On some Quest firmware versions, OpenXR rendering bypasses Android's SurfaceFlinger, producing a black frame instead of VR content. Before relying on this workflow:

1. Run the Godot XR app on Quest
2. Execute `adb exec-out screencap -p > /tmp/test.png`
3. Inspect the result

If the capture is black or shows only the system UI, scrcpy must be used as the primary capture mechanism instead. scrcpy uses the device's MediaCodec encoder, which reliably captures VR content.

### Components

#### 1. `tools/quest-screenshot.sh`

Capture script that grabs a frame from the Quest.

**Behavior:**
- Calls `bash tools/quest-adb.sh resolve-target --auto-wireless`, parses the output, and uses the resolved serial (same pattern as `quest-deploy.sh` and `quest_logcat.sh`)
- Runs `adb exec-out screencap -p` under a 10-second timeout
- Validates the output is a valid PNG (checks magic bytes and non-zero size)
- Saves to `.screenshots/<YYYYMMDD-HHMMSS>.png`
- Copies to `.screenshots/latest.png` (regular file, not symlink, for tool compatibility)
- Auto-cleans old captures beyond the last 20
- Prints the path to stdout for the agent to read

**Subcommands:**
- `quest-screenshot.sh` — single capture (default)
- `quest-screenshot.sh scrcpy` — start scrcpy live mirror window
- `quest-screenshot.sh scrcpy-stop` — stop scrcpy if running
- `quest-screenshot.sh clean` — manually keep only the last 20 captures
- `quest-screenshot.sh help` — show usage

**Error handling:**
- Timeout after 10 seconds if Quest is asleep or ADB connection is stale
- Invalid PNG detection with clear message suggesting scrcpy fallback
- No Quest target: points user to `quest-adb.sh doctor`

#### 2. scrcpy installation in `setup-distrobox-ubuntu24.sh`

scrcpy is not in Ubuntu 24.04 default repos (the apt version is outdated at 1.25). Install from source using the official `install_release.sh` script.

**Changes:**
- Add `install_scrcpy` function that clones the repo and runs `install_release.sh`
- Add apt build dependencies: `ffmpeg`, `libsdl2-2.0-0`, `libsdl2-dev`, `libavcodec-dev`, `libavdevice-dev`, `libavformat-dev`, `libavutil-dev`, `libswresample-dev`, `libusb-1.0-0`, `libusb-1.0-0-dev`, `meson`, `ninja-build`

#### 3. `.screenshots/` directory

- Created by the capture script on first run
- Added to `.gitignore`
- Auto-cleaned after each capture (keeps last 20)
- `latest.png` is always a regular file copy of the most recent capture

#### 4. `.gitignore` additions

```
.screenshots/
.superpowers/
```

### Execution Environment

The capture script runs inside the **Ubuntu 24.04 distrobox** where adb and scrcpy are installed. Claude Code runs on the Bazzite host but reads screenshots from the shared filesystem (the repo is mounted in both environments). This differs from the devcontainer workflow in CLAUDE.md — the distrobox has direct display access for scrcpy windows, while the devcontainer is Docker-based.

### Workflow

```
user: "I deployed the clutch changes, the UI looks weird — take a look"
agent: [runs tools/quest-screenshot.sh inside distrobox]
agent: [reads .screenshots/latest.png]
agent: "I can see the status panel text is clipped on the right side.
        The composition layer quad width might be too narrow. Let me
        check the viewport size in quest_main.gd..."
```

### Image Format Notes

The captured image resolution and format depends on Quest firmware behavior. The first capture should be inspected to understand whether it is:
- A single flat 2D projection of the VR scene
- A side-by-side stereo pair
- Only one eye's view

This affects how the AI agent interprets spatial relationships in the image.

### Constraints

- Quest must be connected via wireless ADB (already the user's setup)
- `adb screencap` may not work for VR content — validated at Step 0, scrcpy fallback available
- The distrobox is the primary execution environment for this tool

### Future Evolution (Approach B)

This design is intentionally minimal. Approach B would add:
- Periodic automatic capture (rolling buffer, read on demand — no tokens until asked)
- Scene tree inspector endpoint over the existing TCP control channel
- Structured telemetry snapshots alongside visual captures

Each addition is informed by real experience with Approach A.

### Files Changed

| File | Change |
|------|--------|
| `tools/quest-screenshot.sh` | New — capture script |
| `tools/setup-distrobox-ubuntu24.sh` | Add scrcpy install + apt deps |
| `docs/distrobox-ubuntu24.md` | Document screenshot tooling |
| `.gitignore` | Add `.screenshots/`, `.superpowers/` |

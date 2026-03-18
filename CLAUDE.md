# Project Overview

This project is a Godot 4.6.1 project that is used to develop a 6DOF Drone Controller prototype using the Meta Quest 3.
Read the plans for the project in the `docs/plans` folder.

# Working with GodotXR
- Always check the GodotXR documentation for the latest information on how to work with GodotXR. They have a lot of great documentation and examples. https://docs.godotengine.org/en/latest/tutorials/xr/index.html


# Quest XR Notes

- Keep `OpenXRCompositionLayerQuad` nodes as direct children of `XROrigin3D` on Quest.
- Do not insert an intermediate `Node3D`/`UiPivot` parent above the composition layer. That setup caused Quest hangs and repeated `XR_ERROR_POSE_INVALID` frame failures during startup.
- Recenter and manipulate the composition layer node itself instead of moving a parent pivot.
- Keep the repro scenes under `scenes/repro/` available for future XR regressions; they are the known-good bisect path for composition-layer issues.

# Distrobox Workflow

The primary dev environment on Bazzite is an Ubuntu 24.04 distrobox named "Ubuntu". All tools (Godot, adb, scrcpy, Android SDK) are installed there.

- Run tools via distrobox from the host: `distrobox enter Ubuntu -- bash tools/<script>.sh`
- Run the full headless test suite: `distrobox enter Ubuntu -- bash tools/run_tests.sh`
- Export and install a Quest build: `distrobox enter Ubuntu -- bash tools/quest-deploy.sh`
- Export only: `distrobox enter Ubuntu -- bash tools/quest-deploy.sh export`
- Check Quest ADB connection: `distrobox enter Ubuntu -- bash tools/quest-adb.sh doctor`
- The repo is at `/var/home/tommi/repositories/6dof-drone-sim`, shared between host and distrobox.

# Quest Visual Feedback

The AI agent can capture and view screenshots from the running Quest 3 app over wireless ADB.

- Capture a screenshot (mono left-eye, via scrcpy): `distrobox enter Ubuntu -- bash tools/quest-screenshot.sh`
- View the result: read `.screenshots/latest.png`
- Fast capture (stereo, via adb screencap): `distrobox enter Ubuntu -- bash tools/quest-screenshot.sh adb`
- Start a live mirror window: `distrobox enter Ubuntu -- bash tools/quest-screenshot.sh scrcpy`
- Capture takes ~5 seconds. Screenshots are saved to `.screenshots/` with `latest.png` always being the most recent.

# Devcontainer Workflow (Docker, alternative)

An alternative to the distrobox for CI or environments without distrobox.

- Find the running devcontainer with `docker ps --format '{{.ID}} {{.Names}}'`.
- Verify the repo is mounted in the container with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && pwd'`.
- Run the full headless test suite with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && bash tools/run_tests.sh'`.
- Export and install a fresh Quest build with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && bash tools/quest-deploy.sh'`.
- Export only, without installing, with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && bash tools/quest-deploy.sh export'`.
- If Quest USB should be available, confirm it inside the container with `docker exec <container_id> bash -lc 'adb devices -l'`.

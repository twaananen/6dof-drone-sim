# Working with GodotXR
- Always check the GodotXR documentation for the latest information on how to work with GodotXR. They have a lot of great documentation and examples. https://docs.godotengine.org/en/latest/tutorials/xr/index.html


# Quest XR Notes

- Keep `OpenXRCompositionLayerQuad` nodes as direct children of `XROrigin3D` on Quest.
- Do not insert an intermediate `Node3D`/`UiPivot` parent above the composition layer. That setup caused Quest hangs and repeated `XR_ERROR_POSE_INVALID` frame failures during startup.
- Recenter and manipulate the composition layer node itself instead of moving a parent pivot.
- Keep the repro scenes under `scenes/repro/` available for future XR regressions; they are the known-good bisect path for composition-layer issues.

# Devcontainer Workflow

- Prefer running Godot tests and Android/Quest exports inside the devcontainer, not on the host.
- Find the running devcontainer with `docker ps --format '{{.ID}} {{.Names}}'`.
- Verify the repo is mounted in the container with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && pwd'`.
- Run the full headless test suite with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && bash tools/run_tests.sh'`.
- Export and install a fresh Quest build with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && bash tools/quest-deploy.sh'`.
- Export only, without installing, with `docker exec <container_id> bash -lc 'cd /workspaces/6dof-drone-sim && bash tools/quest-deploy.sh export'`.
- If Quest USB should be available, confirm it inside the container with `docker exec <container_id> bash -lc 'adb devices -l'`.
- Prefer the devcontainer for Quest work because it has the working `godot`, Android SDK, and `adb` setup that the host shell may not have.

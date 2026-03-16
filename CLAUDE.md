# Working with GodotXR
- Always check the GodotXR documentation for the latest information on how to work with GodotXR. They have a lot of great documentation and examples. https://docs.godotengine.org/en/latest/tutorials/xr/index.html


# Quest XR Notes

- Keep `OpenXRCompositionLayerQuad` nodes as direct children of `XROrigin3D` on Quest.
- Do not insert an intermediate `Node3D`/`UiPivot` parent above the composition layer. That setup caused Quest hangs and repeated `XR_ERROR_POSE_INVALID` frame failures during startup.
- Recenter and manipulate the composition layer node itself instead of moving a parent pivot.
- Keep the repro scenes under `scenes/repro/` available for future XR regressions; they are the known-good bisect path for composition-layer issues.

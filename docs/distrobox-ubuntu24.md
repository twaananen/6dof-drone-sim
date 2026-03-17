# Ubuntu 24.04 Distrobox Setup

This setup is for an existing Ubuntu 24.04 `distrobox`. It prepares graphical Godot, Android export, and Quest deployment from inside the box.

Bootstrap from the repository root:

```bash
bash tools/setup-distrobox-ubuntu24.sh
```

The script assumes distrobox host integration is already handling graphical apps, so `godot` should open the editor directly from inside the box when X11 or Wayland forwarding is available.

`~/.android` is reused through your shared distrobox home directory. That keeps ADB keys and wireless pairing state available across shell sessions and box restarts.

The bootstrap writes Android editor paths to both `~/.config/godot/editor_settings-4.6.tres` and `~/.config/godot/editor_settings-4.tres` so Godot 4 can pick them up regardless of which filename the editor build uses.

Quest USB note:
- If `adb devices -l` reports a permissions error, run `sudo bash .devcontainer/repair-usb-permissions.sh`.
- If USB still fails after that, use wireless ADB or configure host-side `udev` rules. A distrobox cannot own the host's persistent USB permission policy.

This distrobox setup intentionally follows the current Godot Android export documentation for NDK and CMake:
- NDK `28.1.13356709`
- CMake `3.10.2.4988404`

Those versions differ from the current devcontainer pins, which remain unchanged for the existing container workflow.

## AI Visual Feedback (scrcpy)

The setup script installs scrcpy from source for Quest screen mirroring. This lets the AI agent capture screenshots from the running Quest app over wireless ADB.

```bash
bash tools/quest-screenshot.sh              # Capture a single screenshot
bash tools/quest-screenshot.sh scrcpy       # Start live mirror window
bash tools/quest-screenshot.sh scrcpy-stop  # Stop the mirror
bash tools/quest-screenshot.sh clean        # Keep only the last 20 captures
```

Screenshots are saved to `.screenshots/latest.png` (symlink to the most recent capture).

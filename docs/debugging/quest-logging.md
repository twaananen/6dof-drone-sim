# Quest Logging

Package ID: `com.fullpotatostudios.dofdronecontroller`

## USB-First Workflow

Use the current devcontainer or any host shell with `adb` access to the headset.

1. Confirm the Quest is reachable:
```bash
bash tools/quest-adb.sh doctor
```

2. Clear logcat, launch the app, and stream filtered logs:
```bash
bash tools/quest_logcat.sh --clear --launch
```

3. Save a reproduction to disk when chasing startup hangs:
```bash
bash tools/quest_logcat.sh --clear --launch --save quest-startup.log
```

The default filtered stream includes:
- `QUEST_LOG`
- `godot`
- `openxr`
- `androidruntime`
- `com.fullpotatostudios`

## Manual Commands

Basic live log workflow:
```bash
adb devices
adb logcat -c
adb shell monkey -p com.fullpotatostudios.dofdronecontroller -c android.intent.category.LAUNCHER 1
adb logcat -v time | grep -Ei 'QUEST_LOG|godot|openxr|androidruntime|com.fullpotatostudios'
```

PID-filtered logs after the app is running:
```bash
PID="$(adb shell pidof -s com.fullpotatostudios.dofdronecontroller)"
adb logcat --pid="$PID" -v time
```

Full logcat when filtered output is too narrow:
```bash
bash tools/quest_logcat.sh --full
```

## Expected Boot Log Sequence

The Quest app now emits structured startup markers with the `QUEST_LOG` prefix. A normal startup should include these phases in roughly this order:

1. `READY_BEGIN`
2. `UI_LAYER_READY`
3. `UI_BIND_BEGIN`
4. `UI_BIND_OK`
5. `UI_SIGNALS_BOUND`
6. `XR_INIT_BEGIN`
7. `XR_INIT_OK` or `XR_INIT_FAILED`
8. `CONTROLLER_VISUALS_UPDATED`
9. `UI_PANEL_RECENTERED`
10. `PASSTHROUGH_TOGGLE_SYNCED`
11. `READY_COMPLETE`

If the app stalls in the headset, the last `BOOT` phase in logcat is the first place to inspect.

## Godot Remote Debug

Use Godot remote debug as a secondary path when:
- the app is launched as a debug deployment from Godot,
- `adb` connectivity already works,
- and the failure happens late enough for the debugger to attach.

Use `adb logcat` first for startup hangs on exported APKs.

## Bug Reports

There is no practical live in-headset log console for this workflow. Use an Android bug report as the postmortem fallback:

```bash
adb bugreport quest-bugreport.zip
```

Use this when you missed the live log stream or the app died before you could attach.

## Wireless Follow-Up

Once USB logging is confirmed, you can switch to wireless ADB for convenience:

```bash
bash tools/quest-adb.sh tcpip 5555
bash tools/quest-adb.sh wireless <quest-ip>:5555
bash tools/quest_logcat.sh --wireless <quest-ip>:5555 --launch
```

Keep USB as the first-choice path for initial startup debugging and device trust issues.

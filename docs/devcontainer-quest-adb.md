# Devcontainer Quest ADB Workflow

This repo's default devcontainer now treats Quest deployment as a USB-first workflow with automatic wireless fallback.

## What the VS Code Ports view is showing

If VS Code shows an ADB port in the Ports panel, that entry is about the remote container session seeing an ADB server listen socket. It is not evidence that Docker failed to expose `5037` to the host.

This repo keeps `--network=host`, so the container shares the host network namespace. The more important reliability issue was that the container could not see `/dev/bus/usb`, which meant a container-owned ADB server had no direct USB path to the headset.

## ADB model

The devcontainer uses the standard local ADB server socket by default:

```text
tcp:127.0.0.1:5037
```

This keeps the container aligned with normal ADB behavior. If a host-side ADB server is already bound on `127.0.0.1:5037`, `adb` commands in the container will talk to that server because the devcontainer uses host networking.

The devcontainer also bind-mounts the host `~/.android` directory into `/home/vscode/.android`, so the container reuses the same ADB keys and wireless pairing state across rebuilds.

On container start, the devcontainer also repairs `/dev/bus/usb` device-node group ownership to `plugdev` so the non-root `vscode` user can open Quest USB devices. If you reconnect the headset later and get a permissions error, rerun the repair manually.

## Default USB workflow

1. Rebuild the devcontainer after pulling these changes.
2. Connect the Quest by USB.
3. Unlock the headset and accept any USB debugging prompt.
4. Run:

```bash
bash tools/quest-adb.sh doctor
adb devices -l
```

Expected result:

- `bash tools/quest-adb.sh doctor` reports `STATUS: ready`
- `adb devices -l` lists the Quest as `device`

Once that works, install directly from the container:

```bash
adb install /tmp/6dof-drone-debug.apk
```

For the full export-and-install flow in one command:

```bash
bash tools/quest-deploy.sh
```

## Wireless fallback

Wireless ADB is supported as the automatic fallback path when USB is unavailable.

From a working USB session:

```bash
bash tools/quest-adb.sh tcpip
bash tools/quest-adb.sh wireless <quest-ip>:5555
adb devices -l
```

If the Quest only appears as `<ip>:5555 device`, the helper still reports `STATUS: ready` and marks the preferred transport as `wireless`.

If the Quest is already paired for wireless debugging and exactly one discoverable endpoint is present, the helper can connect automatically:

```bash
bash tools/quest-adb.sh wireless --auto
bash tools/quest-adb.sh resolve-target --auto-wireless
bash tools/quest-deploy.sh install
```

If both USB and wireless transports are available at the same time, the scripts prefer USB.

## Helper commands

```bash
bash tools/quest-adb.sh doctor
bash tools/quest-adb.sh resolve-target [--auto-wireless]
bash tools/quest-adb.sh repair-usb
bash tools/quest-adb.sh restart-server
bash tools/quest-adb.sh tcpip [port]
bash tools/quest-adb.sh wireless <ip[:port]>
bash tools/quest-adb.sh wireless --auto
bash tools/quest-deploy.sh
bash tools/quest-deploy.sh export
bash tools/quest-deploy.sh install
```

`doctor` distinguishes between:

- `ready`
- `unauthorized`
- `no_permissions`
- `no_device`
- `server_conflict`
- `ambiguous`

`doctor` also prints:

- connected USB adb serials
- connected wireless adb serials
- discoverable wireless adb endpoints
- the preferred transport and serial

## Troubleshooting

### `STATUS: no_device`

- If `/dev/bus/usb` is missing, rebuild the devcontainer so the USB passthrough `runArgs` are applied.
- If the Quest appears in `lsusb` but not in `adb devices -l`, confirm developer mode is enabled, the headset is unlocked, and the RSA prompt was accepted.
- If the host cannot see the Quest in `lsusb`, fix the cable or host-side USB permissions first.
- If USB is unavailable, enable wireless debugging or SideQuest wireless ADB and rerun `bash tools/quest-deploy.sh install`.

### `STATUS: unauthorized`

- Put on the headset.
- Unlock it.
- Accept the USB debugging prompt.
- Rerun `bash tools/quest-adb.sh doctor`.

### `STATUS: no_permissions`

- Run `bash tools/quest-adb.sh repair-usb`.
- Rerun `bash tools/quest-adb.sh doctor`.
- If the Quest was just unplugged and replugged, expect to rerun the repair because the kernel may have created a fresh USB device node.

### `STATUS: ambiguous`

- Disconnect extra Android devices or extra wireless adb connections.
- Or connect the desired Quest target explicitly with `bash tools/quest-adb.sh wireless <ip[:port]>`.

### `STATUS: server_conflict`

Another listener is already using the container's ADB socket. This repo expects ADB to use `127.0.0.1:5037` unless you explicitly override `ANDROID_ADB_SERVER_PORT`.

### Fedora / Bazzite / SELinux edge case

If the host sees the Quest over USB but the container still cannot use it after a rebuild, SELinux policy may be blocking device access even with `--device=/dev/bus/usb:/dev/bus/usb`.

In that case, verify with host-side audit logs and use a local-only devcontainer override with stronger privileges as a fallback. Keep that override out of the repo so the default config stays as narrow as possible.

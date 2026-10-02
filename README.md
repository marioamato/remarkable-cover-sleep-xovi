# Cover Sleep Screen for reMarkable / XOVI

Show the **cover (first page) of the currently open PDF or EPUB** when a reMarkable goes to sleep.

When you return to **Home / My Files**, the dynamic cover is removed and reMarkable falls back to the normal sleep screen — including a custom sleep image previously configured with **reManager**.

> **Experimental mod.** This project patches xochitl QML resources through XOVI and is firmware-specific. Back up your device and be prepared to remove the mod after a reMarkable OS update.

## Features

- Uses the first page of the document currently open in xochitl.
- Automatically changes the sleep cover when you open another document.
- Falls back to the stock/reManager sleep image when no document is open.
- Supports PDF and EPUB documents when a thumbnail/cache image for the first page is available.
- Keeps the normal reMarkable sleep-screen behavior when no dynamic cover exists.
- Includes a small systemd service that refreshes the current cover automatically.

## Compatibility

| Device / software | Status |
| --- | --- |
| reMarkable Paper Pro, reMarkable OS 3.27.x | ✅ Tested working |
| reMarkable OS 3.28.x | QMD selectors checked against upstream; not yet device-tested |
| reMarkable Paper Pro Move | ⚠️ Not yet tested |
| Other reMarkable OS versions | ⚠️ QMD hashes may need updating |

The sleep-screen selectors are shared by the upstream
[3.27](https://github.com/ingatellent/xovi-qmd-extensions/blob/main/3.27/randomSleepScreen.qmd)
and [3.28](https://github.com/ingatellent/xovi-qmd-extensions/blob/main/3.28/randomSleepScreen.qmd)
patches (checked 2026-10-02). No selector changes are needed for 3.28.
This is a source-level compatibility check, not a successful test on a 3.28 device.
The helper's LastOpen detection and cover rendering still need device validation.
The installer accepts OS 3.27.x and 3.28.x and rejects other/unknown versions
before making changes. Future firmware updates may change the QML layout.

## Requirements

- SSH/root access to the reMarkable.
- [XOVI](https://github.com/asivery/rm-xovi-extensions).
- `qt-resource-rebuilder` installed under XOVI.
- `/usr/bin/sh` available on the device.

The mod works well alongside a custom static sleep image configured with [reManager](https://github.com/rmitchellscott/reManager): that image becomes the fallback whenever you are on Home / My Files.

## How it works

There are two parts:

1. **`cover-sleep-update.sh`** reads xochitl's native `LastOpen` state from:

   ```text
   /home/root/.config/remarkable/xochitl.conf
   ```

   If a PDF/EPUB is open, it finds that document's first page in its `.content` metadata, locates the corresponding pre-rendered thumbnail/cache image and copies it to:

   ```text
   /home/root/.cover-sleep/current.png
   ```

   When xochitl is at Home / My Files, `LastOpen` has no usable document UUID, so the helper removes `current.png`.

2. **`coverSleepScreen.qmd`** changes the sleep-screen source only when `current.png` exists. If it does not exist, xochitl keeps using its normal `SleepScreenPath`, which means stock behavior or the PNG selected through reManager.

The helper service checks the state every 2 seconds.

## Installation

Copy or clone this repository to the device, then run:

```sh
cd /home/root/remarkable-cover-sleep-xovi
chmod +x install.sh uninstall.sh cover-sleep-update.sh
./install.sh
```

The installer:

- copies `coverSleepScreen.qmd` to `/home/root/xovi/exthome/qt-resource-rebuilder/`;
- installs the helper as `/home/root/.local/bin/cover-sleep-update`;
- installs and enables `cover-sleep.service`;
- restarts XOVI/xochitl so the QMD becomes active.

### Install from a release archive

```sh
cd /home/root
tar xzf cover-sleep-xovi-v4.4.tar.gz
cd cover-sleep-xovi
./install.sh
```

### Updating after installing OS 3.28

Ensure XOVI and qt-resource-rebuilder work on the new firmware, then run
`./install.sh` from this release to reinstall the QMD and service.
Firmware updates may remove the service under `/etc/systemd/system`.
Do not enable another sleep-screen QMD (such as randomSleepScreen or
visibleSleepScreen) during validation: they can patch the same resources.

Validate on the tablet: open a PDF, wait two seconds and sleep; repeat with
another PDF and an EPUB. Return to Home, wait two seconds and sleep again;
the normal/reManager screen should return. Also check after a reboot.
If the patch fails to load, collect XOVI's patch error and the full firmware
version from `/etc/os-release` before claiming compatibility.

## Test / debug

Open a PDF or EPUB, wait a couple of seconds, then run:

```sh
/home/root/.local/bin/cover-sleep-update --debug
```

Expected output resembles:

```text
cover-sleep: document uuid=... method=lastopen name=...
cover-sleep: first page id=...
cover-sleep: sleep cover updated: ...
```

Check the generated state:

```sh
ls -lh /home/root/.cover-sleep/
cat /home/root/.cover-sleep/current.uuid
cat /home/root/.cover-sleep/current.method
```

Return to Home / My Files, wait two seconds and run:

```sh
/home/root/.local/bin/cover-sleep-update --debug
```

The dynamic files should be removed and the next sleep should use the normal/reManager sleep image.

Service diagnostics:

```sh
systemctl status cover-sleep.service --no-pager
journalctl -u cover-sleep.service -n 50 --no-pager
```

## Uninstall

```sh
./uninstall.sh
```

This removes the QMD, helper and service. `/home/root/.cover-sleep` is intentionally left in place; it can be removed manually if desired.

## Known limitations

- QMD patches are tied to the xochitl/QML resource hashes of compatible firmware versions.
- For EPUBs, “cover” means the first page rendered by reMarkable, which may differ from the cover image declared inside the EPUB. The helper does not extract the EPUB cover asset.
- Page selection uses the first page ID in `.content`; reordered/deleted page records and unfamiliar metadata layouts require device validation.
- A lone thumbnail for a different page is never used as a fallback.
- The first page must have a usable image in the document's `.thumbnails` or `.cache` directory.
- The helper currently polls every 2 seconds rather than subscribing to an xochitl event.
- The mod is not affiliated with or supported by reMarkable AS.
- Test carefully after every reMarkable OS update.

## Local regression checks

Run `python3 -m unittest discover -s tests -v` on a computer. These tests run the shell helper against isolated PDF/EPUB metadata and cache fixtures, including missing covers and returning Home. They do not validate rendering on a tablet.

## Files

```text
coverSleepScreen.qmd       XOVI QMD sleep-screen override
cover-sleep-update.sh      Detects current document and prepares current.png
cover-sleep.service        Background updater
install.sh                 Installer / upgrader
uninstall.sh               Removal script
CHANGELOG.md               Development history
LICENSE                    GNU GPL v3
```

## Credits

This project was developed by iterating on the reMarkable Paper Pro and builds on the work of the reMarkable modding community.

In particular:

- [XOVI / rm-xovi-extensions](https://github.com/asivery/rm-xovi-extensions) by asivery.
- [`xovi-qmd-extensions`](https://github.com/alefaraci/xovi-qmd-extensions) by alefaraci, especially the `visibleSleepScreen.qmd` approach to sleep-screen QML patching.
- [`xovi-qmd-extensions`](https://github.com/ingatellent/xovi-qmd-extensions) by ingatellent for examples of firmware-specific QMD extensions and document-navigation hooks.
- [reManager](https://github.com/rmitchellscott/reManager) by Mitchell Scott, used for managing reMarkable mods and custom static sleep screens.

If you reuse or modify code derived from GPL-licensed QMD work, preserve the relevant license and attribution.

## License

Licensed under **GNU GPL v3.0**. See [`LICENSE`](LICENSE).

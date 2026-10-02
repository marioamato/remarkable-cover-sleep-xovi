# Changelog

## v4.4.2 — 2026-10-02

- Fall back to the EPUB-specific `.thumbnails/cover.png` when the first-page thumbnail is missing, based on device diagnostics from OS 3.28.0.172.
- Preserve PDF selection and ignore empty cover files.
- Remove the misleading “no document open” message when clearing a missing cover.
- Add four regression tests; visual validation of the EPUB fallback is pending.

## v4.4.1 — 2026-10-02

- Fix firmware detection: prefer IMG_VERSION from /etc/os-release; VERSION_ID may identify the Linux base (for example 5.8.203).
- Keep VERSION_ID as a fallback only when IMG_VERSION is absent or empty.
- Add regression tests for the reported version mismatch and unsupported firmware.

## v4.4 — 2026-10-02

- Checked sleep-screen QMD selectors against upstream OS 3.28 patches; the selectors are unchanged from 3.27.
- Added an installer firmware check for 3.27.x / 3.28.x before any installation changes.
- Documented reinstalling after an OS update and the on-device validation procedure.
- Removed the unsafe single-image fallback: a cached non-cover page must not become the sleep screen.
- Select only one page ID when metadata is compact JSON.
- Added PDF/EPUB regression tests covering first-page selection, missing covers, deleted documents and Home.
- OS 3.28 device testing remains pending.

## v4.3 — 2026-08-28

First GitHub-ready working release.

- Uses xochitl's native `LastOpen` value as the primary source of truth for the open document.
- Shows the first-page thumbnail/cache image of the current PDF/EPUB as the sleep screen.
- Clears the dynamic cover when returning to Home / My Files.
- Falls back to the normal/reManager sleep image when no document is open.
- Keeps QML/QMD responsibility limited to choosing `current.png` when it exists.

## v4.2

- Attempted to clear the current document through a QML destruction hook.
- Rejected because the document view can remain alive when returning Home on 3.27.x.

## v4.1

- Fixed debug output contaminating the source-image path.
- Fixed the systemd shell path to `/usr/bin/sh`.

## v4

- Added QML-based current-document tracking.
- Proved reliable for detecting document changes, but retained stale state when leaving the document view.

## v3

- Added metadata/content based fallback detection and first-page thumbnail lookup.

## v2

- Replaced unavailable GNU `install` command with `cp`, `mkdir` and `chmod`.
- Corrected shell path for reMarkable Paper Pro.

## v1

- Initial experimental implementation.

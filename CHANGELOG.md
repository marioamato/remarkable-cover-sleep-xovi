# Changelog

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

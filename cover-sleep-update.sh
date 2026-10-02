#!/usr/bin/sh
# cover-sleep-update v4.4.2
# reMarkable OS 3.27.x / 3.28.x / Paper Pro experimental
#
# Source of truth: xochitl.conf -> LastOpen.
# Recent tooling confirms LastOpen contains the current document id and is
# null/empty while xochitl is showing the library rather than a document.

set -u

DATA="/home/root/.local/share/remarkable/xochitl"
CONF="/home/root/.config/remarkable/xochitl.conf"
OUTDIR="/home/root/.cover-sleep"
OUT="$OUTDIR/current.png"
TMP="$OUTDIR/.current.png.tmp"
STATE="$OUTDIR/current.uuid"
METHOD_STATE="$OUTDIR/current.method"
DEBUG=0
[ "${1:-}" = "--debug" ] && DEBUG=1

mkdir -p "$OUTDIR"

log() {
    logger -t cover-sleep "$*" 2>/dev/null || true
    [ "$DEBUG" -eq 1 ] && printf '%s\n' "cover-sleep: $*" >&2
}

debug() {
    [ "$DEBUG" -eq 1 ] && printf '%s\n' "cover-sleep: $*" >&2
}

clear_dynamic_cover() {
    had_cover=0
    [ -f "$OUT" ] && had_cover=1
    rm -f "$OUT" "$TMP" "$STATE" "$METHOD_STATE"
    if [ "$had_cover" -eq 1 ]; then
        log "dynamic cover removed, using default sleep screen"
    else
        debug "using default sleep screen"
    fi
}

is_document_uuid() {
    u="$1"
    [ -f "$DATA/$u.pdf" ] || [ -f "$DATA/$u.epub" ]
}

is_deleted() {
    u="$1"
    m="$DATA/$u.metadata"
    [ -f "$m" ] || return 1
    grep -q '"deleted"[[:space:]]*:[[:space:]]*true' "$m" 2>/dev/null
}

# Return status:
#   0: LastOpen key exists (value may intentionally contain no UUID => Home)
#   1: LastOpen key not found (older/unexpected firmware; fallback allowed)
lastopen_document() {
    [ -f "$CONF" ] || return 1

    line="$(grep -m1 '^LastOpen=' "$CONF" 2>/dev/null || true)"
    if [ -z "$line" ]; then
        # Be tolerant of case differences, without printing unrelated config.
        line="$(grep -im1 '^LastOpen=' "$CONF" 2>/dev/null || true)"
    fi
    [ -n "$line" ] || return 1

    value="${line#*=}"
    uuid="$(printf '%s\n' "$value" | grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | head -n1 || true)"

    if [ -z "$uuid" ]; then
        printf '%s\n' 'NONE|lastopen'
        return 0
    fi

    if is_document_uuid "$uuid" && ! is_deleted "$uuid"; then
        printf '%s|lastopen\n' "$uuid"
    else
        # LastOpen exists and is authoritative, but does not point to a usable
        # PDF/EPUB. Treat this as no cover rather than resurrecting an old doc.
        printf '%s\n' 'NONE|lastopen-nondoc'
    fi
    return 0
}

# Compatibility fallback only if LastOpen is absent altogether.
qml_current_document_value() {
    [ -d /home/root/.config ] || return 1
    settings_file="$(grep -R -l -m1 '^coverSleepCurrentDocId=' /home/root/.config 2>/dev/null | head -n1 || true)"
    [ -n "$settings_file" ] || return 1
    line="$(grep -m1 '^coverSleepCurrentDocId=' "$settings_file" 2>/dev/null || true)"
    value="${line#*=}"
    value="$(printf '%s' "$value" | tr -d '\r\"')"
    printf '%s\n' "$value"
    return 0
}

current_document_uuid_from_recent_xochitl_files() {
    for f in $(ls -1t "$DATA"/*.metadata "$DATA"/*.content 2>/dev/null); do
        base="${f##*/}"
        u="${base%.metadata}"
        u="${u%.content}"
        if is_document_uuid "$u" && ! is_deleted "$u"; then
            printf '%s\n' "$u"
            return 0
        fi
    done
    return 1
}

current_document_uuid() {
    detected="$(lastopen_document 2>/dev/null)"
    lastopen_rc=$?
    if [ "$lastopen_rc" -eq 0 ]; then
        printf '%s\n' "$detected"
        return 0
    fi

    # Old v4 QML fallback only if this firmware has no LastOpen key.
    qml_value="$(qml_current_document_value 2>/dev/null)"
    qml_rc=$?
    if [ "$qml_rc" -eq 0 ]; then
        if [ -z "$qml_value" ]; then
            printf '%s\n' 'NONE|qml'
            return 0
        fi
        if is_document_uuid "$qml_value" && ! is_deleted "$qml_value"; then
            printf '%s|qml\n' "$qml_value"
            return 0
        fi
    fi

    u="$(current_document_uuid_from_recent_xochitl_files 2>/dev/null || true)"
    if [ -n "$u" ]; then
        printf '%s|recent\n' "$u"
        return 0
    fi

    printf '%s\n' 'NONE|none'
}

first_page_id() {
    uuid="$1"
    content="$DATA/$uuid.content"
    [ -f "$content" ] || return 1
    UUID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

    page="$(
        sed -n '/"cPages"[[:space:]]*:/,$p' "$content" 2>/dev/null \
        | sed -n '/"pages"[[:space:]]*:/,/"uuids"[[:space:]]*:/p' \
        | grep -m1 -oE "$UUID_RE" | head -n1 \
        || true
    )"
    if [ -n "$page" ]; then
        printf '%s\n' "$page"
        return 0
    fi

    page="$(
        sed -n '/"pages"[[:space:]]*:/,$p' "$content" 2>/dev/null \
        | grep -m1 -oE "$UUID_RE" | head -n1 \
        || true
    )"
    [ -n "$page" ] && { printf '%s\n' "$page"; return 0; }
    return 1
}

pick_first_page_image() {
    uuid="$1"
    page="$(first_page_id "$uuid" 2>/dev/null || true)"

    if [ -n "$page" ]; then
        debug "first page id=$page"
        for f in \
            "$DATA/$uuid.thumbnails/$page.jpg" \
            "$DATA/$uuid.thumbnails/$page.jpeg" \
            "$DATA/$uuid.thumbnails/$page.png" \
            "$DATA/$uuid.cache/$page.png" \
            "$DATA/$uuid.cache/$page.jpg" \
            "$DATA/$uuid.cache/$page.jpeg"
        do
            if [ -f "$f" ]; then
                printf '%s\n' "$f"
                return 0
            fi
        done
    else
        debug "could not parse first page id from $DATA/$uuid.content"
    fi

    # EPUBs can store the cover separately from page-ID thumbnails.
    if [ -f "$DATA/$uuid.epub" ] && [ -s "$DATA/$uuid.thumbnails/cover.png" ]; then
        printf '%s\n' "$DATA/$uuid.thumbnails/cover.png"
        return 0
    fi

    # A sole cached image may be the last page read, not the cover.
    # Other cached pages are not valid fallbacks.

    return 1
}

visible_name() {
    uuid="$1"
    m="$DATA/$uuid.metadata"
    [ -f "$m" ] || return 0
    grep -m1 '"visibleName"' "$m" 2>/dev/null \
      | sed 's/.*"visibleName"[[:space:]]*:[[:space:]]*"//' \
      | sed 's/"[[:space:]]*,*[[:space:]]*$//' \
      || true
}

update_cover() {
    detected="$(current_document_uuid 2>/dev/null || true)"
    uuid="${detected%%|*}"
    method="${detected#*|}"

    if [ -z "$detected" ] || [ "$uuid" = "NONE" ]; then
        debug "document state: none method=${method:-?}"
        clear_dynamic_cover
        return 0
    fi

    name="$(visible_name "$uuid")"
    debug "document uuid=$uuid method=$method name=${name:-?}"

    src="$(pick_first_page_image "$uuid" 2>/dev/null || true)"
    if [ -z "$src" ]; then
        log "document $uuid (${name:-unknown}) detected via $method, but no first-page image or EPUB cover.png found; using default sleep screen"
        clear_dynamic_cover
        return 0
    fi

    old=""
    [ -f "$STATE" ] && old="$(cat "$STATE" 2>/dev/null || true)"

    if [ "$uuid" = "$old" ] && [ -f "$OUT" ] && [ "$OUT" -nt "$src" ]; then
        debug "cover already current: $OUT"
        return 0
    fi

    cp "$src" "$TMP" || return 1
    mv -f "$TMP" "$OUT"
    printf '%s\n' "$uuid" > "$STATE"
    printf '%s\n' "$method" > "$METHOD_STATE"
    log "sleep cover updated: ${name:-$uuid} via $method from $src"
}

update_cover

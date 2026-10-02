#!/usr/bin/sh
set -e

QMD_DIR="/home/root/xovi/exthome/qt-resource-rebuilder"
BIN_DIR="/home/root/.local/bin"
SRC_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# Read data only: do not execute /etc/os-release as a shell script.
OS_VERSION="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | head -n 1 | tr -d '\042\047\015')"
case "$OS_VERSION" in
    3.27|3.27.*|3.28|3.28.*) ;;
    *)
        echo "Unsupported reMarkable OS: ${OS_VERSION:-unknown}. Expected 3.27.x or 3.28.x; nothing installed." >&2
        exit 1
        ;;
esac

mkdir -p "$QMD_DIR" "$BIN_DIR" /home/root/.cover-sleep

cp "$SRC_DIR/coverSleepScreen.qmd" "$QMD_DIR/coverSleepScreen.qmd"
chmod 0644 "$QMD_DIR/coverSleepScreen.qmd"

cp "$SRC_DIR/cover-sleep-update.sh" "$BIN_DIR/cover-sleep-update"
chmod 0755 "$BIN_DIR/cover-sleep-update"

cp "$SRC_DIR/cover-sleep.service" /etc/systemd/system/cover-sleep.service
chmod 0644 /etc/systemd/system/cover-sleep.service

systemctl daemon-reload
systemctl enable cover-sleep.service >/dev/null 2>&1 || true
systemctl restart cover-sleep.service

# Restart XOVI/xochitl so the QMD sleep-screen override is applied.
if [ -x /home/root/xovi/start ]; then
    /home/root/xovi/start
else
    systemctl restart xochitl
fi

echo "Installed Cover Sleep Screen v4.4 and its update service on OS $OS_VERSION."
echo "Open a PDF (or return Home), wait ~2 seconds, then run:"
echo "  /home/root/.local/bin/cover-sleep-update --debug"

#!/usr/bin/sh
set -e
systemctl disable --now cover-sleep.service 2>/dev/null || true
rm -f /etc/systemd/system/cover-sleep.service
rm -f /home/root/.local/bin/cover-sleep-update
rm -f /home/root/xovi/exthome/qt-resource-rebuilder/coverSleepScreen.qmd
systemctl daemon-reload
if [ -x /home/root/xovi/start ]; then
    /home/root/xovi/start
else
    systemctl restart xochitl
fi
echo "Cover sleep mod removed. /home/root/.cover-sleep was left intact."

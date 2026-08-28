# Contributing

Issues and pull requests are welcome, especially for:

- compatibility with additional reMarkable OS versions;
- Paper Pro Move testing;
- replacing the 2-second polling loop with a reliable xochitl event/hook;
- more robust first-page image discovery;
- packaging for Vellum/reManager.

When reporting a bug, please include:

```sh
cat /etc/os-release
/home/root/.local/bin/cover-sleep-update --debug
systemctl status cover-sleep.service --no-pager
journalctl -u cover-sleep.service -n 50 --no-pager
```

Do **not** include SSH passwords, private document contents, or other sensitive data.

"""Firmware guard tests: execute the actual installer preflight in isolation."""
from pathlib import Path
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]

class FirmwareTests(unittest.TestCase):
    def check_version(self, contents, expected):
        with tempfile.TemporaryDirectory() as tmp:
            release = Path(tmp) / 'os-release'
            release.write_text(contents)
            script = (PROJECT / 'install.sh').read_text()
            # Stop before installation side effects; run the real detection/guard.
            preflight = script.split('# Read data only:', 1)[1].split('mkdir -p', 1)[0]
            preflight = '# Read data only:' + preflight
            preflight = preflight.replace('/etc/os-release', str(release))
            result = subprocess.run(['sh', '-ec', preflight + '\nprintf "%s" "$OS_VERSION"'], capture_output=True, text=True)
            if expected is None:
                self.assertNotEqual(result.returncode, 0)
            else:
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, expected)

    def test_paper_pro_linux_base_version(self):
        self.check_version('VERSION_ID=5.8.203\nIMG_VERSION="3.28.0.169"\n', '3.28.0.169')

    def test_unsupported_image_overrides_supported_base(self):
        self.check_version('VERSION_ID=3.28.0.169\nIMG_VERSION=3.29.0.1\n', None)

    def test_legacy_and_quotes(self):
        self.check_version("VERSION_ID='3.27.0.1'\n", '3.27.0.1')
        self.check_version("VERSION_ID=5.8.203\r\nIMG_VERSION='3.28.0.172'\r\n", '3.28.0.172')

    def test_unknown_or_unsupported(self):
        for value in ['', 'VERSION_ID=5.8.203\n', 'IMG_VERSION=3.280.1\n', 'IMG_VERSION=invalid\n']:
            with self.subTest(value=value):
                self.check_version(value, None)

if __name__ == '__main__':
    unittest.main()

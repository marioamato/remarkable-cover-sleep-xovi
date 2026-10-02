"""Run the actual shell helper with isolated tablet filesystem fixtures."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
DOC = '11111111-1111-1111-1111-111111111111'
FIRST = '22222222-2222-2222-2222-222222222222'
SECOND = '33333333-3333-3333-3333-333333333333'

class CoverTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data = self.root / '.local/share/remarkable/xochitl'
        self.data.mkdir(parents=True)
        self.conf = self.root / '.config/remarkable/xochitl.conf'
        self.conf.parent.mkdir(parents=True)
        self.conf.write_text('LastOpen=' + DOC + '\n')
        self.out = self.root / '.cover-sleep/current.png'
        script = (PROJECT / 'cover-sleep-update.sh').read_text()
        script = script.replace('/home/root', str(self.root))
        script = script.replace('logger -t cover-sleep', 'true')
        self.script = self.root / 'helper.sh'
        self.script.write_text(script)

    def document(self, kind, modern=False, compact=False):
        (self.data / (DOC + '.' + kind)).touch()
        pages = {'cPages': {'pages': [{'id': FIRST}, {'id': SECOND}]}} if modern else {'pages': [FIRST, SECOND]}
        (self.data / (DOC + '.content')).write_text(json.dumps(pages, indent=None if compact else 4))
        (self.data / (DOC + '.metadata')).write_text('{"deleted":false}')

    def thumb(self, page, value, directory='thumbnails', ext='jpg'):
        d = self.data / (DOC + '.' + directory)
        d.mkdir(exist_ok=True)
        (d / (page + '.' + ext)).write_bytes(value)

    def run_helper(self):
        subprocess.run(['sh', str(self.script), '--debug'], check=True, capture_output=True)

    def test_pdf_and_epub_first_page(self):
        for kind in ['pdf', 'epub']:
            for modern in [False, True]:
                for compact in [False, True]:
                    with self.subTest(kind=kind, modern=modern, compact=compact):
                        self.document(kind, modern, compact)
                        self.thumb(FIRST, b'first-page')
                        self.thumb(SECOND, b'wrong-page')
                        self.run_helper()
                        self.assertEqual(self.out.read_bytes(), b'first-page')
                        (self.data / (DOC + '.' + kind)).unlink()
                        self.out.unlink()

    def test_only_wrong_page_cached(self):
        for kind in ['pdf', 'epub']:
            with self.subTest(kind=kind):
                self.document(kind)
                self.thumb(SECOND, b'wrong-page')
                self.out.parent.mkdir(exist_ok=True)
                self.out.write_bytes(b'stale-cover')
                self.run_helper()
                self.assertFalse(self.out.exists())
                (self.data / (DOC + '.' + kind)).unlink()

    def test_unknown_first_page_does_not_guess(self):
        self.document('epub')
        (self.data / (DOC + '.content')).write_text('{}')
        self.thumb(SECOND, b'wrong-page')
        self.run_helper()
        self.assertFalse(self.out.exists())

    def test_epub_cache_and_home(self):
        self.document('epub', modern=True)
        self.thumb(FIRST, b'epub-cover', directory='cache', ext='png')
        self.run_helper()
        self.assertEqual(self.out.read_bytes(), b'epub-cover')
        self.conf.write_text('LastOpen=\n')
        self.run_helper()
        self.assertFalse(self.out.exists())

    def test_epub_dedicated_cover_without_first_page_thumbnail(self):
        self.document('epub')
        self.thumb(SECOND, b'wrong-page')
        self.thumb('cover', b'epub-cover', ext='png')
        self.run_helper()
        self.assertEqual(self.out.read_bytes(), b'epub-cover')

    def test_pdf_does_not_use_named_cover(self):
        self.document('pdf')
        self.thumb('cover', b'not-a-confirmed-first-page', ext='png')
        self.run_helper()
        self.assertFalse(self.out.exists())

    def test_first_page_precedes_named_cover(self):
        self.document('epub')
        self.thumb(FIRST, b'first-page')
        self.thumb('cover', b'other-cover', ext='png')
        self.run_helper()
        self.assertEqual(self.out.read_bytes(), b'first-page')

    def test_empty_epub_cover_is_ignored(self):
        self.document('epub')
        self.thumb('cover', b'', ext='png')
        self.run_helper()
        self.assertFalse(self.out.exists())

    def test_deleted_epub(self):
        self.document('epub')
        self.thumb(FIRST, b'cover')
        (self.data / (DOC + '.metadata')).write_text('{"deleted":true}')
        self.run_helper()
        self.assertFalse(self.out.exists())

if __name__ == '__main__':
    unittest.main()

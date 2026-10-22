"""
Smoke tests. Run from the package root:

    python -m unittest discover -s tests -v
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import numpy as np  # noqa: E402

import handbake  # noqa: E402
from handbake import bake, normalize_text, RenderSettings  # noqa: E402
from handbake.cli import main  # noqa: E402


class TextTests(unittest.TestCase):
    def test_rejects_unsupported(self):
        with self.assertRaises(ValueError):
            normalize_text('Quest')          # no capital Q in the model's alphabet
        with self.assertRaises(ValueError):
            normalize_text('x' * 80)         # longer than one line

    def test_fallback(self):
        self.assertEqual(normalize_text('Quälgeist', fallback=True), 'quaelgeist')
        self.assertEqual(normalize_text('café — “ok”', fallback=True), 'cafe - "ok"')


class BakeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.take = bake('hi there', style=5, seed=3)

    def test_deterministic(self):
        again = bake('hi there', style=5, seed=3)
        np.testing.assert_array_equal(self.take.offsets, again.offsets)

    def test_png_and_json_agree(self):
        rs = RenderSettings()
        img, meta = self.take.to_png(rs)
        self.assertEqual(img.mode, 'RGBA')
        self.assertGreater(img.getextrema()[3][1], 0, 'image has no ink')
        d = self.take.to_dict(rs, 'x.png')
        self.assertEqual((d['image']['width'], d['image']['height']), img.size)
        pts = np.vstack([s['points'] for s in d['strokes']])
        self.assertTrue((pts >= 0).all() and (pts[:, 0] <= img.width).all() and (pts[:, 1] <= img.height).all())
        for s in d['strokes']:
            self.assertEqual(len(s['points']), len(s['width']))
            self.assertEqual(len(s['points']), len(s['t']))

    def test_pow2(self):
        img, _ = self.take.to_png(RenderSettings(pow2=True))
        for v in img.size:
            self.assertEqual(v & (v - 1), 0)


class CliTests(unittest.TestCase):
    def test_cli_end_to_end(self):
        with tempfile.TemporaryDirectory() as tmp:
            rc = main(['died twice', '--style', '12', 'none', '--takes', '1',
                       '--sheet', '--jobs', '2', '--out', tmp])
            self.assertEqual(rc, 0)
            m = json.loads((Path(tmp) / 'manifest.json').read_text())
            self.assertEqual(len(m['takes']), 2)
            for t in m['takes']:
                self.assertTrue((Path(tmp) / t['png']).exists())
                self.assertTrue((Path(tmp) / t['json']).exists())
            self.assertTrue((Path(tmp) / 'sheet.png').exists())

    def test_cli_rejects_bad_text(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(main(['Quest log', '--out', tmp]), 2)
            self.assertEqual(main(['Quest log', '--fallback', '--check', '--out', tmp]), 0)


if __name__ == '__main__':
    unittest.main()

"""Provenance of the frozen HCOneButton fixtures.

The fixtures are fetched by scripts/fetch_fixtures.py and must stay
byte-identical to the blobs of HCOneButton commit e973acb.
"""
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import fetch_fixtures  # noqa: E402


class FixtureProvenanceTest(unittest.TestCase):
    def test_fixtures_match_recorded_blobs(self):
        for fixture, (_, blob) in fetch_fixtures.FIXTURES.items():
            data = (ROOT / fixture).read_bytes()
            self.assertEqual(fetch_fixtures.git_blob_sha1(data), blob, fixture)


if __name__ == "__main__":
    unittest.main()

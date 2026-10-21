"""Package build and verification (deliverable dist/ForeverOneButton-<version>.zip)."""
import pathlib
import shutil
import sys
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import package  # noqa: E402


class PackageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_build_is_complete_and_clean(self):
        target = package.build(dist=self.tmp)
        self.assertEqual(target.name, f"ForeverOneButton-{package.read_toc(ROOT / 'ForeverOneButton')[0]['Version']}.zip")
        self.assertEqual(package.verify(target), [])
        with zipfile.ZipFile(target) as archive:
            names = archive.namelist()
            self.assertTrue(all(n.startswith("ForeverOneButton/") for n in names))
            for required in ("ForeverOneButton/ForeverOneButton.toc", "ForeverOneButton/LICENSE",
                             "ForeverOneButton/NOTICE.md", "ForeverOneButton/README.md",
                             "ForeverOneButton/Media/icon.tga"):
                self.assertIn(required, names)
            self.assertFalse(any("/tests/" in n or "fixtures" in n for n in names))
            for name in names:
                if not package.is_binary(name):
                    self.assertNotIn(b"\r\n", archive.read(name), name)
            icon = archive.read("ForeverOneButton/Media/icon.tga")
            self.assertEqual(icon, (ROOT / "ForeverOneButton" / "Media" / "icon.tga").read_bytes(), "icon shipped byte for byte")

    def test_build_is_reproducible(self):
        first = package.build(dist=self.tmp / "a").read_bytes()
        second = package.build(dist=self.tmp / "b").read_bytes()
        self.assertEqual(first, second)

    def test_verify_rejects_extra_and_forbidden_entries(self):
        target = package.build(dist=self.tmp)
        with zipfile.ZipFile(target, "a") as archive:
            archive.writestr("ForeverOneButton/Spam.lua", "local SpamButton = true")
            archive.writestr("Other/file.lua", "")
        problems = package.verify(target)
        self.assertTrue(any("entries differ" in p for p in problems))
        self.assertTrue(any("outside" in p for p in problems))
        self.assertTrue(any("forbidden" in p for p in problems))


if __name__ == "__main__":
    unittest.main()

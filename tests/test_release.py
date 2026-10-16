"""Offline tests for scripts/release.py (no network, no token)."""
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("release", ROOT / "scripts" / "release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

FOREVER = {"id": 17053, "name": "1.60.1", "gameVersionTypeID": release.FOREVER_VERSION_TYPE}


def copy_repo(target):
    shutil.copytree(ROOT / "ForeverOneButton", target / "ForeverOneButton")
    for name in ("README.md", "CHANGELOG.md", "LICENSE"):
        shutil.copy(ROOT / name, target / name)


def set_version(root, old, new):
    for path, pattern in ((root / "ForeverOneButton" / "ForeverOneButton.toc", "## Version: {}"),
                          (root / "ForeverOneButton" / "Core" / "Init.lua", 'ns.VERSION = "{}"'),
                          (root / "CHANGELOG.md", "## {} ")):
        text = path.read_text(encoding="utf-8")
        assert pattern.format(old) in text, (path, old)
        path.write_text(text.replace(pattern.format(old), pattern.format(new), 1), encoding="utf-8")


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeOpener:
    def __init__(self, responses):
        self.responses = responses
        self.requests = []

    def open(self, request, timeout):
        self.requests.append(request)
        return FakeResponse(json.dumps(self.responses[request.full_url[len(release.API_ROOT):]]).encode())


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.summary = os.environ.pop("GITHUB_STEP_SUMMARY", None)
        self.tmp = Path(tempfile.mkdtemp())
        copy_repo(self.tmp)
        self.version = release.version_info(self.tmp)[0]

    def tearDown(self):
        shutil.rmtree(self.tmp)
        if self.summary is not None:
            os.environ["GITHUB_STEP_SUMMARY"] = self.summary

    def test_versions_agree_with_the_tag(self):
        self.assertEqual(release.check_version("v" + self.version, self.tmp), self.version)
        with self.assertRaises(release.ReleaseError):
            release.check_version("v9.9.9", self.tmp)
        with self.assertRaises(release.ReleaseError):
            release.check_version(self.version, self.tmp)  # no "v"

    def test_runtime_version_must_match(self):
        init = self.tmp / "ForeverOneButton" / "Core" / "Init.lua"
        init.write_text(re.sub(r'ns\.VERSION = "[^"]+"', 'ns.VERSION = "0.0.1"', init.read_text(encoding="utf-8")),
                        encoding="utf-8")
        with self.assertRaises(release.ReleaseError):
            release.version_info(self.tmp)

    def test_release_type_from_the_version(self):
        self.assertEqual(release.release_type("1.0.0"), "release")
        self.assertEqual(release.release_type("1.0.0-beta.1"), "beta")
        self.assertEqual(release.release_type("1.0.0-alpha.2"), "alpha")

    def test_package_writes_zip_notes_and_manifest(self):
        out = self.tmp / "release" / "ci"
        manifest = release.package(self.tmp, out)
        self.assertEqual(manifest["gameVersion"], "1.60.1")
        self.assertTrue((out / manifest["zip"]).is_file())
        notes = (out / manifest["notes"]).read_text(encoding="utf-8")
        self.assertTrue(notes.startswith("## " + self.version))
        self.assertNotIn("## 0.2.0", notes, "only this version's section")
        with self.assertRaises(release.ReleaseError):
            release.package(self.tmp, out)  # never into a used folder

    def test_upload_beta_with_receipt_and_no_second_upload(self):
        set_version(self.tmp, self.version, self.version + "-beta.1")
        out = self.tmp / "release" / "ci"
        release.package(self.tmp, out)
        opener = FakeOpener({"/game/wow/versions": [FOREVER, {"id": 1, "name": "1.60.1", "gameVersionTypeID": 67408}],
                             "/projects/123/upload-file": {"id": 456}})
        receipt = release.upload(self.tmp, out, "token", "123", opener)
        self.assertEqual(receipt["fileId"], 456)
        self.assertEqual(receipt["releaseType"], "beta")
        body = opener.requests[1].data.decode("utf-8", "replace")
        self.assertIn('"releaseType": "beta"', body)
        self.assertIn('"gameVersions": [17053]', body)
        self.assertEqual(opener.requests[1].get_header("X-api-token"), "token")
        with self.assertRaises(release.ReleaseError):
            release.upload(self.tmp, out, "token", "123", opener)

    def test_upload_refuses_without_a_unique_forever_version(self):
        out = self.tmp / "release" / "ci"
        release.package(self.tmp, out)
        for versions in ([], [FOREVER, dict(FOREVER, id=17054)], [dict(FOREVER, gameVersionTypeID=67408)]):
            with self.assertRaises(release.ReleaseError):
                release.upload(self.tmp, out, "token", "123", FakeOpener({"/game/wow/versions": versions}))

    def test_upload_requires_token_project_and_an_unchanged_package(self):
        out = self.tmp / "release" / "ci"
        manifest = release.package(self.tmp, out)
        with self.assertRaises(release.ReleaseError):
            release.upload(self.tmp, out, "", "123")
        with self.assertRaises(release.ReleaseError):
            release.upload(self.tmp, out, "token", "abc")
        (out / manifest["zip"]).write_bytes(b"tampered")
        with self.assertRaises(release.ReleaseError):
            release.upload(self.tmp, out, "token", "123", FakeOpener({"/game/wow/versions": [FOREVER]}))


if __name__ == "__main__":
    unittest.main()

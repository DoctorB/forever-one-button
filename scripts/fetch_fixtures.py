"""Fetch the frozen HCOneButton fixtures into tests/fixtures/hcob/.

The fixtures are not stored in this repository. They are read from
HCOneButton commit e973acb: from a local checkout when available (HCOB_REPO,
default ../hc-one-button, read-only `git show`), otherwise from GitHub. Every
file must match its recorded Git blob hash, or nothing is written.
"""
import hashlib
import os
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMMIT = "e973acba84e3911ddb6a68655d247426df7bdf4f"
RAW_URL = "https://raw.githubusercontent.com/DoctorB/hc-one-button/{commit}/{path}"
FIXTURES = {
    "tests/fixtures/hcob/DiagnosticPixel.lua": ("HCOneButton/UI/DiagnosticPixel.lua",
                                                "3c6b405084612743396d68cbf1938de8bdcd8464"),
    "tests/fixtures/hcob/diagnostic_pixel_edge.lua": ("tests/diagnostic_pixel_edge.lua",
                                                      "ac792476979bc27dbaa91665e89e2a060645086f"),
}


def git_blob_sha1(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def read_source(path):
    repo = pathlib.Path(os.environ.get("HCOB_REPO", ROOT.parent / "hc-one-button"))
    if (repo / ".git").exists():
        shown = subprocess.run(["git", "-C", str(repo), "show", f"{COMMIT}:{path}"],
                               capture_output=True, check=False)
        if shown.returncode == 0:
            return shown.stdout
    with urllib.request.urlopen(RAW_URL.format(commit=COMMIT, path=path), timeout=30) as response:
        return response.read()


def main():
    contents = {}
    for fixture, (path, blob) in FIXTURES.items():
        target = ROOT / fixture
        if target.exists() and git_blob_sha1(target.read_bytes()) == blob:
            continue
        data = read_source(path)
        if git_blob_sha1(data) != blob:
            sys.exit(f"{path}: blob hash mismatch, expected {blob}")
        contents[target] = data
    for target, data in contents.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    print(f"fixtures: {len(FIXTURES)} verified")


if __name__ == "__main__":
    main()

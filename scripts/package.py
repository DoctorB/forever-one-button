"""Build and verify dist/ForeverOneButton-<version>.zip.

    python scripts/package.py build    # build, then verify
    python scripts/package.py verify   # verify an existing package

The package has one root folder, ForeverOneButton/, holding exactly the TOC,
the files it lists, the license, the attribution notice and the README.
Entries use a fixed timestamp so the same commit gives the same bytes.
"""
import argparse
import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = "ForeverOneButton"
FIXED_TIME = (2026, 1, 1, 0, 0, 0)
# Code that must never ship: HCOneButton decision code and excluded features.
# Checked in .lua and .toc entries (the docs legitimately say they are absent).
CODE_FORBIDDEN = [
    re.compile(rb"HCOB_DB|HCOneButton\.Internal|Advisor/Engine|EvaluatePrePullReadiness"),
    re.compile(rb"[Ss]pam[A-Z_ ]?[Bb]utton|[Pp]ull[ _]?[Aa]dvisor|[Aa]uto[ _-]?[Pp]ull"),
]
# Never in any entry: local paths and anything that looks like a credential.
FORBIDDEN = [
    re.compile(rb"C:\\\\Users|C:/Users|/home/[a-z]"),
    re.compile(rb"(?i)(api[_-]?token|secret[_-]?key|password)\s*[=:]\s*['\"][^'\"]+"),
    re.compile(rb"gh[pousr]_[A-Za-z0-9]{20,}"),
]


def read_toc(addon_dir):
    fields, files = {}, []
    for line in (addon_dir / f"{ADDON}.toc").read_text(encoding="utf-8").splitlines():
        match = re.match(r"^##\s*([^:]+):\s*(.*?)\s*$", line)
        if match:
            fields[match.group(1)] = match.group(2)
        elif line.strip() and not line.startswith("#"):
            files.append(line.strip().replace("\\", "/"))
    return fields, files


def expected_entries(addon_dir):
    _, files = read_toc(addon_dir)
    names = [f"{ADDON}.toc", *files, "LICENSE", "NOTICE.md", "README.md"]
    return [f"{ADDON}/{name}" for name in names]


def source_for(entry, addon_dir):
    relative = entry[len(ADDON) + 1:]
    if relative == "README.md":
        return ROOT / "README.md"
    return addon_dir / relative


def package_path(version, dist):
    return dist / f"{ADDON}-{version}.zip"


def build(root=ROOT, dist=None):
    addon_dir = root / ADDON
    dist = dist or root / "dist"
    fields, _ = read_toc(addon_dir)
    version = fields["Version"]
    dist.mkdir(parents=True, exist_ok=True)
    target = package_path(version, dist)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for entry in expected_entries(addon_dir):
            data = source_for(entry, addon_dir).read_bytes().replace(b"\r\n", b"\n")
            info = zipfile.ZipInfo(entry, FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data)
    return target


def verify(target, root=ROOT):
    addon_dir = root / ADDON
    problems = []
    expected = expected_entries(addon_dir)
    with zipfile.ZipFile(target) as archive:
        names = archive.namelist()
        if sorted(names) != sorted(expected):
            extra = sorted(set(names) - set(expected))
            missing = sorted(set(expected) - set(names))
            problems.append(f"entries differ: extra={extra} missing={missing}")
        for name in names:
            if not name.startswith(f"{ADDON}/") or ".." in name:
                problems.append(f"entry outside {ADDON}/: {name}")
            data = archive.read(name)
            patterns = FORBIDDEN + (CODE_FORBIDDEN if name.endswith((".lua", ".toc")) else [])
            for pattern in patterns:
                if pattern.search(data):
                    problems.append(f"forbidden content {pattern.pattern!r} in {name}")
        if f"{ADDON}/{ADDON}.toc" in names:
            toc = archive.read(f"{ADDON}/{ADDON}.toc").decode("utf-8")
            for required in ("## Interface: 16001", "## Title: Forever One Button",
                             "## SavedVariables: ForeverOneButtonDB"):
                if required not in toc:
                    problems.append(f"TOC lacks {required!r}")
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["build", "verify"])
    args = parser.parse_args(argv)
    fields, _ = read_toc(ROOT / ADDON)
    target = package_path(fields["Version"], ROOT / "dist")
    if args.command == "build":
        target = build()
    if not target.exists():
        print(f"missing package: {target}", file=sys.stderr)
        return 1
    problems = verify(target)
    for problem in problems:
        print(f"FAIL: {problem}", file=sys.stderr)
    if problems:
        return 1
    with zipfile.ZipFile(target) as archive:
        count = len(archive.namelist())
    print(f"{target.relative_to(ROOT).as_posix()}: {count} entries verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())

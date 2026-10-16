"""Forever One Button release gates, packaging and CurseForge upload.

Python 3 standard library only. Every command except `upload` and `catalog`
is offline.

  python3 scripts/release.py check-version --tag vX   tag = TOC = runtime = changelog
  python3 scripts/release.py package [--out DIR]       build + verify ZIP, notes, manifest
  python3 scripts/release.py catalog                   read-only CurseForge version lookup
  python3 scripts/release.py upload [--out DIR]        upload the verified ZIP

The release type follows the version: "-alpha.N" alpha, "-beta.N" beta,
otherwise release. The CurseForge token is read only from the CF_API_TOKEN
environment variable and the project id from CF_PROJECT_ID; neither is ever
printed. Adapted from the release tooling of Forever ChatGuard (same author).
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import package as packager  # noqa: E402  (the verified, reproducible ZIP)

ADDON = packager.ADDON
TAG = re.compile(r"v(\d+\.\d+\.\d+(?:-(?:alpha|beta)\.\d+)?)\Z")
API_ROOT = "https://www.curseforge.com/api"
# CurseForge game version type for WoW Forever: the only type listing 1.60.1
# (id 17053), as recorded by Forever ChatGuard on 2026-10-14. Pinned; the
# upload refuses to guess when that type has no unique matching version.
FOREVER_VERSION_TYPE = 88568


class ReleaseError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def report(message):
    print(message)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(message + "\n")


def version_info(root=ROOT):
    fields, _ = packager.read_toc(root / ADDON)
    version = fields.get("Version", "")
    require(TAG.fullmatch("v" + version), f"Invalid TOC version {version!r}")
    interface = fields.get("Interface", "")
    require(re.fullmatch(r"\d{5,6}", interface), "Invalid TOC Interface")
    init = (root / ADDON / "Core" / "Init.lua").read_text(encoding="utf-8")
    match = re.search(r'ns\.VERSION = "([^"]+)"', init)
    require(match and match[1] == version, "TOC and Core/Init.lua versions differ")
    changelog_section(version, root)
    number = int(interface)
    game_version = f"{number // 10000}.{number // 100 % 100}.{number % 100}"
    return version, interface, game_version


def changelog_section(version, root=ROOT):
    text = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(r"^## " + re.escape(version) + r"(?![\w.-])[^\n]*\n.*?(?=^## |\Z)",
                      text, re.MULTILINE | re.DOTALL)
    require(match, f"CHANGELOG.md has no section for {version}")
    return match[0].strip() + "\n"


def release_type(version):
    if "-alpha." in version:
        return "alpha"
    if "-beta." in version:
        return "beta"
    return "release"


def check_version(tag, root=ROOT):
    version = version_info(root)[0]
    match = TAG.fullmatch(tag or "")
    require(match and match[1] == version, f"Tag {tag!r} does not equal v{version}")
    report(f"Tag {tag} matches TOC, runtime and changelog version {version} ({release_type(version)}).")
    return version


def package(root, out):
    version, interface, game_version = version_info(root)
    require(not out.exists() or not any(out.iterdir()), f"{out} is not empty")
    out.mkdir(parents=True, exist_ok=True)
    archive_path = packager.build(root, out)
    problems = packager.verify(archive_path, root)
    require(not problems, "Package verification failed: " + "; ".join(problems))
    with zipfile.ZipFile(archive_path) as archive:
        files = {name: digest(archive.read(name)) for name in archive.namelist()}
    notes_name = f"{ADDON}-{version}-notes.md"
    (out / notes_name).write_text(changelog_section(version, root), encoding="utf-8", newline="\n")
    manifest = {"version": version, "releaseType": release_type(version), "interface": interface,
                "gameVersion": game_version, "zip": archive_path.name,
                "sha256": digest(archive_path.read_bytes()), "files": files, "notes": notes_name,
                "notesSha256": digest((out / notes_name).read_bytes())}
    with (out / "manifest.json").open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    report(f"Verified {archive_path.name}: {len(files)} files, sha256 {manifest['sha256']}. No upload performed.")
    return manifest


# ---------------------------------------------------------------- CurseForge

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # never forward the token to another host


def request_json(path, token, data=None, content_type=None, opener=None):
    headers = {"X-Api-Token": token, "Accept": "application/json", "User-Agent": "ForeverOneButton-Release"}
    if content_type:
        headers["Content-Type"] = content_type
    request = urllib.request.Request(API_ROOT + path, data=data, headers=headers)
    opener = opener or urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(request, timeout=60) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        # Status and path only: remote bodies are never printed.
        raise ReleaseError(f"CurseForge returned HTTP {error.code} for {'POST' if data else 'GET'} {path}. "
                           "Check the project's Files page before any retry; no automatic retry was made.") from None
    except (urllib.error.URLError, OSError, ValueError):
        raise ReleaseError("CurseForge request failed or was ambiguous. Check the project's "
                           "Files page before any retry; no automatic retry was made.") from None


def forever_game_version(versions, name):
    """Exactly one version of the pinned Forever type with the exact name."""
    require(isinstance(versions, list), "Invalid CurseForge version catalog")
    matches = [v.get("id") for v in versions if isinstance(v, dict)
               and v.get("gameVersionTypeID") == FOREVER_VERSION_TYPE and v.get("name") == name]
    require(len(matches) == 1 and isinstance(matches[0], int) and matches[0] > 0,
            f"No unique WoW Forever game version {name} (type {FOREVER_VERSION_TYPE}); refusing to guess")
    return matches[0]


def multipart(metadata, filename, content):
    boundary = "fob-" + uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n"
            "Content-Type: application/json\r\n\r\n").encode()
    body += json.dumps(metadata, ensure_ascii=False).encode("utf-8")
    body += (f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
             f"filename=\"{filename}\"\r\nContent-Type: application/zip\r\n\r\n").encode()
    return body + content + f"\r\n--{boundary}--\r\n".encode(), "multipart/form-data; boundary=" + boundary


def upload(root, out, token, project_id, opener=None):
    require(token and token.strip(), "Missing CF_API_TOKEN secret")
    require(project_id and project_id.isdigit(), "Missing or invalid CF_PROJECT_ID variable")
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    archive_path = out / manifest["zip"]
    content = archive_path.read_bytes()
    require(digest(content) == manifest["sha256"], "Package changed after verification")
    with zipfile.ZipFile(archive_path) as archive:
        require({name: digest(archive.read(name)) for name in archive.namelist()} == manifest["files"],
                "Package contents changed after verification")
    receipt_path = out / "curseforge-receipt.json"
    require(not receipt_path.exists(), "This package already has an upload receipt")
    versions = request_json("/game/wow/versions", token, opener=opener)
    version_id = forever_game_version(versions, manifest["gameVersion"])
    notes = (out / manifest["notes"]).read_text(encoding="utf-8")
    metadata = {"changelog": notes, "changelogType": "markdown",
                "displayName": f"Forever One Button {manifest['version']}",
                "releaseType": manifest["releaseType"], "gameVersions": [version_id]}
    body, content_type = multipart(metadata, manifest["zip"], content)
    result = request_json(f"/projects/{project_id}/upload-file", token, body, content_type, opener=opener)
    require(isinstance(result, dict) and isinstance(result.get("id"), int) and result["id"] > 0,
            "Upload response ambiguous: check CurseForge before retrying")
    receipt = {"projectId": int(project_id), "fileId": result["id"], "version": manifest["version"],
               "releaseType": manifest["releaseType"], "sha256": manifest["sha256"]}
    with receipt_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(receipt, stream, indent=2)
        stream.write("\n")
    report(f"CurseForge accepted file {result['id']} for project {project_id} ({manifest['releaseType']}). "
           "Accepted is not yet approved/public: check the moderation status.")
    return receipt


def catalog(root, token, opener=None):
    """Read-only: reports the CurseForge game version the upload would target."""
    require(token and token.strip(), "Missing CF_API_TOKEN secret")
    game_version = version_info(root)[2]
    versions = request_json("/game/wow/versions", token, opener=opener)
    require(isinstance(versions, list), "Invalid CurseForge version catalog")
    candidates = [v for v in versions if isinstance(v, dict) and str(v.get("name", "")).startswith("1.60")]
    report(f"Versions named 1.60.* ({len(candidates)}):")
    for item in candidates:
        report(f"- {item.get('id')}: {item.get('name')} (type {item.get('gameVersionTypeID')})")
    try:
        version_id = forever_game_version(versions, game_version)
        report(f"Upload target resolved: WoW Forever {game_version} -> game version id {version_id}.")
    except ReleaseError as error:
        report(f"Upload target NOT resolved for {game_version}: {error}")
    report("Read-only check: nothing was uploaded.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=("check-version", "package", "catalog", "upload"))
    parser.add_argument("--out", default="release/ci")
    parser.add_argument("--tag")
    args = parser.parse_args(argv)
    out = (ROOT / args.out).resolve()
    if args.command == "check-version":
        check_version(args.tag)
    elif args.command == "package":
        package(ROOT, out)
    elif args.command == "catalog":
        catalog(ROOT, os.environ.get("CF_API_TOKEN"))
    else:
        upload(ROOT, out, os.environ.get("CF_API_TOKEN"), os.environ.get("CF_PROJECT_ID", ""))


if __name__ == "__main__":
    try:
        main()
    except (ReleaseError, OSError, KeyError, ValueError) as error:
        print(f"Release stopped: {error}", file=sys.stderr)
        sys.exit(1)

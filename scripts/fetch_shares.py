"""Download the logs players shared at trace.lucabottani.dev and analyze them.

    py -B scripts/fetch_shares.py [--all]

Reads ADMIN_TOKEN from trace-server/.dev.vars (git-ignored), lists the
stored logs, downloads the ones not yet in local/shares/ and runs
scripts/analyze_log.py on each new one (--all: on every downloaded log).
"""
import argparse
import json
import os
import sys
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = "https://trace.lucabottani.dev"
OUT = os.path.join(ROOT, "local", "shares")
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import analyze_log  # noqa: E402


def token():
    path = os.path.join(ROOT, "trace-server", ".dev.vars")
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            key, _, value = line.strip().partition("=")
            if key == "ADMIN_TOKEN":
                return value.strip().strip('"')
    raise SystemExit("ADMIN_TOKEN not found in trace-server/.dev.vars")


def get(path, secret):
    request = urllib.request.Request(BASE + path, headers={"Authorization": "Bearer " + secret,
                                                          "User-Agent": "fob-fetch-shares"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def local_path(key):
    return os.path.join(OUT, key.replace("/", "_"))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--all", action="store_true", help="analyze every downloaded log, not only new ones")
    args = parser.parse_args(argv)
    secret = token()
    objects, cursor = [], None
    while True:
        query = "?prefix=fob/" + ("&cursor=" + urllib.parse.quote(cursor) if cursor else "")
        page = json.loads(get("/admin/list" + query, secret))
        objects += page["objects"]
        cursor = page.get("cursor")
        if not cursor:
            break
    os.makedirs(OUT, exist_ok=True)
    new = []
    for obj in objects:
        target = local_path(obj["key"])
        if not os.path.exists(target):
            with open(target, "wb") as handle:
                handle.write(get("/admin/get?key=" + urllib.parse.quote(obj["key"]), secret))
            new.append(obj)
    print(f"{len(objects)} logs stored, {len(new)} new")
    for obj in objects if args.all else new:
        meta = obj.get("meta") or {}
        print(f"\n#### {obj['key']}  {meta.get('class', '?')} lv {meta.get('level', '?')}"
              f"  FOB {meta.get('addon', '?')}  build {meta.get('build', '?')}")
        analyze_log.main([local_path(obj["key"])])
    return 0


if __name__ == "__main__":
    sys.exit(main())

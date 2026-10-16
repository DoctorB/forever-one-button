"""Import the WoW Forever data tables of JustAC 6.0.0 into ForeverOneButton/Data/.

    python scripts/import_justac_data.py [--justac <folder>] [--lua <lua5.1>]

The source files must match the SHA-256 hashes recorded below (JustAC 6.0.0 as
installed by the CurseForge app); a different JustAC version is refused, so
every change of the data is a deliberate update of this script. The capture
itself runs in scripts/import_justac_data.lua.
"""
import argparse
import hashlib
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "ForeverOneButton" / "Data"
DEFAULT_JUSTAC = r"C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\JustAC"
VERSION = "6.0.0"
SOURCES = {
    "Data/Forever/Rotations.lua": "3febf631366848e05d58e3a7ba629f2a6aa545022dc0f8ac2d8adc485f618706",
    "Data/Forever/Defaults.lua": "143fba6750c16322cd44d2c6fc45164a9dcb3754c49c58786256d91c4ceaba4d",
    "Data/Forever/Consumables.lua": "12b19d9e73c9e1554ca3332334bbe91bbc984c6fa3184b5266fd471c1dd0f404",
    "Data/InterruptAbilities.lua": "36301e8ed96b95bfdaf6ab2cf89fe311963fe030aa825660ef8321799adbb547",
    "Data/CCBreakers.lua": "d8f6ca8bcfab2821f9a98b31b63605f04997e5d1d1fc634573d32da1e7dba6f9",
}
OUTPUTS = ["Rotations", "Defaults", "Interrupts", "Consumables", "CCBreakers"]


def find_lua(explicit):
    if explicit:
        return explicit
    for name in ("lua5.1", "lua"):
        found = shutil.which(name)
        if found:
            return found
    bundled = pathlib.Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Lua51" / "lua.exe"
    if bundled.exists():
        return str(bundled)
    sys.exit("lua5.1 not found; pass --lua")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--justac", default=DEFAULT_JUSTAC)
    parser.add_argument("--lua")
    args = parser.parse_args()
    justac = pathlib.Path(args.justac)
    toc = (justac / "JustAC.toc").read_text(encoding="utf-8", errors="replace")
    if f"## Version: {VERSION}" not in toc:
        sys.exit(f"JustAC {VERSION} expected in {justac}")
    for path, digest in SOURCES.items():
        actual = hashlib.sha256((justac / path).read_bytes()).hexdigest()
        if actual != digest:
            sys.exit(f"{path}: sha256 {actual}, expected {digest}")
    with tempfile.TemporaryDirectory() as scratch:
        subprocess.run([find_lua(args.lua), str(ROOT / "scripts" / "import_justac_data.lua"), str(justac), scratch],
                       check=True)
        OUTPUT.mkdir(parents=True, exist_ok=True)
        for name in OUTPUTS:
            shutil.copyfile(pathlib.Path(scratch) / f"{name}.lua", OUTPUT / f"{name}.lua")
    print(f"data: {len(OUTPUTS)} files written to {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

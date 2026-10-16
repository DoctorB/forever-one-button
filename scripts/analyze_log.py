"""Analyze the Forever One Button diagnostic log (ForeverOneButtonLog).

    python scripts/analyze_log.py [path\\to\\ForeverOneButton.lua]

Without a path it looks in the Forever client's SavedVariables:
World of Warcraft\\_classic_beta_\\WTF\\Account\\*\\SavedVariables\\ForeverOneButton.lua
The client writes the file on /reload or logout. Enable the log in game with
`/fob log on`.

Reports every acknowledgement edge (black after a successful cast of the
encoded spell): its duration, the colour before and after, and casts whose
spell ID was secret (no edge possible). Pixel lines carry the frame time
(GetTime) used by the edge timer and by the screen; durations use it when
present (logs from before it fall back to the precise write time).
"""
import argparse
import glob
import os
import re
import sys

ACK_MIN_SECONDS = 0.060
SAMPLE_SECONDS = 0.020  # one frame at 50 Hz
DEFAULT_GLOB = r"C:\Program Files (x86)\World of Warcraft\_classic_beta_\WTF\Account\*\SavedVariables\ForeverOneButton.lua"


def read_entries(text):
    start = text.find("ForeverOneButtonLog")
    if start < 0:
        return []
    block = text[start:]
    entries = re.findall(r'"(\d+(?:\.\d+)?\|[a-z]+\|[^"\n]*)"', block)
    return entries


def summarize(entries):
    result = {"casts": 0, "secret_casts": 0, "acknowledged": 0, "edges": [], "short": 0, "open": 0,
              "restarted": 0, "combats": 0, "pixel_writes": 0}
    pending = None
    black_since = before = None
    last_colour = previous_colour = last_time = None
    for entry in entries:
        parts = entry.split("|")
        t, event = float(parts[0]), parts[1]
        a = parts[2] if len(parts) > 2 else None
        b = parts[3] if len(parts) > 3 else None
        if event == "pixel" and b is not None:
            try:
                t = float(b)
            except ValueError:
                pass
        if event == "cast":
            result["casts"] += 1
            if a == "secret":
                result["secret_casts"] += 1
            if b == "1":
                result["acknowledged"] += 1
                restarting = pending is not None and black_since is not None
                if pending is not None:
                    result["restarted"] += 1
                pending = t
                if restarting:
                    pass  # the black already shown continues
                elif last_colour == "black":
                    black_since, before = last_time, previous_colour
                else:
                    black_since, before = None, last_colour
        elif event == "pixel":
            result["pixel_writes"] += 1
            if pending is not None:
                if a == "black":
                    black_since = black_since if black_since is not None else t
                elif black_since is not None:
                    duration = t - black_since
                    result["edges"].append({"at": black_since, "duration": duration, "before": before, "after": a})
                    if duration + 1e-6 < ACK_MIN_SECONDS:
                        result["short"] += 1
                    pending = None
            previous_colour, last_colour, last_time = last_colour, a, t
        elif event == "combat" and a == "in":
            result["combats"] += 1
        elif event == "combat" and a == "out" and pending is not None:
            result["open"] += 1
            pending = None
    if pending is not None:
        result["open"] += 1
    return result


def timeline(entries):
    """Visible pixel states (what the screen shows), identical
    consecutive writes merged, timed on frame time when logged."""
    segments = []
    for entry in entries:
        parts = entry.split("|")
        if len(parts) < 3 or parts[1] != "pixel":
            continue
        t = float(parts[0])
        if len(parts) > 3:
            try:
                t = float(parts[3])
            except ValueError:
                pass
        state = parts[2]
        cell = parts[4] if len(parts) > 4 else None
        if not segments or segments[-1]["state"] != state:
            if segments:
                segments[-1]["duration"] = t - segments[-1]["start"]
            segments.append({"state": state, "start": t, "duration": None, "cell": cell})
    cycles = sum(1 for s in segments if s["state"] != "black")
    short = [s for s in segments if s["duration"] is not None and s["duration"] + 1e-6 < SAMPLE_SECONDS]
    return {"segments": segments, "cycles": cycles, "short": short}


def timeline_report(view, limit=200):
    lines = [f"pixel timeline: {len(view['segments'])} visible states, {view['cycles']} recommendation cycles, "
             f"{len(view['short'])} shorter than 20 ms (may be missed at 50 Hz)"]
    for s in view["segments"][-limit:]:
        duration = "open" if s["duration"] is None else f"{s['duration'] * 1000:7.1f} ms"
        meaning = {"black": "no action", "white": "suggestion not on the grid"}.get(s["state"], s["cell"] or "")
        flag = "  <-- shorter than one 50 Hz sample" if s in view["short"] else ""
        state = s["state"] if s["state"] in ("black", "white") else f"slot {s['state']}"
        lines.append(f"  {s['start']:.3f}s  {state:<8} {duration}  {meaning}{flag}")
    return "\n".join(lines)


def report(result):
    lines = [
        f"pixel writes: {result['pixel_writes']}, combats: {result['combats']}",
        f"casts: {result['casts']} (secret spell ID: {result['secret_casts']}), acknowledged: {result['acknowledged']}",
        f"edges: {len(result['edges'])}, shorter than 60 ms: {result['short']}, "
        f"restarted: {result['restarted']}, not closed: {result['open']}",
    ]
    if result["edges"]:
        durations = [e["duration"] * 1000 for e in result["edges"]]
        same = sum(1 for e in result["edges"] if e["before"] == e["after"])
        lines.append(f"edge duration ms: min {min(durations):.1f}, avg {sum(durations) / len(durations):.1f}, "
                     f"max {max(durations):.1f}; same colour after the edge: {same}")
        for e in result["edges"]:
            lines.append(f"  {e['at']:.3f}s  {e['before']} -> black {e['duration'] * 1000:.1f} ms -> {e['after']}")
    verdict = "OK" if result["edges"] and result["short"] == 0 else "CHECK"
    if result["acknowledged"] == 0:
        verdict = "NO ACKNOWLEDGED CASTS" + (" (spell IDs secret)" if result["secret_casts"] else "")
    lines.append(f"verdict: {verdict}")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("path", nargs="?")
    args = parser.parse_args(argv)
    paths = [args.path] if args.path else glob.glob(DEFAULT_GLOB)
    if not paths:
        print("no ForeverOneButton.lua found; pass the path explicitly", file=sys.stderr)
        return 1
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            entries = read_entries(handle.read())
        print(f"== {os.path.basename(os.path.dirname(os.path.dirname(path)))}: {len(entries)} entries")
        print(report(summarize(entries)))
        print(timeline_report(timeline(entries)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

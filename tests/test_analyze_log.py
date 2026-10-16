"""scripts/analyze_log.py on a SavedVariables file shaped like the client's."""
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import analyze_log  # noqa: E402

SAMPLE = '''
ForeverOneButtonDB = {
["schema"] = 2,
}
ForeverOneButtonLog = {
["enabled"] = true,
["entries"] = {
"100.0000|session|0.2.0|1.60.1.70374",
"100.0000|combat|in",
"100.0010|pixel|3",
"100.5000|pixel|black",
"100.5000|cast|6603|1",
"100.5610|pixel|3",
"101.0000|pixel|black",
"101.0000|cast|6603|1",
"101.0300|pixel|3",
"101.2000|cast|secret|0",
"101.3000|cast|9999|0",
"101.5000|pixel|black",
"101.5000|cast|6603|1",
"101.6000|combat|out",
"102.0000|combat|in",
"102.1000|pixel|1|102.0900",
"102.2000|pixel|black|102.1900",
"102.2000|cast|6603|1",
"102.2300|pixel|black|102.2290",
"102.2300|cast|6603|1",
"102.2880|pixel|1|102.2900",
},
["version"] = 1,
}
'''


class AnalyzeLogTest(unittest.TestCase):
    def test_edges_and_counts(self):
        result = analyze_log.summarize(analyze_log.read_entries(SAMPLE))
        self.assertEqual(result["casts"], 7)
        self.assertEqual(result["secret_casts"], 1)
        self.assertEqual(result["acknowledged"], 5)
        self.assertEqual(len(result["edges"]), 3)
        self.assertAlmostEqual(result["edges"][0]["duration"], 0.061, places=4)
        self.assertEqual(result["edges"][0]["before"], "3")
        self.assertEqual(result["edges"][0]["after"], "3")
        self.assertEqual(result["short"], 1)  # the 30 ms edge
        self.assertEqual(result["open"], 1)   # ended by leaving combat
        # Frame times are used when present: 102.1900 -> 102.2900 is 100 ms
        # although the precise write times differ by 88 ms; the second cast
        # restarted the same edge.
        self.assertEqual(result["restarted"], 1)
        self.assertAlmostEqual(result["edges"][2]["duration"], 0.100, places=4)
        self.assertEqual(result["edges"][2]["before"], "1")
        self.assertIn("verdict: CHECK", analyze_log.report(result))

    def test_pixel_timeline(self):
        entries = [
            "1.000|pixel|3|1.000|spell 6603 Strike / SHIFT-3",
            "1.500|pixel|black|1.500",
            "1.560|pixel|3|1.560|spell 6603 Strike / SHIFT-3",
            "1.570|pixel|3|1.570|spell 6603 Strike / SHIFT-3",
            "1.800|pixel|white|1.800",
            "1.810|pixel|black|1.810",
        ]
        view = analyze_log.timeline(entries)
        self.assertEqual([s["state"] for s in view["segments"]], ["3", "black", "3", "white", "black"])
        self.assertEqual(view["cycles"], 3)
        self.assertEqual(len(view["short"]), 1)  # 10 ms white
        text = analyze_log.timeline_report(view)
        self.assertIn("slot 3", text)
        self.assertIn("Strike / SHIFT-3", text)
        self.assertIn("shorter than one 50 Hz sample", text)

    def test_no_log(self):
        self.assertEqual(analyze_log.read_entries("ForeverOneButtonDB = {}"), [])
        report = analyze_log.report(analyze_log.summarize([]))
        self.assertIn("NO ACKNOWLEDGED CASTS", report)


if __name__ == "__main__":
    unittest.main()

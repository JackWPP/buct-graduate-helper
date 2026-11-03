#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""只读课表快照：用已导出的样本，不访问学校。"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from timetable_pull import (  # noqa: E402
    FORBIDDEN_KEYS,
    apply_live_timetable,
    load_json,
    periods_from_meta,
)


class TimetablePullTest(unittest.TestCase):
    def test_live_snapshot_matches_exported_courses_and_drops_secrets(self):
        base = load_json(ROOT / "web/data/snapshot.json")
        selected = load_json(ROOT / "demo_output/selected_courses_55.json")
        plan = load_json(ROOT / "demo_output/training_plan.json")["pyjh"]
        meta = load_json(ROOT / "demo_output/selection_meta.json")
        # 样本里故意塞一个联系方式字段，确认不会进快照。
        selected = [dict(row) for row in selected]
        selected[0]["sjhm"] = "13800000000"
        selected[0]["email"] = "hidden@example.com"
        periods = periods_from_meta(meta)
        live = apply_live_timetable(
            base,
            selected=selected,
            plan=plan,
            term={"termcode": "55", "termname": "2026-2027秋季学期"},
            periods=periods,
            term_start="2026-08-31",
        )
        self.assertEqual(
            [(c["name"], c["room"], c["sjms"], c["category"]) for c in live["courses"]],
            [(c["name"], c["room"], c["sjms"], c["category"]) for c in base["courses"]],
        )
        self.assertEqual(live["credits"]["selected"], base["credits"]["selected"])
        self.assertEqual(live["term"]["start"], "2026-08-31")
        self.assertEqual(periods[0]["start"], "08:00")
        self.assertEqual(periods[0]["name"], "上午1")
        self.assertNotIn("selected", periods[0])
        self.assertEqual(live["notices"], [])
        self.assertEqual(live["exams"], [])
        blob = json.dumps(live, ensure_ascii=False)
        for key in FORBIDDEN_KEYS:
            self.assertNotIn('"%s"' % key, blob)
        self.assertNotIn("13800000000", blob)
        self.assertNotIn("hidden@example.com", blob)

    def test_login_does_not_take_a_password_argument(self):
        env = os.environ.copy()
        env.pop("GMIS_PASSWORD", None)
        env.pop("GMIS_USER", None)
        denied = subprocess.run(
            [sys.executable, str(ROOT / "gmis_cli.py"), "login", "--password", "secret"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(denied.returncode, 0)
        self.assertIn("password", denied.stderr.lower())
        missing = subprocess.run(
            [sys.executable, str(ROOT / "gmis_cli.py"), "login", "--user", "1"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            input="",
        )
        self.assertEqual(missing.returncode, 2)
        self.assertIn("GMIS_PASSWORD", missing.stderr)
        self.assertNotIn("secret", missing.stderr)

    def test_timetable_command_stops_without_cookies(self):
        env = os.environ.copy()
        env.pop("GMIS_PASSWORD", None)
        result = subprocess.run(
            [sys.executable, str(ROOT / "gmis_cli.py"), "--cookies", str(ROOT / "no-such-cookies.json"), "timetable"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("Cookie", result.stderr)
        self.assertFalse((ROOT / "web/data/live.json").exists())


if __name__ == "__main__":
    unittest.main()

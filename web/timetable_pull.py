#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 GMIS 只读课表收成网页快照。不写入密码、Cookie、验证码和联系方式。"""

from __future__ import annotations

import copy
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# 楼名只有首字。未识别的不猜测校区。
CAMPUS = {"教": "朝阳校区", "科": "朝阳校区"}

COURSE_KEYS = (
    "id", "name", "className", "code", "credits", "hours", "teacher", "room",
    "campus", "online", "ksz", "jsz", "pattern", "enrolled", "sjms", "category", "degree",
)

# 这些字段即使接口带回来，也不能进快照。
FORBIDDEN_KEYS = {
    "sfzh", "zjhm", "sfzjh", "sjhm", "jtdh", "jtdz", "lxdh", "email", "dzyx",
    "passwd", "password", "pwd", "cookie", "cookies", "vericode", "vericode",
    "yzm", "captcha",
}

SHANGHAI = timezone(timedelta(hours=8))


def campus_of(room: str) -> str | None:
    if not room or room == "网络课程":
        return None
    return CAMPUS.get(room[:1])


def course_from_row(raw: dict, plan_by_code: dict[str, dict]) -> dict:
    """已选课一行 -> 课表格子需要的学业字段。"""
    plan_item = plan_by_code.get(raw.get("kcbh") or "")
    room = raw.get("dz") or ""
    online = room == "网络课程" or raw.get("rkjsxm") == "网络课程"
    if plan_item:
        category = plan_item.get("kclbmc") or ""
        hours = plan_item.get("kczxs")
        degree = str(plan_item.get("xwk")) == "1"
    else:
        category = ""
        hours = None
        degree = False
    course = {
        "id": raw.get("bjid"),
        "name": raw.get("kcmc") or "",
        "className": raw.get("bjmc") or "",
        "code": raw.get("kcbh") or "",
        "credits": raw.get("kcxf") or 0,
        "hours": hours,
        "teacher": raw.get("rkjsxm") or "",
        "room": room,
        "campus": campus_of(room),
        "online": online,
        "ksz": raw.get("ksz"),
        "jsz": raw.get("jsz"),
        "pattern": raw.get("lxfs") or "连续周",
        "enrolled": raw.get("xkrs"),
        "sjms": raw.get("sjms") or "",
        "category": category,
        "degree": degree,
    }
    return {key: course[key] for key in COURSE_KEYS}


def periods_from_meta(meta: dict | None) -> list[dict]:
    """节次时间来自 xswsxk_kb_load.jc，不把接口里的 selected 等标记带进快照。"""
    rows = []
    for item in (meta or {}).get("jc") or []:
        name = str(item.get("mc") or "").strip()
        if not name or "btime" not in item or "etime" not in item:
            continue
        group = "晚上" if name.startswith("晚上") else "下午" if name.startswith("下午") else "上午"
        rows.append({
            "n": int(item.get("sortid") or len(rows) + 1),
            "name": name,
            "start": item["btime"],
            "end": item["etime"],
            "group": group,
        })
    rows.sort(key=lambda period: period["n"])
    return rows


def _recompute_credits(base: dict, courses: list[dict]) -> dict:
    credits = copy.deepcopy(base)
    keys = [item.get("key") for item in credits.get("categories") or []]
    got = {key: 0.0 for key in keys}
    orphans = []
    for course in courses:
        category = course.get("category") or ""
        amount = float(course.get("credits") or 0)
        if category in got:
            got[category] += amount
        else:
            orphans.append({
                "name": course.get("name"),
                "credits": course.get("credits"),
                "code": course.get("code"),
            })
    for item in credits.get("categories") or []:
        item["got"] = round(got.get(item.get("key"), 0.0), 1)
    credits["orphans"] = orphans
    credits["orphanCredits"] = round(sum(float(item["credits"] or 0) for item in orphans), 1)
    credits["selected"] = round(sum(float(course.get("credits") or 0) for course in courses), 1)
    return credits


def _contains_forbidden(value: Any) -> str | None:
    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).lower() in FORBIDDEN_KEYS:
                return str(key)
            found = _contains_forbidden(item)
            if found:
                return found
    elif isinstance(value, list):
        for item in value:
            found = _contains_forbidden(item)
            if found:
                return found
    return None


def apply_live_timetable(
    base: dict,
    *,
    selected: list[dict],
    plan: list[dict],
    term: dict,
    periods: list[dict],
    term_start: str,
    updated_at: datetime | None = None,
) -> dict:
    """用只读课表替换课程、学分合计、学期和节次。通知、考试保持原快照，不另编。"""
    plan_by_code = {item.get("kcbh"): item for item in plan if item.get("kcbh")}
    courses = [course_from_row(row, plan_by_code) for row in selected]
    moment = updated_at or datetime.now(SHANGHAI)
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=SHANGHAI)
    local = moment.astimezone(SHANGHAI)
    snapshot = copy.deepcopy(base)
    snapshot["updatedAt"] = local.isoformat(timespec="seconds")
    snapshot["updatedLabel"] = f"{local.month}月{local.day}日 {local:%H:%M}"
    snapshot["source"] = "GMIS 只读课表。浏览器只读本地 live.json，密码和 Cookie 不在这份文件里。"
    snapshot["term"] = {
        "code": str(term.get("termcode") or ""),
        "name": term.get("termname") or "",
        "start": term_start,
        "startLabel": f"第 1 周周一 {term_start}",
    }
    snapshot["courses"] = courses
    snapshot["credits"] = _recompute_credits(base.get("credits") or {}, courses)
    if periods:
        snapshot["periods"] = periods
    # 设计稿没画完的列表保持空，不用这次拉取去填。
    snapshot["notices"] = base.get("notices") or []
    snapshot["exams"] = base.get("exams") or []
    snapshot["adjustments"] = base.get("adjustments") or []
    found = _contains_forbidden(snapshot)
    if found:
        raise ValueError("快照含有不允许写入的字段: %s" % found)
    return snapshot


def load_json(path: str | Path) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_snapshot(path: str | Path, snapshot: dict) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

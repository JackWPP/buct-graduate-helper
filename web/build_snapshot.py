#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 demo_output 里的学业字段收成网页可用的快照。不写入证件号、电话、地址、邮箱和密码。"""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

from timetable_pull import course_from_row

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / "demo_output"
SAMPLES = ROOT / "samples"
OUT = Path(__file__).resolve().parent / "data" / "snapshot.json"

NATIVE = {
    "/student/pygl/xskbcx": "timetable",
    "/student/pygl/xscjcx": "grades",
    "/student/pygl/xswsxk_kb": "selected",
    "/student/pygl/xswsxk": "catalog",
    "/student/pygl/xkjgcx": "selected",
    "/student/pygl/qxkczml": "catalog",
    "/student/pygl/pyjhtj": "progress",
    "/student/pygl/wsjxpj": "eval",
    "/student/pygl/pyjhcx": "progress",
    "/student/pygl/pyfacx": "progress",
    "/student/pygl/kckccx": "exams",
    "/student/pygl/ttkcx": "exams",
    "/student/grgl/xsxx": "profile",
    "/student/grgl/xyjc": "progress",
}

CATEGORY_ORDER = ["A公共基础课", "B专业核心课", "I学科交叉课", "J前沿课程", "L五育融合课程"]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def app_status(item: dict) -> dict:
    steps = item.get("shlbz") or []
    if not steps:
        return {"label": "状态未知", "tone": "muted", "time": ""}
    first = steps[0]
    if first.get("shlmc") == "未提交":
        return {"label": "未提交", "tone": "amber", "time": ""}
    approved = [s for s in steps if str(s.get("shlzt")) == "1"]
    if approved:
        last = approved[-1]
        return {"label": f"{last.get('shlmc', '审核')}已通过", "tone": "ok", "time": last.get("shsj") or ""}
    return {"label": first.get("shlmc") or "进行中", "tone": "muted", "time": first.get("shsj") or ""}


def main() -> None:
    card = load(DEMO / "card.json")[0]
    plan = load(DEMO / "training_plan.json")["pyjh"]
    selected = load(DEMO / "selected_courses_55.json")
    grades = load(DEMO / "grades.json")["xftj"][0]
    evals = load(SAMPLES / "wsjxpjlist.json")
    apps = load(SAMPLES / "getxssqinfo.json")
    menu = load(DEMO / "menu.json")["menus"]
    terms = load(DEMO / "terms.json")

    by_code = {item["kcbh"]: item for item in plan}
    required = defaultdict(float)
    for item in plan:
        required[item["kclbmc"]] += float(item["kcxf"])

    got = defaultdict(float)
    orphans = []
    courses = []
    for raw in selected:
        course = course_from_row(raw, by_code)
        if course["category"]:
            got[course["category"]] += float(course["credits"])
        else:
            orphans.append({
                "name": course["name"],
                "credits": course["credits"],
                "code": course["code"],
            })
        courses.append(course)

    selection_courses = []
    for raw in selected:
        selection_courses.append({
            "id": raw.get("bjid") or "",
            "code": raw.get("kcbh") or "",
            "name": raw.get("kcmc") or "",
            "className": raw.get("bjmc") or "",
            "teacher": raw.get("rkjsxm") or "",
            "room": raw.get("dz") or "",
            "credits": float(raw.get("kcxf") or 0),
            "hours": int(raw.get("kczxs") or 0),
            "weeks": f"{raw.get('ksz') or ''}-{raw.get('jsz') or ''}",
            "sjms": raw.get("sjms") or "",
            "capacity": int(raw.get("rnrs") or raw.get("xkrs") or 0),
            "selected": True,
            "selectable": 1,
        })

    categories = []
    for key in CATEGORY_ORDER:
        need = round(required.get(key, 0), 1)
        have = round(got.get(key, 0), 1)
        categories.append({
            "key": key,
            "name": key[1:] if key[:1].isalpha() else key,
            "got": have,
            "need": need,
        })

    orphan_credits = round(sum(item["credits"] for item in orphans), 1)
    selected_credits = round(sum(c["credits"] for c in courses), 1)
    plan_credits = round(sum(required.values()), 1)

    evaluations = []
    for item in evals:
        evaluations.append({
            "name": item.get("kcmc"),
            "className": item.get("bjmc"),
            "teacher": item.get("jsxm"),
            "credits": item.get("kcxf"),
            "code": item.get("kcbh"),
            "rated": str(item.get("sfpj")) == "1",
            "open": str(item.get("yxpj")) == "1",
        })

    applications = []
    for item in apps:
        status = app_status(item)
        applications.append({
            "id": item.get("dm"),
            "name": item.get("mc"),
            "label": status["label"],
            "tone": status["tone"],
            "time": status["time"],
        })

    groups = []
    exam_group = None
    for group in menu:
        items = []
        for entry in group.get("menus") or []:
            if entry["menuid"] == "wskscp":
                exam_group = {
                    "id": "wsks",
                    "name": "网上考试",
                    "items": [{
                        "id": entry["menuid"],
                        "name": entry["menuname"],
                        "path": entry["url"],
                        "native": None,
                    }],
                }
                continue
            items.append({
                "id": entry["menuid"],
                "name": entry["menuname"],
                "path": entry["url"],
                "native": NATIVE.get(entry["url"]),
            })
        if items:
            groups.append({"id": group["menuid"], "name": group["menuname"], "items": items})
    if exam_group:
        groups.append(exam_group)

    current = next((t for t in terms if t.get("selected")), terms[0])
    snapshot = {
        "updatedAt": "2026-10-30T14:32:00+08:00",
        "updatedLabel": "10月30日 14:32",
        "source": "GMIS 导出快照，演示版不连接学校服务器",
        "student": {
            "xh": card["xh"],
            "xm": card["xm"],
            "college": card["xsmc"],
            "major": card["zymc"],
            "advisor": card["dsxm"],
            "grade": card["nj"],
            "kind": card["xslb"],
        },
        "term": {
            "code": current["termcode"],
            "name": current["termname"],
            "start": "2026-08-31",
            "startLabel": "第 1 周周一 2026-08-31",
        },
        "demoStudentId": card["xh"],
        "courses": courses,
        "selectionCourses": selection_courses,
        "credits": {
            "selected": selected_credits,
            "required": plan_credits,
            "categories": categories,
            "orphans": orphans,
            "orphanCredits": orphan_credits,
            "recorded": grades.get("zxf") or 0,
            "degreeRecorded": grades.get("xwxf") or 0,
            "nonDegreeRecorded": grades.get("fxwxf") or 0,
            "degreeRequired": grades.get("yxxwxf"),
            "nonDegreeRequired": grades.get("yxfxwxf"),
            "gpa": grades.get("zfgpa"),
            "degreeGpa": grades.get("xwkgpa"),
        },
        "evaluations": evaluations,
        "applications": applications,
        "notices": [],
        "exams": [],
        "adjustments": [],
        "services": groups,
        "campusNote": "教、科 暂按朝阳校区显示。地点没有校区字段，未识别的楼名只显示教室。",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    pending = sum(1 for e in evaluations if e["open"] and not e["rated"])
    print(f"courses={len(courses)} online={sum(c['online'] for c in courses)} credits={selected_credits}/{plan_credits} eval_pending={pending} apps={len(applications)}")


if __name__ == "__main__":
    main()

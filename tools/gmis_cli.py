#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GMIS 学生端命令行工具。

示例：
    python3 tools/gmis_cli.py login --user 2026201060 --cookies cookies.json
    python3 tools/gmis_cli.py dump --cookies cookies.json --out data/demo_output
    python3 tools/gmis_cli.py ics --cookies cookies.json --term 55 --start 2026-08-31 --out 课表.ics
    python3 tools/gmis_cli.py courses --cookies cookies.json --lb 3 --rows 20
    python3 tools/gmis_cli.py select --cookies cookies.json --bjid BID
"""
from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
import tempfile
import time
from pathlib import Path

from gmis_client import GmisClient, GmisError, build_ics


def _client(args) -> GmisClient:
    c = GmisClient(timeout=args.timeout)
    cookie_file = Path(args.cookies)
    if cookie_file.exists():
        c.load_cookies(cookie_file)
    return c


def _save(c: GmisClient, path: str) -> None:
    Path(path).write_text(json.dumps(c.s.cookies.get_dict(), ensure_ascii=False, indent=2), encoding="utf-8")
    print("cookies -> %s" % path)


def _solve_captcha(gif: bytes, name: str = "captcha") -> str:
    """验证码只用学校返回的图，看完就从临时目录删掉。"""
    fd, path = tempfile.mkstemp(prefix=name + "_", suffix=".gif")
    os.close(fd)
    gif_path = Path(path)
    gif_path.write_bytes(gif)
    shown = gif_path
    try:
        from PIL import Image
        png = gif_path.with_suffix(".png")
        Image.open(gif_path).convert("RGB").save(png)
        gif_path.unlink(missing_ok=True)
        shown = png
    except Exception:
        pass
    print("验证码图片: %s" % shown)
    try:
        return input("验证码: ").strip()
    finally:
        shown.unlink(missing_ok=True)


def _password() -> str:
    """密码只来自 GMIS_PASSWORD 或交互输入，不接受命令行参数。"""
    password = os.environ.get("GMIS_PASSWORD", "")
    if password:
        return password
    if not sys.stdin.isatty():
        raise GmisError("没有 GMIS_PASSWORD，当前也不是交互终端。不要把密码写进命令行。")
    password = getpass.getpass("密码: ")
    if not password:
        raise GmisError("密码为空。")
    return password


def cmd_login(args) -> int:
    user = args.user or os.environ.get("GMIS_USER", "")
    password = _password()
    if not user:
        if not sys.stdin.isatty():
            raise GmisError("没有学号。请传 --user，或设置 GMIS_USER。")
        user = input("学号: ").strip()
    c = GmisClient(timeout=args.timeout)
    body = c.login(lambda gif: _solve_captcha(gif, "stucode"), user, password)
    _save(c, args.cookies)
    print(json.dumps({"jg": body.get("jg"), "url": body.get("url")}, ensure_ascii=False))
    return 0


def cmd_dump(args) -> int:
    c = _client(args)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    term = args.term or c.terms()[0]["termcode"]
    payloads = {
        "card.json": c.card(),
        "menu.json": c.menu(),
        "terms.json": c.terms(),
        "colleges.json": c.colleges(),
        "profile.json": c.profile(),
        "training_plan.json": c.training_plan(),
        "grades.json": c.grades(),
        "timetable_%s.json" % term: c.timetable(term),
        "selected_courses_%s.json" % term: c.selected_courses(term),
        "selection_meta.json": c.selection_meta(),
        "selected_grid.json": c.selected_grid(),
        "notices.json": c.notices(rows=20),
        "exam_rooms.json": c.exam_rooms(),
    }
    for name, data in payloads.items():
        (out / name).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print("%-28s %s" % (name, type(data).__name__))
    return 0


def cmd_ics(args) -> int:
    c = _client(args)
    term = args.term or c.terms()[0]["termcode"]
    courses = c.selected_courses(term)
    text = build_ics(courses, term_start=args.start, calendar_name=args.name)
    Path(args.out).write_text(text, encoding="utf-8")
    print("%s 门课 -> %s" % (len(courses), args.out))
    return 0


def cmd_courses(args) -> int:
    c = _client(args)
    data = c.course_list(lb=args.lb, page=args.page, rows=args.rows,
                         only_in_window=(args.type == "2"), xwk=args.xwk, zh=args.zh,
                         yxsh=args.yxsh, kcbh=args.kcbh)
    print("total=%s shown=%s" % (data.get("total") or len(data.get("kc", [])), len(data.get("kc", []))))
    for row in data.get("kc", []):
        print("%-12s %-26s %-10s %-8s %s" % (
            row.get("kcbh", ""), row.get("kcmc", ""), row.get("xsmc", ""),
            row.get("kcxf", ""), row.get("rkjsxm", "")))
    return 0


def cmd_select(args) -> int:
    c = _client(args)
    gif = c.get_captcha("xkyzm")
    code = _solve_captcha(gif, "xkyzm")
    result = c.select_course(args.bjid, code)
    print(json.dumps(result, ensure_ascii=False))
    return 0


def cmd_timetable(args) -> int:
    cookie_file = Path(args.cookies)
    if not cookie_file.exists():
        raise GmisError("还没有本地 Cookie。先运行 login。密码用 GMIS_PASSWORD 或交互输入，成功后的 Cookie 留在 %s。" % cookie_file)
    c = _client(args)
    sys.path.insert(0, str(Path(__file__).resolve().parent / "web"))
    from timetable_pull import apply_live_timetable, load_json, periods_from_meta, write_snapshot

    base_path = Path(args.base)
    base = load_json(base_path)
    terms = c.terms()
    if not terms:
        raise GmisError("学校没有返回学期。")
    current = next((item for item in terms if item.get("selected")), terms[0])
    code = args.term or str(current.get("termcode") or "")
    term = next((item for item in terms if str(item.get("termcode")) == code), current)
    selected = c.selected_courses(code)
    plan_body = c.training_plan()
    plan = plan_body.get("pyjh") if isinstance(plan_body, dict) else []
    periods = periods_from_meta(c.selection_meta())
    start = args.start or (base.get("term") or {}).get("start") or ""
    if not start:
        raise GmisError("快照里没有开学日。请用 --start YYYY-MM-DD 指定第 1 周周一。")
    live = apply_live_timetable(
        base,
        selected=selected,
        plan=plan or [],
        term=term,
        periods=periods,
        term_start=start,
    )
    write_snapshot(args.out, live)
    print("courses=%s periods=%s -> %s" % (len(live["courses"]), len(live.get("periods") or []), args.out))
    return 0


def cmd_drop(args) -> int:
    c = _client(args)
    gif = c.get_captcha("xkyzm")
    code = _solve_captcha(gif, "xkyzm")
    result = c.drop_course(args.bjid, code)
    print(json.dumps(result, ensure_ascii=False))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="GMIS 学生端命令行工具")
    p.add_argument("--cookies", default="cookies.json", help="cookie JSON 文件")
    p.add_argument("--timeout", type=int, default=30)
    sub = p.add_subparsers(dest="cmd", required=True)

    q = sub.add_parser("login", help="验证码用学校返回的图。密码只读 GMIS_PASSWORD 或交互输入")
    q.add_argument("--user", default="")
    q.set_defaults(func=cmd_login)

    q = sub.add_parser("dump")
    q.add_argument("--term", default="")
    q.add_argument("--out", default="data/demo_output")
    q.set_defaults(func=cmd_dump)

    q = sub.add_parser("ics")
    q.add_argument("--term", default="")
    q.add_argument("--start", required=True, help="第1周周一，YYYY-MM-DD")
    q.add_argument("--out", default="课表.ics")
    q.add_argument("--name", default="GMIS 课表")
    q.set_defaults(func=cmd_ics)

    q = sub.add_parser("courses")
    q.add_argument("--lb", default="3", help="1公共课 2专业课 3全部")
    q.add_argument("--type", default="1", help="1全部 2仅选课时间内")
    q.add_argument("--xwk", default="", help="1学位课 0非学位课")
    q.add_argument("--zh", default="", help="星期 1-7")
    q.add_argument("--yxsh", default="", help="院系代码")
    q.add_argument("--kcbh", default="", help="课程编号或名称")
    q.add_argument("--page", type=int, default=1)
    q.add_argument("--rows", type=int, default=20)
    q.set_defaults(func=cmd_courses)

    q = sub.add_parser("select")
    q.add_argument("--bjid", required=True, help="班级 id")
    q.set_defaults(func=cmd_select)

    q = sub.add_parser("drop")
    q.add_argument("--bjid", required=True, help="班级 id")
    q.set_defaults(func=cmd_drop)

    q = sub.add_parser("timetable", help="用本地 Cookie 拉只读课表，写成不提交的 live.json")
    q.add_argument("--term", default="")
    q.add_argument("--start", default="", help="第 1 周周一 YYYY-MM-DD，默认沿用快照里的开学日")
    q.add_argument("--base", default="web/data/snapshot.json")
    q.add_argument("--out", default="web/data/live.json")
    q.set_defaults(func=cmd_timetable)

    args = p.parse_args()
    try:
        return args.func(args)
    except GmisError as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

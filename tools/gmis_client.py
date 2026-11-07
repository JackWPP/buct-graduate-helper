#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
北京化工大学研究生管理系统（GMIS 5.0）学生端 API 客户端。

依赖：requests、cryptography
可选：Pillow（命令行登录时把验证码 GIF 转成 PNG 方便查看）

用法：
    from gmis_client import GmisClient
    c = GmisClient()
    c.login(captcha_solver=lambda gif: input("验证码: "))
    print(c.card())
    print(c.timetable("55"))
"""
from __future__ import annotations

import base64
import getpass
import hashlib
import json
import os
import re
import tempfile
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable, Dict, Iterable, List, Optional, Sequence, Tuple

import requests
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

BASE = "https://gmis.buct.edu.cn"
DEFAULT_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0 Safari/537.36"
)
PERIOD_NAMES = ["上午1", "上午2", "上午3", "上午4", "上午5",
                "下午6", "下午7", "下午8", "下午9",
                "晚上10", "晚上11", "晚上12"]
DEFAULT_PERIOD_MAP = {
    "上午1": ("08:00", "08:45"), "上午2": ("08:50", "09:35"),
    "上午3": ("09:45", "10:30"), "上午4": ("10:40", "11:25"),
    "上午5": ("11:30", "12:15"), "下午6": ("13:30", "14:15"),
    "下午7": ("14:20", "15:05"), "下午8": ("15:15", "16:00"),
    "下午9": ("16:05", "16:50"), "晚上10": ("18:00", "18:45"),
    "晚上11": ("18:50", "19:35"), "晚上12": ("19:40", "20:25"),
}
WEEKDAY_INDEX = {"一": 0, "二": 1, "三": 2, "四": 3, "五": 4, "六": 5, "日": 6, "天": 6}
WEEKDAY_NAME = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]


class GmisError(Exception):
    """GMIS 通用异常。"""


class GmisAuthError(GmisError):
    """未登录、登录失效、动态 RSA 公钥不匹配。"""


class GmisApiError(GmisError):
    """接口返回非 JSON 或业务错误。"""


class GmisClient:
    """一个学生账号对应一个 GmisClient；内部持有 requests.Session。"""

    def __init__(self, base: str = BASE, timeout: int = 30, user_agent: str = DEFAULT_UA):
        self.base = base.rstrip("/")
        self.timeout = timeout
        self.s = requests.Session()
        self.s.trust_env = False
        self.s.verify = True
        self.s.headers.update({
            "User-Agent": user_agent,
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "X-Requested-With": "XMLHttpRequest",
            "Referer": self.base + "/home/stulogin",
        })

    # ---------- 基础请求 ----------
    def _url(self, path: str) -> str:
        if path.startswith("http://") or path.startswith("https://"):
            return path
        return self.base + "/" + path.lstrip("/")

    def request(self, method: str, path: str, *, allow_redirects: bool = False, **kwargs) -> requests.Response:
        kwargs.setdefault("timeout", self.timeout)
        r = self.s.request(method.upper(), self._url(path), allow_redirects=allow_redirects, **kwargs)
        if r.status_code in (301, 302, 303, 307, 308):
            loc = r.headers.get("Location", "")
            if "/home/stulogin" in loc or "stulogin" in loc:
                raise GmisAuthError("登录态已失效，请重新登录")
            raise GmisApiError("接口发生跳转: %s -> %s" % (path, loc))
        if r.status_code >= 500 and "block incorrect" in (r.text or ""):
            raise GmisAuthError("RSA 公钥与服务器不匹配：必须从当前 /home/stulogin 页面读取 #pubkey")
        if r.status_code >= 400:
            raise GmisApiError("HTTP %s %s: %s" % (r.status_code, path, (r.text or "")[:300]))
        return r

    def get_json(self, path: str, params: Optional[dict] = None) -> Any:
        r = self.request("GET", path, params=params)
        try:
            return r.json()
        except ValueError as exc:
            raise GmisApiError("返回不是 JSON: %s %s" % (path, (r.text or "")[:300])) from exc

    def post_json(self, path: str, data: Optional[dict] = None) -> Any:
        r = self.request("POST", path, data=data or {})
        try:
            return r.json()
        except ValueError as exc:
            raise GmisApiError("返回不是 JSON: %s %s" % (path, (r.text or "")[:300])) from exc

    # ---------- 登录 ----------
    def get_captcha(self, codetype: str = "stucode") -> bytes:
        r = self.request("GET", "/home/verificationcode",
                         params={"codetype": codetype, "t": str(int(time.time() * 1000))})
        return r.content

    def login(self, captcha_solver: Callable[[bytes], str], user_id: str, password: str) -> dict:
        """完整学生端登录。

        captcha_solver 接收验证码 GIF 的 bytes，返回 4 位验证码字符串。
        """
        self.s.cookies.clear()
        r = self.s.get(self._url("/home/stulogin"), timeout=self.timeout, allow_redirects=True)
        if r.status_code != 200:
            raise GmisAuthError("打开登录页失败: HTTP %s" % r.status_code)
        m = re.search(r'id="pubkey"\s+type="hidden"\s+value=\'(.*?)\'', r.text, re.S)
        if not m:
            raise GmisAuthError("登录页未找到 #pubkey")
        pubkey_pem = m.group(1).strip()
        captcha = self.get_captcha("stucode")
        code = (captcha_solver(captcha) or "").strip()
        if not code:
            raise GmisAuthError("验证码为空")
        key = serialization.load_pem_public_key(pubkey_pem.encode("utf-8"))
        encrypted = key.encrypt(password.encode("utf-8"), padding.PKCS1v15())
        info = {
            "UserId": user_id,
            "Password": base64.b64encode(encrypted).decode("ascii"),
            "VeriCode": code,
            "url": "",
            "city": "",
        }
        r = self.s.post(
            self._url("/home/stulogin_do"),
            data={"json": json.dumps(info, ensure_ascii=False, separators=(",", ":"))},
            timeout=self.timeout,
            allow_redirects=True,
        )
        if r.status_code >= 500 and "block incorrect" in (r.text or ""):
            raise GmisAuthError("RSA block incorrect：请确认 #pubkey 来自本次登录页")
        try:
            body = r.json()
        except ValueError:
            raise GmisApiError("登录返回非 JSON: %s" % (r.text or "")[:300])
        if str(body.get("jg")) != "1":
            raise GmisAuthError("登录失败: %s" % body.get("msg", body))
        self.s.get(self._url("/" + body.get("url", "student/default/index")), timeout=self.timeout)
        return body

    def logout(self) -> None:
        try:
            self.request("GET", "/home/logout", params={"js": "xs"}, allow_redirects=True)
        finally:
            self.s.cookies.clear()

    # ---------- Cookie 持久化 ----------
    def save_cookies(self, path: str | Path) -> None:
        Path(path).write_text(json.dumps(self.s.cookies.get_dict(), ensure_ascii=False, indent=2), encoding="utf-8")

    def load_cookies(self, path: str | Path) -> None:
        self.s.cookies.update(json.loads(Path(path).read_text(encoding="utf-8")))

    # ---------- 首页 / 公共数据 ----------
    def menu(self) -> dict:
        return self.get_json("/student/default/MenuleftInfo", params={"_": str(int(time.time() * 1000))})

    def card(self) -> list:
        return self.get_json("/student/default/getxscardinfo")

    def terms(self) -> list:
        return self.get_json("/student/default/bindterm")

    def colleges(self) -> list:
        return self.get_json("/student/default/bindyxsh")

    def home_data(self) -> dict:
        return self.post_json("/student/default/gethomepagesw")

    def home_position(self) -> dict:
        return self.post_json("/student/default/index_position", {"p": "/student/default/home"})

    def unread_notices(self) -> list:
        return self.post_json("/student/default/getUnReadTzxx")

    def fee_status(self, kind: str = "xfqk") -> Any:
        return self.get_json("/student/default/getxfwcqk", {"type": kind})

    def notices(self, page: int = 1, rows: int = 20, title: str = "",
                start: str = "", end: str = "") -> dict:
        return self.get_json("/student/grgl/tzgg_list", {
            "ksrq": start, "jsrq": end, "bt": title, "page": page, "rows": rows,
        })

    # ---------- 个人管理 ----------
    def profile(self) -> dict:
        return self.get_json("/student/grgl/xsxx_jbxx")

    def education_history(self) -> Any:
        return self.post_json("/student/grgl/xsxx_jcjl", {})

    def research_papers(self) -> Any:
        return self.post_json("/student/grgl/xsxx_kylw", {})

    def research_projects(self) -> Any:
        return self.post_json("/student/grgl/xsxx_ktzq", {})

    def rewards(self) -> Any:
        return self.get_json("/student/grgl/xsxx_byxw")

    def registration_status(self) -> Any:
        return self.post_json("/student/grgl/getzcxx", {})

    def register_term(self) -> Any:
        return self.post_json("/student/grgl/xszcaction", {})

    def address_change_load(self) -> Any:
        return self.post_json("/student/grgl/ccqjwh_load", {})

    def address_change_save(self, ccqj: str) -> Any:
        return self.post_json("/student/grgl/ccqjwh_save", {"ccqj": ccqj})

    def exam_signup_list(self) -> Any:
        return self.get_json("/student/grgl/djksbm_list")

    def exam_signup_records(self) -> Any:
        return self.get_json("/student/grgl/getbmrecorder")

    def exam_scores(self) -> Any:
        return self.post_json("/student/grgl/djkscjcx", {})

    # ---------- 培养管理 ----------
    def training_plan(self) -> dict:
        return self.post_json("/student/pygl/pyjhcxlist", {})

    def training_plan_options(self) -> dict:
        return self.get_json("/student/pygl/pyjhtj_drop")

    def training_plan_draft(self, pyfx: str = "") -> dict:
        return self.post_json("/student/pygl/pyjhtjlist", {"pyfx": pyfx})

    def grades(self) -> dict:
        return self.post_json("/student/pygl/xscjcx_list", {})

    def timetable(self, termcode: str) -> dict:
        """学生课表网格，rows 为 13 行 jcid/mc/z1..z7。"""
        return self.post_json("/student/pygl/py_kbcx_ew", {"kblx": "xs", "termcode": termcode})

    def selected_courses(self, termcode: str) -> list:
        """选课结果（逐门课程，不是网格）。"""
        return self.post_json("/student/pygl/py_kbcx_yw", {"termcode": termcode})

    def selection_meta(self) -> dict:
        return self.post_json("/student/pygl/xswsxk_kb_load", {})

    def selected_grid(self) -> dict:
        return self.post_json("/student/pygl/xswsxk_kb_loadkb", {})

    def course_list(self, lb: str = "3", xwk: str = "", zh: str = "", jc1: str = "",
                    jc2: str = "", yxsh: str = "", kcbh: str = "", page: int = 1,
                    rows: int = 100, only_in_window: bool = False) -> dict:
        """选课列表。

        lb: 1=公共课, 2=专业课, 3=全部
        xwk: 1=学位课, 0=非学位课, ""=全部
        zh: 星期一=1 ... 星期日=7
        jc1/jc2: 节次 id，来自 selection_meta()['jc']
        type: 1=全部可选, 2=仅选课时间内
        """
        return self.post_json("/student/pygl/xswsxk_kb_list", {
            "lb": lb, "xwk": xwk, "zh": zh, "jc1": jc1, "jc2": jc2,
            "yxsh": yxsh, "kcbh": kcbh, "page": page, "rows": rows,
            "type": "2" if only_in_window else "1",
        })

    def course_catalog(self, yxsh: str = "", kcbh: str = "", page: int = 1, rows: int = 100) -> dict:
        """课程开课一览（全校课程目录）。"""
        return self.post_json("/student/pygl/xswsxk_all", {
            "yxsh": yxsh, "kcbh": kcbh, "page": page, "rows": rows,
        })

    def select_course(self, bjid: str, xkyzm: str) -> dict:
        return self.post_json("/student/pygl/xswsxk_kb_xk", {"lb": "1", "bjid": bjid, "xkyzm": xkyzm})

    def drop_course(self, bjid: str, xkyzm: str = "") -> dict:
        return self.post_json("/student/pygl/xswsxk_kb_xk", {"lb": "0", "bjid": bjid, "xkyzm": xkyzm})

    def course_adjustments(self, page: int = 1, rows: int = 50) -> list:
        return self.post_json("/student/pygl/ttkcx_list", {"page": page, "rows": rows})

    def exam_rooms(self) -> Any:
        return self.post_json("/student/pygl/kckccx_list", {})

    def teaching_evaluation(self) -> list:
        return self.post_json("/student/pygl/wsjxpjlist")

    def retake_apply_list(self) -> dict:
        return self.get_json("/student/pygl/cxhkbksq_list")

    def retake_apply_records(self) -> Any:
        return self.get_json("/student/pygl/cxhkbksq_sqjl")

    # ---------- 研工 / 科研 / 考试（页面直取） ----------
    def financial_aid(self) -> list:
        return self.get_json("/student/yggl/pypgsq_list")

    def financial_aid_records(self) -> list:
        return self.get_json("/student/yggl/pypgsq_sqlist")

    def temporary_dorm(self) -> list:
        return self.get_json("/student/yggl/szgwsq_list")

    def temporary_dorm_records(self) -> list:
        return self.get_json("/student/yggl/szgwsq_sqlist")

    def academic_exchange(self) -> list:
        return self.get_json("/student/pygl/gjxsjlhd_load")

    def practice_plan(self) -> Any:
        return self.get_json("/student/pygl/zysjwc_load", params={"id": "0", "xh": self.card()[0].get("xh", "")})

    def thesis_list(self) -> Any:
        return self.post_json("/student/bygl/xwlwdjlist", {})

    def research_project_list(self) -> Any:
        return self.post_json("/student/bygl/xskyxmdj_list", {})

    def special_grant_list(self) -> Any:
        return self.post_json("/student/bygl/zlcglist", {})

    def honors_list(self) -> Any:
        return self.post_json("/student/bygl/hjqklist", {})

    def online_exam_list(self) -> list:
        return self.get_json("/student/wsks/wskscp_list")

    def online_exam_load(self) -> list:
        return self.get_json("/student/wsks/wskscp_load")

    def consultation(self) -> Any:
        return self.get_json("/student/grgl/zixun_load")

    # ---------- 通用分页 ----------
    @staticmethod
    def paged_rows(result: Any) -> List[dict]:
        if isinstance(result, list):
            return result
        if isinstance(result, dict):
            for key in ("rows", "kc", "pyjh", "pyfakc"):
                if isinstance(result.get(key), list):
                    return result[key]
        return []


def console_captcha_solver(gif_bytes: bytes) -> str:
    """把验证码 GIF 存成 PNG 并让人工输入；适合本地 CLI。"""
    try:
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(gif_bytes)).convert("RGB")
        path = Path(tempfile.gettempdir()) / "gmis_captcha.png"
        img.save(path)
        print("验证码图片: %s" % path)
    except Exception:
        path = Path(tempfile.gettempdir()) / "gmis_captcha.gif"
        path.write_bytes(gif_bytes)
        print("验证码图片: %s" % path)
    return input("请输入验证码: ").strip()


# ---------- 课表 -> ICS ----------
def parse_sjms(sjms: str) -> List[Tuple[int, str, str]]:
    """把 '星期二 上午1 -上午2,星期六 上午3-上午5' 解析成 [(weekday_index, start_period, end_period)]。"""
    out: List[Tuple[int, str, str]] = []
    text = (sjms or "").replace("，", ",")
    for seg in text.split(","):
        seg = seg.strip()
        if not seg:
            continue
        m = re.search(r"星期([一二三四五六日天])\s*(上午|下午|晚上)\s*(\d+)\s*[-~至]\s*(上午|下午|晚上)\s*(\d+)", seg)
        if not m:
            continue
        wd = WEEKDAY_INDEX[m.group(1)]
        start = ("%s%s" % (m.group(2), m.group(3))).strip()
        end = ("%s%s" % (m.group(4), m.group(5))).strip()
        out.append((wd, start, end))
    return out


def course_weeks(course: dict) -> List[int]:
    ksz, jsz = int(course.get("ksz", 0)), int(course.get("jsz", 0))
    if ksz <= 0 or jsz < ksz:
        return []
    weeks = list(range(ksz, jsz + 1))
    lx = (course.get("lxfs") or "").replace(" ", "")
    if "单周" in lx:
        return [w for w in weeks if w % 2 == 1]
    if "双周" in lx:
        return [w for w in weeks if w % 2 == 0]
    return weeks


def build_ics(courses: Sequence[dict], term_start: str, period_map: Optional[Dict[str, Tuple[str, str]]] = None,
              calendar_name: str = "GMIS 课表") -> str:
    """courses 来自 selected_courses()；term_start 为第 1 周周一（YYYY-MM-DD）。"""
    start0 = date.fromisoformat(term_start)
    period_map = period_map or DEFAULT_PERIOD_MAP
    lines: List[str] = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//GMIS BUCT//Timetable//CN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "X-WR-CALNAME:" + _ics_escape(calendar_name),
        "X-WR-TIMEZONE:Asia/Shanghai",
        "BEGIN:VTIMEZONE",
        "TZID:Asia/Shanghai",
        "BEGIN:STANDARD",
        "DTSTART:19700101T000000",
        "TZOFFSETFROM:+0800",
        "TZOFFSETTO:+0800",
        "TZNAME:CST",
        "END:STANDARD",
        "END:VTIMEZONE",
    ]
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for course in courses:
        sjms = course.get("sjms", "")
        segments = parse_sjms(sjms)
        if not segments:
            continue
        for wd, start_p, end_p in segments:
            if start_p not in period_map or end_p not in period_map:
                continue
            start_time = period_map[start_p][0]
            end_time = period_map[end_p][1]
            weeks = course_weeks(course)
            if not weeks:
                continue
            first = weeks[0]
            day = start0 + timedelta(days=(first - 1) * 7 + wd)
            dtstart = "%04d%02d%02dT%s00" % (day.year, day.month, day.day,
                                             start_time.replace(":", ""))
            dtend = "%04d%02d%02dT%s00" % (day.year, day.month, day.day,
                                           end_time.replace(":", ""))
            interval = 2 if ("单周" in (course.get("lxfs") or "") or "双周" in (course.get("lxfs") or "")) else 1
            uid_src = "%s|%s|%s|%s|%s" % (course.get("kcbh", ""), course.get("bjmc", ""),
                                          sjms, course.get("ksz", ""), course.get("jsz", ""))
            uid = hashlib.sha1(uid_src.encode("utf-8")).hexdigest() + "@gmis.buct.edu.cn"
            desc = "教师: %s\n地点: %s\n周次: %s-%s周\n节次: %s" % (
                course.get("rkjsxm", ""), course.get("dz", ""),
                course.get("ksz", ""), course.get("jsz", ""), sjms)
            lines.extend([
                "BEGIN:VEVENT",
                "UID:" + uid,
                "DTSTAMP:" + stamp,
                "DTSTART;TZID=Asia/Shanghai:" + dtstart,
                "DTEND;TZID=Asia/Shanghai:" + dtend,
                "SUMMARY:" + _ics_escape(course.get("kcmc", "")),
                "LOCATION:" + _ics_escape(course.get("dz", "")),
                "DESCRIPTION:" + _ics_escape(desc),
                "RRULE:FREQ=WEEKLY;INTERVAL=%d;COUNT=%d" % (interval, len(weeks)),
                "END:VEVENT",
            ])
    lines.append("END:VCALENDAR")
    return "\r\n".join(lines) + "\r\n"


def _ics_escape(value: str) -> str:
    return str(value).replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")


def period_map_from_meta(meta: dict) -> Dict[str, Tuple[str, str]]:
    out: Dict[str, Tuple[str, str]] = {}
    for item in meta.get("jc", []):
        out[item["mc"].strip()] = (item["btime"], item["etime"])
    return out


__all__ = [
    "GmisClient", "GmisError", "GmisAuthError", "GmisApiError",
    "console_captcha_solver", "parse_sjms", "course_weeks", "build_ics",
    "period_map_from_meta",
]

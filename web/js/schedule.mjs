/** 课表纯函数：周次、节次、网格、ICS。节次时间与 gmis_client.DEFAULT_PERIOD_MAP 一致。 */

export const PERIODS = [
  { n: 1, name: "上午1", start: "08:00", end: "08:45", group: "上午" },
  { n: 2, name: "上午2", start: "08:50", end: "09:35", group: "上午" },
  { n: 3, name: "上午3", start: "09:45", end: "10:30", group: "上午" },
  { n: 4, name: "上午4", start: "10:40", end: "11:25", group: "上午" },
  { n: 5, name: "上午5", start: "11:30", end: "12:15", group: "上午" },
  { n: 6, name: "下午6", start: "13:30", end: "14:15", group: "下午" },
  { n: 7, name: "下午7", start: "14:20", end: "15:05", group: "下午" },
  { n: 8, name: "下午8", start: "15:15", end: "16:00", group: "下午" },
  { n: 9, name: "下午9", start: "16:05", end: "16:50", group: "下午" },
  { n: 10, name: "晚上10", start: "18:00", end: "18:45", group: "晚上" },
  { n: 11, name: "晚上11", start: "18:50", end: "19:35", group: "晚上" },
  { n: 12, name: "晚上12", start: "19:40", end: "20:25", group: "晚上" },
];

const PERIOD_BY_NAME = Object.fromEntries(PERIODS.map((p) => [p.name, p]));
const WEEKDAY = { 一: 0, 二: 1, 三: 2, 四: 3, 五: 4, 六: 5, 日: 6, 天: 6 };
export const WEEKDAY_LABEL = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];

export function parseISODate(value) {
  const [y, m, d] = value.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function formatISODate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

/** 第 1 周周一为 termStart。返回值可以小于 1 或大于学期长度。 */
export function weekIndex(date, termStart) {
  const start = parseISODate(termStart);
  const days = Math.round((startOfDay(date) - start) / 86400000);
  return Math.floor(days / 7) + 1;
}

export function weekMonday(week, termStart) {
  const start = parseISODate(termStart);
  const day = new Date(start);
  day.setDate(start.getDate() + (week - 1) * 7);
  return day;
}

export function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

export function formatMonthDay(date) {
  return `${date.getMonth() + 1}月${date.getDate()}日`;
}

export function courseWeeks(course) {
  const ksz = Number(course.ksz);
  const jsz = Number(course.jsz);
  if (!ksz || jsz < ksz) return [];
  const weeks = [];
  for (let w = ksz; w <= jsz; w += 1) weeks.push(w);
  const pattern = String(course.pattern || "").replace(/\s/g, "");
  if (pattern.includes("单周")) return weeks.filter((w) => w % 2 === 1);
  if (pattern.includes("双周")) return weeks.filter((w) => w % 2 === 0);
  return weeks;
}

export function parseSjms(sjms) {
  const out = [];
  const text = String(sjms || "").replace(/，/g, ",");
  const re = /星期([一二三四五六日天])\s*(上午|下午|晚上)\s*(\d+)\s*[-~至]\s*(上午|下午|晚上)\s*(\d+)/g;
  let match = re.exec(text);
  while (match) {
    const startName = `${match[2]}${match[3]}`;
    const endName = `${match[4]}${match[5]}`;
    const start = PERIOD_BY_NAME[startName];
    const end = PERIOD_BY_NAME[endName];
    if (start && end) {
      out.push({
        weekday: WEEKDAY[match[1]],
        startName,
        endName,
        startPeriod: start.n,
        endPeriod: end.n,
        startTime: start.start,
        endTime: end.end,
      });
    }
    match = re.exec(text);
  }
  return out;
}

export function decorateCourse(course) {
  return {
    ...course,
    weeks: courseWeeks(course),
    segments: parseSjms(course.sjms),
  };
}

/** 周日整学期都没有线下课则隐藏该列。周四即使为空也保留。 */
export function visibleWeekdays(courses) {
  const used = new Set();
  for (const course of courses) {
    if (course.online) continue;
    for (const seg of course.segments || []) used.add(seg.weekday);
  }
  return [0, 1, 2, 3, 4, 5, 6].filter((day) => day !== 6 || used.has(6));
}

export function blocksForWeek(courses, week, showOffWeek = false) {
  const blocks = [];
  for (const course of courses) {
    if (course.online) continue;
    const active = (course.weeks || []).includes(week);
    if (!active && !showOffWeek) continue;
    for (const seg of course.segments || []) {
      blocks.push({
        id: `${course.id}-${seg.weekday}-${seg.startPeriod}`,
        courseId: course.id,
        name: course.name,
        room: course.room,
        weekday: seg.weekday,
        startPeriod: seg.startPeriod,
        endPeriod: seg.endPeriod,
        startTime: seg.startTime,
        endTime: seg.endTime,
        active,
      });
    }
  }
  return blocks;
}

export function sessionsOn(courses, date, termStart) {
  const week = weekIndex(date, termStart);
  const weekday = (date.getDay() + 6) % 7;
  const items = [];
  for (const course of courses) {
    if (course.online) continue;
    if (!(course.weeks || []).includes(week)) continue;
    for (const seg of course.segments || []) {
      if (seg.weekday !== weekday) continue;
      items.push({
        course,
        seg,
        startMin: toMinutes(seg.startTime),
        endMin: toMinutes(seg.endTime),
      });
    }
  }
  items.sort((a, b) => a.startMin - b.startMin);
  return { week, weekday, items };
}

export function pickHero(items, now) {
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const ongoing = items.find((item) => nowMin >= item.startMin && nowMin < item.endMin);
  if (ongoing) return { kind: "ongoing", item: ongoing, minutes: itemRemain(ongoing, nowMin) };
  const next = items.find((item) => item.startMin > nowMin);
  if (next) return { kind: "next", item: next, minutes: next.startMin - nowMin };
  if (items.length) return { kind: "done", item: items[items.length - 1], minutes: 0 };
  return { kind: "empty", item: null, minutes: 0 };
}

function itemRemain(item, nowMin) {
  return Math.max(item.endMin - nowMin, 0);
}

export function toMinutes(hhmm) {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
}

export function formatDuration(minutes) {
  const value = Math.max(0, Math.round(minutes));
  if (value < 60) return `${value} 分钟`;
  const h = Math.floor(value / 60);
  const m = value % 60;
  return m ? `${h} 小时 ${m} 分钟` : `${h} 小时`;
}

export function weekProgress(course, week) {
  const weeks = course.weeks || [];
  if (!weeks.length) return { done: 0, total: 0, remain: 0, phase: "empty" };
  const total = weeks.length;
  const first = weeks[0];
  const last = weeks[weeks.length - 1];
  if (week < first) return { done: 0, total, remain: total, phase: "upcoming" };
  if (week > last) return { done: total, total, remain: 0, phase: "ended" };
  const done = weeks.filter((w) => w <= week).length;
  return { done, total, remain: last - week, phase: "current" };
}

function icsEscape(value) {
  return String(value ?? "").replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");
}

function pad(n) {
  return String(n).padStart(2, "0");
}

function icsStamp(date) {
  return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`;
}

/** 只导出线下课。线上课的节次是占位，写进日历会把周五下午填满。 */
export function buildIcs(courses, termStart, calendarName = "化研助手课表") {
  const start0 = parseISODate(termStart);
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//BUCT Graduate Helper//Timetable//CN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${icsEscape(calendarName)}`,
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
  ];
  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
  for (const course of courses) {
    if (course.online) continue;
    const weeks = course.weeks || [];
    if (!weeks.length) continue;
    const odd = String(course.pattern || "").includes("单周") || String(course.pattern || "").includes("双周");
    for (const seg of course.segments || []) {
      const first = weeks[0];
      const day = addDays(start0, (first - 1) * 7 + seg.weekday);
      const ymd = icsStamp(day);
      const start = seg.startTime.replace(":", "");
      const end = seg.endTime.replace(":", "");
      lines.push(
        "BEGIN:VEVENT",
        `UID:${course.id}-${seg.weekday}-${seg.startPeriod}@buct-graduate-helper`,
        `DTSTAMP:${stamp}`,
        `DTSTART;TZID=Asia/Shanghai:${ymd}T${start}00`,
        `DTEND;TZID=Asia/Shanghai:${ymd}T${end}00`,
        `SUMMARY:${icsEscape(course.name)}`,
        `LOCATION:${icsEscape([course.room, course.campus].filter(Boolean).join(" "))}`,
        `DESCRIPTION:${icsEscape(`教师: ${course.teacher}\n周次: ${course.ksz}-${course.jsz}周\n节次: ${seg.startName}-${seg.endName}`)}`,
        `RRULE:FREQ=WEEKLY;INTERVAL=${odd ? 2 : 1};COUNT=${weeks.length}`,
        "END:VEVENT",
      );
    }
  }
  lines.push("END:VCALENDAR");
  return `${lines.join("\r\n")}\r\n`;
}

const ROW_H = 46;
const ROW_GAP = { 2: 10, 5: 10, 9: 10 };

export function periodTop(n) {
  let y = 0;
  for (let i = 1; i < n; i += 1) {
    y += ROW_H;
    if (ROW_GAP[i]) y += ROW_GAP[i];
  }
  return y;
}

export function spanHeight(startPeriod, endPeriod) {
  return periodTop(endPeriod) + ROW_H - periodTop(startPeriod) - 3;
}

export const GRID_HEIGHT = periodTop(12) + ROW_H;

export const PALETTE = ["#2F6BFF", "#7C5CFF", "#E8618C", "#F0853A", "#12A05C", "#0E9FB5", "#F0654E", "#7D9B2E"];

const PREFERRED = {
  数值分析: "#2F6BFF",
  分子探针与诊疗新技术: "#7C5CFF",
  应用电化学: "#12A05C",
  催化化学: "#0E9FB5",
  化学生物学导论: "#F0853A",
  学术英语读写: "#E8618C",
  太阳能材料与化学: "#F0654E",
};

export function courseColor(name, overrides = {}) {
  if (overrides[name]) return overrides[name];
  if (PREFERRED[name]) return PREFERRED[name];
  let hash = 0;
  for (const ch of name) hash = (hash * 33 + ch.codePointAt(0)) % PALETTE.length;
  return PALETTE[hash];
}

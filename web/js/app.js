import {
  PERIODS,
  WEEKDAY_LABEL,
  GRID_HEIGHT,
  PALETTE,
  addDays,
  blocksForWeek,
  buildIcs,
  courseColor,
  decorateCourse,
  formatDuration,
  formatMonthDay,
  periodTop,
  pickHero,
  sessionsOn,
  spanHeight,
  visibleWeekdays,
  weekIndex,
  weekMonday,
  weekProgress,
} from "./schedule.mjs";

const app = document.querySelector("#app");
const navStack = [];
const state = {
  snap: null,
  courses: [],
  now: new Date(),
  week: 1,
  sheet: null,
  toast: "",
  confirm: null,
  query: "",
  filter: "all",
  cacheBytes: 0,
  captcha: "",
  login: {
    sid: "",
    pwd: "",
    code: "",
    remember: true,
    agree: false,
    showPwd: false,
    error: "",
    fails: 0,
  },
  settings: null,
};

const SERVICE_ALIAS = {
  wsjxpj: "评教 评价",
  xskbcx: "课表",
  xscjcx: "成绩 分数",
  xswsxk_kb: "选课",
  xswsxk: "选课",
  xkjgcx: "选课 已选",
  kckccx: "考试 考场",
  ttkcx: "调课",
  pyjhcx: "培养计划 学分",
  xsxx: "资料",
};

const SHORTCUTS = [
  ["#/timetable", "课表", "cal"],
  ["#/grades", "成绩", "chart"],
  ["#/selected", "选课", "check"],
  ["#/eval", "评教", "star"],
];

function defaultSettings() {
  return {
    reminder: true,
    reminderMin: 15,
    deadline: true,
    dnd: true,
    weekStart: "mon",
    showOffWeek: false,
    colors: {},
    courseRemind: {},
  };
}

function loadSettings() {
  try {
    const saved = JSON.parse(localStorage.getItem("buct_settings") || "null");
    return saved ? { ...defaultSettings(), ...saved } : defaultSettings();
  } catch {
    return defaultSettings();
  }
}

function saveSettings() {
  localStorage.setItem("buct_settings", JSON.stringify(state.settings));
}

function esc(value) {
  return String(value ?? "").replace(/[&<>"']/g, (ch) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[ch]));
}

function num(value) {
  const rounded = Math.round(Number(value) * 10) / 10;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
}

function creditText(value) {
  return (Math.round(Number(value) * 10) / 10).toFixed(1);
}

function icon(name) {
  const paths = {
    bell: '<path d="M6 9a6 6 0 1 1 12 0c0 7 3 7 3 7H3s3 0 3-7"/><path d="M10 19a2 2 0 0 0 4 0"/>',
    back: '<path d="M15 5 8 12l7 7"/>',
    cal: '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M8 3v4M16 3v4M4 10h16"/>',
    chart: '<path d="M4 19V5M4 19h16"/><path d="M8 16v-4M12 16V8M16 16v-6"/>',
    check: '<circle cx="12" cy="12" r="8"/><path d="m8.5 12 2.5 2.5 4.5-5"/>',
    star: '<path d="m12 4 2.2 4.6 5 .7-3.6 3.5.9 5.1L12 15.8 7.5 17.9l.9-5.1L4.8 9.3l5-.7Z"/>',
    search: '<circle cx="11" cy="11" r="6"/><path d="m16 16 3 3"/>',
    home: '<path d="M4 11.5 12 4l8 7.5"/><path d="M7 10.5V20h10v-9.5"/>',
    grid: '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
    user: '<circle cx="12" cy="9" r="3"/><path d="M6 19c1.5-3 3.5-4 6-4s4.5 1 6 4"/>',
    chev: '<path d="m9 6 6 6-6 6"/>',
    eye: '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z"/><circle cx="12" cy="12" r="2.5"/>',
    eyeoff: '<path d="M3 3 21 21"/><path d="M10.6 6.2A10 10 0 0 1 12 6c6.5 0 10 6 10 6a18 18 0 0 1-3.1 3.7"/><path d="M6.2 6.2C3.6 8 2 12 2 12s3.5 6 10 6c1.4 0 2.7-.3 3.8-.8"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
    book: '<path d="M5 5.5A2.5 2.5 0 0 1 7.5 3H19v16H7.5A2.5 2.5 0 0 0 5 21.5Z"/><path d="M5 5.5A2.5 2.5 0 0 1 7.5 8H19"/>',
    file: '<path d="M7 3h7l5 5v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"/><path d="M14 3v6h6"/>',
    swap: '<path d="M7 7h11l-3-3"/><path d="M17 17H6l3 3"/>',
    clipboard: '<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4.5h6V4a2 2 0 0 0-2-2h-2a2 2 0 0 0-2 2v.5Z"/>',
    flag: '<path d="M6 21V4"/><path d="M6 5h11l-2.2 3.5L17 12H6"/>',
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5.5A1.5 1.5 0 0 1 9.5 4h5A1.5 1.5 0 0 1 16 5.5V7M3 12h18"/>',
    award: '<circle cx="12" cy="9" r="5"/><path d="m8.5 13.2-1.2 6.8L12 17.2l4.7 2.8-1.2-6.8"/>',
    monitor: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
    wallet: '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18"/><path d="M16 14h.01"/>',
    shield: '<path d="M12 3 5 6v6c0 4.2 2.8 6.4 7 8 4.2-1.6 7-3.8 7-8V6Z"/>',
    pencil: '<path d="M4 20h4L19 9l-4-4L4 16v4Z"/><path d="m13 7 4 4"/>',
    clock: '<circle cx="12" cy="12" r="8"/><path d="M12 8v5l3 2"/>',
    folder: '<path d="M3 7.5A2 2 0 0 1 5 5.5h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
    cpu: '<rect x="7" y="7" width="10" height="10" rx="2"/><path d="M9 3v4M15 3v4M9 17v4M15 17v4M3 9h4M3 15h4M17 9h4M17 15h4"/>',
  };
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.file}</svg>`;
}

const SERVICE_ICON = {
  grjbxx: "user",
  xyjc: "swap",
  xsxqzc: "check",
  xsrxdj: "user",
  xslqfc: "check",
  grxxxg: "pencil",
  ccqjwh: "swap",
  xjydsq: "swap",
  djksbm: "clipboard",
  djkscj: "chart",
  zpxxhd: "user",
  pyfacx: "book",
  pyjhtj: "file",
  pyjhcx: "file",
  kcmxsq: "file",
  xswsxk: "grid",
  xswsxk_kb: "check",
  xkjgcx: "check",
  xskbcx: "cal",
  ttkcx: "swap",
  kckccx: "clipboard",
  xscjcx: "chart",
  qxkczml: "book",
  cxhkbksq: "file",
  wsjxpj: "star",
  gjxsjlhd: "flag",
  py_zysjwc: "briefcase",
  xnjddj: "file",
  pypgsq: "award",
  knzzsq: "wallet",
  szgwsq: "briefcase",
  xshdbm: "flag",
  xwsxsq: "briefcase",
  zyzfwbm: "user",
  tyydbm: "check",
  tyydmxsq: "file",
  xsfblwdj: "file",
  xskycgdj: "folder",
  xszlcgdj: "cpu",
  xshjcgdj: "award",
  ktlwsq: "flag",
  lwktsq: "file",
  zqkhsq: "clipboard",
  zqkhdj: "file",
  xsdbsq: "shield",
  lwpygl: "file",
  xsxwsq: "award",
  wskscp: "pencil",
};

function parseHash(hash = location.hash) {
  const raw = (hash || "#/home").replace(/^#/, "");
  const q = raw.indexOf("?");
  const path = (q >= 0 ? raw.slice(0, q) : raw) || "/home";
  const query = q >= 0 ? raw.slice(q + 1) : "";
  const parts = path.split("/").filter(Boolean);
  return { parts, path: `/${parts.join("/")}`, query, params: new URLSearchParams(query) };
}

function gate(route) {
  const open = ["start", "guide", "login", "legal"].includes(route.parts[0]);
  if (open || sessionStorage.getItem("buct_session")) return route;
  const backTo = `#${route.path}${route.query ? `?${route.query}` : ""}`;
  sessionStorage.setItem("buct_return", backTo);
  return parseHash("#/login");
}

function go(hash) {
  if (!hash.startsWith("#")) hash = `#${hash}`;
  state.sheet = null;
  if (location.hash === hash) {
    render();
    return;
  }
  navStack.push(location.hash || "#/home");
  location.hash = hash;
}

function back(fallback) {
  state.sheet = null;
  const prev = navStack.pop();
  location.hash = prev || fallback;
}

function refreshCaptcha() {
  state.captcha = String(Math.floor(1000 + Math.random() * 9000));
}

function greeting(date) {
  const hour = date.getHours();
  if (hour < 5) return "夜深了";
  if (hour < 12) return "上午好";
  if (hour < 14) return "中午好";
  if (hour < 18) return "下午好";
  return "晚上好";
}

function currentWeek() {
  return weekIndex(state.now, state.snap.term.start);
}

function maxWeek() {
  const fromCourses = state.courses.reduce((max, course) => Math.max(max, course.jsz || 1), 1);
  return Math.max(20, fromCourses, Math.max(currentWeek(), 1));
}

function clampWeek(week) {
  return Math.min(Math.max(week, 1), maxWeek());
}

function findCourse(id) {
  return state.courses.find((course) => course.id === id);
}

function colorOf(course) {
  return courseColor(course.name, state.settings.colors);
}

function pendingEvals() {
  return state.snap.evaluations.filter((item) => item.open && !item.rated);
}

function placeOf(course) {
  return [course.room, course.campus].filter(Boolean).join(" · ");
}

function categoryName(course) {
  if (!course.category) return "未写入培养方案";
  return course.category.slice(1);
}

function categoryChip(course) {
  const raw = String(course.category || "");
  const letter = raw.slice(0, 1);
  const name = raw.slice(1);
  if (/^[A-Za-z]$/.test(letter) && name) return `${letter} · ${name}`;
  return name || "未写入培养方案";
}

function formatSeg(seg) {
  const group = String(seg.startName || "").replace(/\d/g, "");
  const startNum = String(seg.startName || "").replace(/\D/g, "");
  const endNum = String(seg.endName || "").replace(/\D/g, "");
  const span = startNum && endNum ? `${group} ${startNum}–${endNum} 节` : `${seg.startName}–${seg.endName}`;
  return `${WEEKDAY_LABEL[seg.weekday]} ${span} · ${seg.startTime}–${seg.endTime}`;
}

function serviceGlyph(id) {
  return icon(SERVICE_ICON[id] || "file");
}

let toastTimer = 0;
let ignoreClick = false;
function toast(message) {
  state.toast = message;
  render();
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    state.toast = "";
    render();
  }, 2200);
}

function downloadText(filename, text, type) {
  const blob = new Blob([text], { type });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(link.href);
}

function exportIcs(id) {
  const courses = id ? state.courses.filter((course) => course.id === id) : state.courses;
  if (courses.every((course) => course.online)) {
    toast("线上课的节次是占位，没有写进日历");
    return;
  }
  const ics = buildIcs(courses, state.snap.term.start, id ? courses[0].name : "化研助手课表");
  downloadText(id ? `${courses[0].name}.ics` : "化研助手课表.ics", ics, "text/calendar");
  toast(id ? "已导出这门课的日历文件" : "已导出线下课日历，线上课已跳过");
}

function courseRemindOn(id) {
  const value = state.settings.courseRemind[id];
  return value === undefined ? state.settings.reminder : value;
}

function toggleCourseRemind(id) {
  const next = !courseRemindOn(id);
  state.settings.courseRemind[id] = next;
  saveSettings();
  if (next && "Notification" in window && Notification.permission === "default") {
    Notification.requestPermission().catch(() => {});
  }
  toast(next ? `上课前 ${state.settings.reminderMin} 分钟提醒，网页打开时才会响` : "这门课不再提醒");
}

function inQuietHours(date) {
  if (!state.settings.dnd) return false;
  const hour = date.getHours();
  return hour >= 22 || hour < 7;
}

function maybeRemind() {
  if (!state.settings.reminder || inQuietHours(state.now) || state.reminded) return;
  const { items } = sessionsOn(state.courses, state.now, state.snap.term.start);
  const hero = pickHero(items, state.now);
  if (hero.kind !== "next" && hero.kind !== "ongoing") return;
  if (!courseRemindOn(hero.item.course.id)) return;
  if (hero.kind === "next" && hero.minutes > state.settings.reminderMin) return;
  state.reminded = true;
  const name = hero.item.course.name;
  toast(hero.kind === "ongoing" ? `${name}正在上课` : `${name}还有 ${formatDuration(hero.minutes)}上课`);
}

function shell(route, body) {
  const tabs = ["home", "timetable", "services", "me"].includes(route.parts[0]);
  const plain = ["start", "guide", "login"].includes(route.parts[0]);
  const center = ["start", "guide"].includes(route.parts[0]);
  const timetable = route.parts[0] === "timetable";
  const course = route.parts[0] === "course";
  const content = tabs ? `<div class="screen-body">${body}</div>` : body;
  return `
    <div class="screen${tabs ? " with-tabs" : ""}${plain ? " plain" : ""}${center ? " center" : ""}${timetable ? " timetable" : ""}${course ? " course" : ""}">${content}</div>
    ${tabs ? tabbar(route.parts[0]) : ""}
    ${state.sheet ? sheet() : ""}
    ${state.confirm ? dialog() : ""}
    ${state.toast ? `<div class="toast" role="status">${esc(state.toast)}</div>` : ""}
  `;
}

function tabbar(active) {
  const tabs = [
    ["home", "首页", "home"],
    ["timetable", "课表", "cal"],
    ["services", "服务", "grid"],
    ["me", "我的", "user"],
  ];
  return `<nav class="tabbar" aria-label="主导航">${tabs.map(([id, label, glyph]) => `
    <button class="tab${active === id ? " active" : ""}" data-act="go" data-href="#/${id}" ${active === id ? 'aria-current="page"' : ""}>
      ${icon(glyph)}<span>${label}</span>
    </button>`).join("")}</nav>`;
}

function nav(title, fallback) {
  return `<div class="nav"><button class="back" data-act="back" data-fallback="${fallback}" aria-label="返回">${icon("back")}</button><h1>${esc(title)}</h1></div>`;
}

function empty(title, text, glyph = "file") {
  return `<div class="empty"><div class="empty-art" aria-hidden="true">${icon(glyph)}</div><h2>${esc(title)}</h2><p>${esc(text)}</p></div>`;
}

function viewStart() {
  return `
    <div class="top"><button class="skip" data-act="skip">跳过</button></div>
    <div class="hero-illu" aria-hidden="true">
      <div class="win">
        <div class="win-dots"><i></i><i></i><i></i></div>
        <div class="win-body">
          <div class="win-rail"></div>
          <div class="win-grid">
            <i class="a"></i><i></i><i class="b"></i>
            <i></i><i class="c"></i><i></i>
            <i></i><i class="d"></i><i></i>
          </div>
        </div>
        <span class="pin"></span>
      </div>
    </div>
    <h1 class="display">一学期的课<br>一张表看清</h1>
    <p class="lead">课表、选课、成绩、待办，都在一个地方。不用再每天开电脑登网页。</p>
    <div class="dots" aria-hidden="true"><i class="on"></i><i></i></div>
    <div class="grow"></div>
    <button class="btn primary full" data-act="go" data-href="#/guide">下一步</button>
  `;
}

function viewGuide() {
  const items = [
    ["blue", "cal", "课表自动同步", "打开就能看这份已同步的课表。调课、停课以学校系统为准。"],
    ["purple", "check", "选课少走弯路", "余量和冲突会先算好。现在不在选课周，这里只放已选结果。"],
    ["orange", "bell", "截止日不漏", "评教和流程收在首页。学校没给日期的，不编一个截止日。"],
    ["green", "grid", "低频功能不用再开电脑", "学校系统里的入口按分类放好，找不到就搜。"],
  ];
  return `
    <div class="top"><button class="skip" data-act="skip">跳过</button></div>
    <h1 class="display">登录一次<br>剩下的事它帮你盯着</h1>
    <div class="features">
      ${items.map(([tone, glyph, title, text]) => `<div class="feature"><span class="feat-ico ${tone}">${icon(glyph)}</span><div><h3>${title}</h3><p>${text}</p></div></div>`).join("")}
    </div>
    <p class="guide-note">数据来自 ${esc(state.snap.updatedLabel)} 导出的学校快照。预览不保存密码，也不连接学校服务器。</p>
    <div class="grow"></div>
    <div class="dots" aria-hidden="true"><i></i><i class="on"></i></div>
    <button class="btn primary full" data-act="skip">开始使用</button>
  `;
}

function viewLogin() {
  const login = state.login;
  const digits = state.captcha.split("").map((digit, index) => {
    const rotate = [-8, 6, -4, 7][index];
    return `<i style="transform:rotate(${rotate}deg)">${digit}</i>`;
  }).join("");
  return `
    <form id="login-form" autocomplete="off">
      <div class="brand-row">
        <div class="logo" aria-hidden="true"><i></i><i></i><i></i><i></i></div>
        <div>
          <h1>化研助手</h1>
          <p>北京化工大学 · 研究生管理系统</p>
        </div>
      </div>
      <p class="login-lead">用学号和教务密码进入。这份预览读的是已导出的快照，密码不会保存。</p>
      <div class="field">
        <input id="sid" name="sid" type="text" inputmode="numeric" autocomplete="off" spellcheck="false" placeholder="学号" aria-label="学号" value="${esc(login.sid)}" />
      </div>
      <div class="field">
        <div class="pwd-wrap">
          <input id="pwd" name="pwd" type="${login.showPwd ? "text" : "password"}" autocomplete="new-password" placeholder="密码" aria-label="密码" value="${esc(login.pwd)}" />
          <button class="eye" type="button" data-act="toggle-pwd" aria-label="${login.showPwd ? "隐藏密码" : "显示密码"}">${icon(login.showPwd ? "eyeoff" : "eye")}</button>
        </div>
      </div>
      <div class="field captcha-row">
        <input id="code" name="code" type="text" inputmode="numeric" maxlength="4" autocomplete="off" spellcheck="false" placeholder="验证码（4 位数字）" aria-label="验证码" value="${esc(login.code)}" />
        <button class="captcha" type="button" data-act="captcha" aria-label="换一张验证码">${digits}</button>
      </div>
      <div class="row-between">
        <label class="check"><input id="remember" type="checkbox" ${login.remember ? "checked" : ""}/> 记住学号</label>
        <button class="text-link" type="button" data-act="forgot">忘记密码</button>
      </div>
      <p class="alert" role="alert">${esc(login.error)}</p>
      <button class="btn primary full" type="submit">登录</button>
      <div class="login-foot">
        <p>登录即表示同意<button type="button" data-act="go" data-href="#/legal/terms">《服务条款》</button>与<button type="button" data-act="go" data-href="#/legal/privacy">《隐私政策》</button></p>
        <p>非官方客户端 · 数据来自 ${esc(state.snap.updatedLabel)} 的学校快照</p>
      </div>
    </form>
  `;
}

function viewHome() {
  const snap = state.snap;
  const week = currentWeek();
  const weekText = week < 1 ? "学期还没开始" : `第 ${week} 周`;
  const { items } = sessionsOn(state.courses, state.now, snap.term.start);
  const hero = pickHero(items, state.now);
  const pending = pendingEvals();
  const credits = snap.credits;
  const remain = num(credits.required - credits.selected);
  const notices = snap.notices || [];
  return `
    <div class="top">
      <div>
        <h1>${greeting(state.now)}，${esc(snap.student.xm)}</h1>
        <p class="subline">${esc(snap.term.name)} · ${weekText}<br>更新于 ${esc(snap.updatedLabel)}</p>
      </div>
      <button class="icon-btn bare" data-act="go" data-href="#/notices" aria-label="通知">${icon("bell")}${notices.length ? '<i class="badge"></i>' : ""}</button>
    </div>
    ${heroCard(hero, items)}
    ${pending.length ? `
      <section class="slot">
        <div class="slot-head">
          <p class="eyebrow">最要紧的一件事</p>
          <button class="go" data-act="go" data-href="#/eval">去评教</button>
        </div>
        <h3>还有 ${pending.length} 门课没评</h3>
        <p>课程结束后一个月内需要评完，否则可能影响查成绩。学校没有返回具体截止日期。</p>
      </section>` : ""}
    <div class="card" role="button" tabindex="0" data-act="go" data-href="#/progress">
      <div class="card-head"><h3>培养方案学分</h3><span class="frac">${num(credits.selected)} / ${num(credits.required)}</span></div>
      <div class="bar" style="margin-top:12px"><span style="width:${Math.min(100, (credits.selected / credits.required) * 100)}%"></span></div>
      <p class="fine">还差 ${remain} 学分 · 本学期 ${state.courses.length} 门课</p>
    </div>
  `;
}

function heroFoot(items, hero) {
  const nowMin = state.now.getHours() * 60 + state.now.getMinutes();
  const rest = items.filter((item) => item !== hero.item);
  const later = rest.filter((item) => item.startMin > nowMin);
  const earlier = rest.filter((item) => item.endMin <= nowMin);
  const bits = [];
  if (later.length) {
    bits.push(`今天还有 ${later.length} 门${later.map((item) => ` · ${item.seg.startTime} ${esc(item.course.name)}`).join("")}`);
  }
  if (earlier.length) bits.push(`已上完 ${earlier.map((item) => esc(item.course.name)).join("、")}`);
  return bits.length ? `<p class="hero-foot">${bits.join(" · ")}</p>` : "";
}

function heroCard(hero, items) {
  const weekday = WEEKDAY_LABEL[(state.now.getDay() + 6) % 7];
  const dateLabel = formatMonthDay(state.now);
  const head = `<div class="hero-top"><span>今天 · ${weekday}</span><b>${dateLabel}</b></div>`;
  if (hero.kind === "empty") {
    return `<section class="hero">${head}<h2>今天没有线下课</h2><p class="meta">线上课不占教室，收在课表最下面。</p></section>`;
  }
  const course = hero.item.course;
  const seg = hero.item.seg;
  if (hero.kind === "done") {
    return `<section class="hero" role="button" tabindex="0" data-act="go" data-href="#/course/${course.id}">${head}<h2>今天的课上完了</h2><p class="meta">${esc(course.name)} · ${seg.endTime} 结束</p></section>`;
  }
  const label = hero.kind === "ongoing" ? "正在上" : "下一节";
  const remain = hero.kind === "ongoing" ? `还剩 ${formatDuration(hero.minutes)}` : `还有 ${formatDuration(hero.minutes)}`;
  return `
    <section class="hero" role="button" tabindex="0" data-act="go" data-href="#/course/${course.id}">
      ${head}
      <div class="hero-kicker">
        <div>
          <span class="pill${hero.kind === "ongoing" ? " live" : ""}">${label}</span>
          <div class="clock">${seg.startTime}</div>
        </div>
        <span class="remain">${remain}</span>
      </div>
      <h2>${esc(course.name)}</h2>
      <p class="meta">${esc(placeOf(course))} · ${esc(course.teacher)} · ${course.ksz}–${course.jsz} 周 · ${num(course.credits)} 学分</p>
      ${heroFoot(items, hero)}
    </section>
  `;
}

function viewTimetable() {
  const week = state.week;
  const monday = weekMonday(week, state.snap.term.start);
  const sunday = addDays(monday, 6);
  const days = visibleWeekdays(state.courses);
  const blocks = blocksForWeek(state.courses, week, state.settings.showOffWeek);
  const todayWeek = currentWeek();
  const todayIndex = (state.now.getDay() + 6) % 7;
  const online = state.courses.filter((course) => course.online);
  const heads = days.map((day) => {
    const date = addDays(monday, day);
    const isToday = week === todayWeek && day === todayIndex;
    return `<div class="day${isToday ? " today" : ""}">${WEEKDAY_LABEL[day]}<b>${date.getDate()}</b></div>`;
  }).join("");
  const cols = days.map((day) => {
    const cell = blocks.filter((block) => block.weekday === day).map((block) => {
      const course = findCourse(block.courseId);
      return `<button class="block${block.active ? "" : " off"}" style="--c:${colorOf(course)};top:${periodTop(block.startPeriod)}px;height:${spanHeight(block.startPeriod, block.endPeriod)}px" data-act="sheet" data-id="${block.courseId}" title="${esc(block.name)} ${esc(block.room)}">
        <strong>${esc(block.name)}</strong>${block.room ? `<em>${esc(block.room)}</em>` : ""}
      </button>`;
    }).join("");
    return `<div class="col">${cell}</div>`;
  }).join("");
  const ticks = (state.periods || PERIODS).map((period) => `<span class="tick" style="top:${periodTop(period.n)}px">${period.start}</span>`).join("");
  const max = maxWeek();
  return `
    <div class="weekbar">
      <div class="week-title-row">
        <h1>课表</h1>
        <button class="today-pill" type="button" data-act="today">回到今天</button>
      </div>
      <div class="week-sub">
        <div class="week-switch">
          <button type="button" data-act="week" data-delta="-1" aria-label="上一周" ${week <= 1 ? "disabled" : ""}>‹</button>
          <strong>第 ${week} 周</strong>
          <button type="button" data-act="week" data-delta="1" aria-label="下一周" ${week >= max ? "disabled" : ""}>›</button>
        </div>
        <div class="week-meta">${formatMonthDay(monday)} – ${formatMonthDay(sunday)}</div>
      </div>
    </div>
    <div class="tt" style="--days:${days.length};--gh:${GRID_HEIGHT}px">
      <div class="tt-head"><div></div>${heads}</div>
      <div class="tt-scroll">${ticks}<div class="tt-cols"><div></div>${cols}</div></div>
    </div>
    <button class="online-bar" data-act="go" data-href="#/online"><span><i class="online-dot"></i>线上课程 ${online.length} 门 · 不占课时</span><b>查看</b></button>
  `;
}

function sheet() {
  const course = findCourse(state.sheet);
  if (!course) return "";
  const time = course.segments.length ? course.segments.map(formatSeg).join("；") : (course.sjms || "无线下时间");
  const thisWeek = (course.weeks || []).includes(state.week) ? "本周有课" : "本周无课";
  return `
    <div class="mask" data-act="close-sheet">
      <div class="sheet-card" data-act="stop">
        <div class="handle"></div>
        <h2>${esc(course.name)}</h2>
        <p class="fine">${esc(categoryName(course))} · ${num(course.credits)} 学分 · ${course.enrolled || 0} 人已选</p>
        <div class="kv"><span>上课时间</span><b>${esc(time)}</b></div>
        <div class="kv"><span>上课地点</span><b>${esc(placeOf(course) || "未安排教室")}</b></div>
        <div class="kv"><span>任课教师</span><b>${esc(course.teacher)}</b></div>
        <div class="kv"><span>上课周次</span><b>${course.ksz}–${course.jsz} 周 · ${thisWeek}</b></div>
        <div class="actions">
          <button class="btn" type="button" data-act="go" data-href="#/course/${course.id}">查看完整详情</button>
          <button class="btn primary" type="button" data-act="ics" data-id="${course.id}">加入日历</button>
        </div>
      </div>
    </div>
  `;
}

function viewCourse(id) {
  const course = findCourse(id);
  if (!course) return `${nav("课程", "#/timetable")}${empty("找不到这门课", "它不在这份快照里。", "search")}`;
  const week = currentWeek();
  const progress = weekProgress(course, week);
  const remind = courseRemindOn(course.id);
  const color = colorOf(course);
  const phase = progress.phase === "upcoming"
    ? `还没开始 · 共 ${progress.total} 周`
    : progress.phase === "ended"
      ? "这个上课周期已经结束"
      : `第 ${week} 周 · ${course.ksz}–${course.jsz} 周 · 还剩 ${progress.remain} 周`;
  const times = course.segments.map(formatSeg).join("；");
  const thisWeek = (course.weeks || []).includes(week) ? "本周有课" : "本周无课";
  return `
    <div class="nav"><button class="back" data-act="back" data-fallback="#/timetable" aria-label="返回">${icon("back")}</button></div>
    <div>
      <span class="chip" style="--c:${color}">${esc(categoryChip(course))}</span>
      <h1 class="detail-title">${esc(course.name)}</h1>
      <p class="subline">${esc(course.className)} · ${esc(course.teacher)}</p>
      <div class="stats">
        <span>${num(course.credits)} 学分</span>
        ${course.hours ? `<span>${course.hours} 学时</span>` : ""}
        <span>${course.enrolled || 0} 人已选</span>
      </div>
      <div class="card kv-page">
        <div class="kv"><span>上课时间</span><b>${esc(times || "无线下时间")}</b></div>
        <div class="kv"><span>上课地点</span><b>${esc(placeOf(course) || "未安排教室")}</b></div>
        <div class="kv"><span>上课周次</span><b>${course.ksz}–${course.jsz} 周 · ${esc(course.pattern)} · ${thisWeek}</b></div>
        <div class="kv"><span>课程编号</span><b>${esc(course.code)}</b></div>
      </div>
      <div class="card">
        <div class="card-head"><span class="quiet">课程进度</span><b class="blue">${progress.done} / ${progress.total} 周</b></div>
        <p class="progress-line">${phase}</p>
        <div class="bar"><span style="width:${progress.total ? (progress.done / progress.total) * 100 : 0}%;background:${color}"></span></div>
      </div>
      <div class="set-group">
        <div class="set-row"><span>上课提醒<small>提前 ${state.settings.reminderMin} 分钟 · 网页打开时才会提示</small></span>
          <button class="switch${remind ? " on" : ""}" type="button" role="switch" aria-checked="${remind}" data-act="remind" data-id="${course.id}"></button>
        </div>
      </div>
    </div>
    <div class="dock">
      <p class="hint">导出的日历不会自动响铃，上课前提示只在这个网页打开时出现。</p>
      <div class="actions">
        <button class="btn" type="button" data-act="remind" data-id="${course.id}">${remind ? "关闭提醒" : "上课提醒"}</button>
        <button class="btn primary" type="button" data-act="ics" data-id="${course.id}">导出到日历</button>
      </div>
    </div>
  `;
}

function viewOnline() {
  const courses = state.courses.filter((course) => course.online);
  return `
    ${nav("线上课程", "#/timetable")}
    <p class="subline" style="margin-bottom:14px">${courses.length} 门课的节次是占位，和线下课叠在同一格。这里单独列出，不占课表。</p>
    <div class="stack">${courses.map(courseRow).join("")}</div>
  `;
}

function courseRow(course) {
  return `<div class="course-row" role="button" tabindex="0" data-act="go" data-href="#/course/${course.id}">
    <i class="dot" style="--c:${colorOf(course)}"></i>
    <span class="txt"><h3>${esc(course.name)}</h3><p>${num(course.credits)} 学分 · ${esc(course.teacher)} · ${course.ksz}–${course.jsz} 周</p></span>
  </div>`;
}

function viewServices() {
  const query = state.query.trim();
  let body = "";
  if (query) {
    const services = [];
    for (const group of state.snap.services) {
      for (const item of group.items) {
        const alias = SERVICE_ALIAS[item.id] || "";
        if (item.name.includes(query) || alias.includes(query)) services.push({ ...item, group: group.name });
      }
    }
    const courses = state.courses.filter((course) => course.name.includes(query) || course.teacher.includes(query) || course.code.toLowerCase().includes(query.toLowerCase()));
    body = `
      <p class="section-label">功能</p>
      ${services.length ? `<div class="stack">${services.map((item) => serviceButton(item, item.group)).join("")}</div>` : `<p class="miss">没有叫「${esc(query)}」的功能</p>`}
      <p class="section-label">课程和老师</p>
      ${courses.length ? `<div class="stack">${courses.map(courseRow).join("")}</div>` : `<p class="miss">没有匹配的课</p>`}
    `;
  } else {
    body = `
      <section class="common">
        <p class="eyebrow">常用</p>
        <div class="common-row">${SHORTCUTS.map(([href, label, glyph]) => `
          <button type="button" data-act="go" data-href="${href}">${icon(glyph)}${label}</button>`).join("")}</div>
      </section>
      <div class="grid-2">
        ${state.snap.services.map((group) => `
          <article class="group-card">
            <header><h3>${esc(group.name)}</h3>${group.items.length > 4 ? `<button class="text-link" data-act="go" data-href="#/group/${group.id}">全部</button>` : ""}</header>
            <div class="mini-grid">
              ${group.items.slice(0, 4).map((item) => `
                <button class="mini" data-act="service" data-path="${esc(item.path)}" data-native="${esc(item.native || "")}" data-title="${esc(item.name)}">
                  <span class="mini-glyph">${serviceGlyph(item.id)}</span><em>${esc(item.name)}</em>
                </button>`).join("")}
            </div>
          </article>`).join("")}
      </div>
    `;
  }
  return `
    <div class="top"><h1>服务</h1></div>
    <label class="search">${icon("search")}<input id="q" type="search" placeholder="搜功能、课程、老师" value="${esc(state.query)}" /></label>
    ${body}
  `;
}

function serviceButton(item, group) {
  return `<div class="course-row" role="button" tabindex="0" data-act="service" data-path="${esc(item.path)}" data-native="${esc(item.native || "")}" data-title="${esc(item.name)}">
    <span class="mini-glyph">${serviceGlyph(item.id)}</span>
    <span class="txt"><h3>${esc(item.name)}</h3><p>${esc(group)}${item.native ? " · 本机页面" : " · 学校网页"}</p></span>
  </div>`;
}

function viewGroup(id) {
  const group = state.snap.services.find((item) => item.id === id);
  if (!group) return `${nav("服务", "#/services")}${empty("没有这个分类", "回到服务页重新选。")}`;
  return `${nav(group.name, "#/services")}<div class="stack">${group.items.map((item) => serviceButton(item, group.name)).join("")}</div>`;
}

function viewWebview() {
  const route = parseHash();
  const path = route.params.get("path") || "";
  const title = route.params.get("title") || "学校网页";
  const allowed = path.startsWith("/student/");
  const url = allowed ? `https://gmis.buct.edu.cn${path}` : "";
  return `
    ${nav(title, "#/services")}
    ${allowed ? `
      <div class="card">
        <h3 style="margin:0 0 6px">会在学校网站打开</h3>
        <p class="muted" style="line-height:1.55">App 版会带上登录状态直接进这个页面。网页预览不能代持会话，打开后如果学校要求登录，需要你自己再登一次。</p>
        <p class="fine">${esc(url)}</p>
      </div>
      <a class="btn primary full" style="display:grid;place-items:center;text-decoration:none" href="${esc(url)}" target="_blank" rel="noopener noreferrer">在浏览器中打开</a>
    ` : empty("链接已拦住", "只允许打开 gmis.buct.edu.cn 上的学生页面。")}
  `;
}

function viewMe() {
  const student = state.snap.student;
  const credits = state.snap.credits;
  const preferred = ["lwkt", "pyjh", "zc", "lwdb"];
  const apps = preferred
    .map((id) => state.snap.applications.find((item) => item.id === id))
    .filter(Boolean)
    .slice(0, 2);
  const frontier = credits.categories.find((item) => item.name === "前沿课程");
  const frontierNote = frontier && frontier.got === 0 ? " · 前沿课程未开始" : "";
  return `
    <div class="top"><h1>我的</h1></div>
    <button class="person" type="button" data-act="go" data-href="#/profile">
      <span class="avatar">${esc(student.xm.slice(0, 1))}</span>
      <span>
        <h2>${esc(student.xm)}</h2>
        <p>${esc(student.xh)} · ${esc(student.college)}<br>${esc(student.major)} · 导师 ${esc(student.advisor)}</p>
      </span>
    </button>
    <div class="card" role="button" tabindex="0" data-act="go" data-href="#/progress">
      <div class="card-head"><h3>培养进度</h3><span class="text-link">查看明细</span></div>
      <div class="score"><b>${num(credits.selected)}</b><span>/ ${num(credits.required)} 学分</span></div>
      <div class="bar"><span style="width:${(credits.selected / credits.required) * 100}%"></span></div>
      <p class="fine">还差 ${num(credits.required - credits.selected)} 学分${frontierNote}</p>
    </div>
    <section class="card apps">
      <div class="card-head"><h3>我的申请</h3><button class="text-link" data-act="go" data-href="#/apps">全部 ${state.snap.applications.length} 项</button></div>
      ${apps.map(appRow).join("")}
    </section>
    <div class="set-group">
      ${meLink("成绩单", "本学期未出分", "#/grades")}
      ${meLink("已修课程", `${state.courses.length} 门 · ${num(credits.selected)} 学分`, "#/selected")}
      ${meLink("我的评价", `${pendingEvals().length} 门未评`, "#/eval")}
      ${meLink("考试与调课", "还没有安排", "#/exams")}
      ${meLink("消息与提醒", (state.snap.notices || []).length ? `${state.snap.notices.length} 条` : "暂无通知", "#/notices")}
      ${meLink("设置", "账号与安全", "#/settings")}
    </div>
  `;
}

function meLink(title, value, href) {
  return `<button class="set-row menu-row" data-act="go" data-href="${href}"><span>${title}</span><em>${value}</em></button>`;
}

function appRow(item) {
  return `<div class="app-row"><div class="txt"><h3>${esc(item.name)}</h3>${item.time ? `<p>${esc(item.time)}</p>` : ""}</div><span class="tag ${esc(item.tone)}">${esc(item.label)}</span></div>`;
}

function viewApps() {
  return `${nav("我的申请", "#/me")}<p class="subline" style="margin-bottom:12px">状态来自学校流程。未提交的事项学校没有给截止日期，这里不编一个。</p><div class="card apps">${state.snap.applications.map(appRow).join("")}</div>`;
}

function viewProfile() {
  const student = state.snap.student;
  const rows = [
    ["姓名", student.xm],
    ["学号", student.xh],
    ["学院", student.college],
    ["专业", student.major],
    ["学生类别", student.kind],
    ["年级", student.grade],
    ["导师", student.advisor],
  ];
  return `${nav("个人资料", "#/me")}<div class="card kv-page">${rows.map(([label, value]) => `<div class="kv"><span>${label}</span><b>${esc(value)}</b></div>`).join("")}</div><p class="fine">证件号、手机号、家庭住址和密码没有放进这个预览。</p>`;
}

function viewProgress() {
  const credits = state.snap.credits;
  const orphans = credits.orphans;
  const frontier = credits.categories.find((item) => item.name === "前沿课程");
  const frontierNote = frontier && frontier.got === 0 ? ` · 前沿课程 ${num(frontier.need)} 学分未开始` : "";
  return `
    ${nav("培养进度", "#/me")}
    <div class="card">
      <div class="score"><b>${num(credits.selected)}</b><span>/ ${num(credits.required)} 学分</span></div>
      <div class="bar"><span style="width:${(credits.selected / credits.required) * 100}%"></span></div>
      <p class="fine">还差 ${num(credits.required - credits.selected)} 学分${frontierNote}</p>
    </div>
    <div class="card">
      <h3>学分构成</h3>
      ${credits.categories.map((item) => {
        const done = item.need > 0 && item.got >= item.need;
        const untouched = item.got === 0;
        const cls = done ? "done" : untouched ? "wait" : "";
        return `<div class="cat"><span>${esc(item.name)}</span><b class="${cls}">${creditText(item.got)} / ${creditText(item.need)}${done ? " <i>已完成</i>" : ""}</b></div>`;
      }).join("")}
    </div>
    ${orphans.length ? `<div class="note"><strong>${orphans.length} 门线上课未对应培养方案条目</strong><p>${esc(orphans.map((item) => `${item.name} ${num(item.credits)} 学分`).join("、"))}。已计入总学分，但不属于任何一类。建议和系里培养办核对。</p></div>` : ""}
    <p class="fine">这是已选学分，不是已出成绩。更新于 ${esc(state.snap.updatedLabel)}。</p>
    <button class="text-link more-link" data-act="go" data-href="#/selected">查看本学期 ${state.courses.length} 门课</button>
  `;
}

function viewGrades() {
  const credits = state.snap.credits;
  const rows = [
    ["记录学分", `${num(credits.recorded)} / ${num(credits.required)}`],
    ["学位课", `${num(credits.degreeRecorded)} / ${num(credits.degreeRequired)}`],
    ["非学位课", `${num(credits.nonDegreeRecorded)} / ${num(credits.nonDegreeRequired)}`],
    ["总 GPA", credits.gpa == null ? "学校还没返回" : credits.gpa],
    ["学位 GPA", credits.degreeGpa == null ? "学校还没返回" : credits.degreeGpa],
  ];
  return `
    ${nav("成绩单", "#/me")}
    ${empty("本学期还没有成绩", `成绩单是空的。已选的 ${num(credits.selected)} 学分在培养进度里，先不要把它当成已出分。`, "chart")}
    <div class="card kv-page">${rows.map(([label, value]) => `<div class="kv"><span>${label}</span><b>${esc(value)}</b></div>`).join("")}</div>
    <p class="fine">毕业要求以学校公布的规则为准。这里没有自行换算 GPA。</p>
    <button class="btn primary full" style="margin-top:16px" data-act="go" data-href="#/progress">看已选学分</button>
  `;
}

function viewExams() {
  return `
    ${nav("考试与调课", "#/me")}
    <div class="empty-card"><div class="empty-art" aria-hidden="true">${icon("clipboard")}</div><div><h3>考场</h3><p>还没有考试安排。公布后会显示课程、时间、地点和座位。</p></div></div>
    <div class="empty-card"><div class="empty-art" aria-hidden="true">${icon("swap")}</div><div><h3>调课</h3><p>这份快照里没有调课记录。有变动时会写明哪一门、改到什么时候。</p></div></div>
    <p class="fine">学校没有返回日期，这里就不放倒计时。考前提醒留在设置里，现在没有可提醒的考试。</p>
  `;
}

function viewNotices() {
  return `${nav("通知", "#/home")}${empty("暂无学校通知", "这次导出的通知是空的。评教待办在首页，不把它伪装成一条学校通知。", "bell")}`;
}

function viewEval() {
  const items = state.snap.evaluations;
  return `
    ${nav("课程评教", "#/home")}
    <p class="subline" style="margin-bottom:12px">${pendingEvals().length} 门未评，${items.length - pendingEvals().length} 门已评。提交评教要进学校页面，这里不能代填。</p>
    <div class="stack">
      ${items.map((item) => `<div class="course-row" role="button" tabindex="0" data-act="service" data-path="/student/pygl/wsjxpj" data-native="" data-title="课程教学评价">
        <span class="txt"><h3>${esc(item.name)}</h3><p>${esc(item.teacher)} · ${num(item.credits)} 学分</p></span>
        <span class="tag ${item.rated ? "ok" : "amber"}">${item.rated ? "已评" : "未评"}</span>
      </div>`).join("")}
    </div>
  `;
}

function viewSelected() {
  const filtered = state.courses.filter((course) => state.filter === "all" || (state.filter === "online" ? course.online : !course.online));
  const chips = [["all", "全部"], ["offline", "线下"], ["online", "线上"]];
  return `
    ${nav("已选课程", "#/me")}
    <p class="subline">集中选课窗口已经结束。这里是选课结果，共 ${num(state.snap.credits.selected)} 学分。预览里不能退课或代选。</p>
    <div class="filters">
      ${chips.map(([id, label]) => `<button type="button" class="${state.filter === id ? "on" : ""}" data-act="filter" data-filter="${id}">${label}</button>`).join("")}
    </div>
    <div class="stack">${filtered.map(courseRow).join("") || empty("这一类没有课", "换一个筛选看看。")}</div>
  `;
}

function viewSettings() {
  const settings = state.settings;
  const student = state.snap.student;
  return `
    ${nav("设置", "#/me")}
    <div class="set-group">
      <p class="set-label">账号</p>
      <button class="set-row" data-act="go" data-href="#/profile"><span>个人资料<small>${esc(student.xm)} · ${esc(student.xh)}</small></span>${icon("chev")}</button>
      <button class="set-row" data-act="logout"><span class="danger-text">退出登录</span></button>
    </div>
    <div class="set-group">
      <p class="set-label">提醒</p>
      <div class="set-row"><span>上课提醒<small>提前 ${settings.reminderMin} 分钟</small></span><button class="switch${settings.reminder ? " on" : ""}" type="button" role="switch" aria-checked="${settings.reminder}" data-act="setting" data-setting="reminder"></button></div>
      <div class="set-row"><span>截止提醒<small>评教和未提交事项</small></span><button class="switch${settings.deadline ? " on" : ""}" type="button" role="switch" aria-checked="${settings.deadline}" data-act="setting" data-setting="deadline"></button></div>
      <div class="set-row"><span>免打扰<small>22:00–07:00 不提示</small></span><button class="switch${settings.dnd ? " on" : ""}" type="button" role="switch" aria-checked="${settings.dnd}" data-act="setting" data-setting="dnd"></button></div>
    </div>
    <div class="set-group">
      <p class="set-label">课表</p>
      <button class="set-row" data-act="week-start"><span>每周起始日</span><em>${settings.weekStart === "mon" ? "周一" : "周日"}</em></button>
      <div class="set-row"><span>显示非本周课程</span><button class="switch${settings.showOffWeek ? " on" : ""}" type="button" role="switch" aria-checked="${settings.showOffWeek}" data-act="setting" data-setting="showOffWeek"></button></div>
      <button class="set-row" data-act="go" data-href="#/settings/look"><span>课程外观<small>配色跟着课走，不跟着格子走</small></span>${icon("chev")}</button>
      <button class="set-row" data-act="ics-all"><span>导出全部线下课<small>生成 ICS 文件，线上课会跳过</small></span>${icon("chev")}</button>
    </div>
    <div class="set-group">
      <p class="set-label">通用与隐私</p>
      <div class="set-row"><span>深色模式<small>预览页仍是浅色</small></span><em>跟随系统</em></div>
      <button class="set-row" data-act="go" data-href="#/settings/widget"><span>桌面小组件<small>今日课程、下一节课</small></span>${icon("chev")}</button>
      <button class="set-row" data-act="clear"><span>清理本机偏好<small>不清除登录和课表快照</small></span></button>
      <button class="set-row" data-act="go" data-href="#/settings/data"><span>我们读取了哪些数据<small>来源、存在这台浏览器里的内容</small></span>${icon("chev")}</button>
      <div class="set-row"><span>版本</span><em>0.1.0 网页预览</em></div>
    </div>
  `;
}

function viewSettingsSub(page) {
  if (page === "look") {
    const courses = state.courses.filter((course) => !course.online);
    return `
      ${nav("课程外观", "#/settings")}
      <p class="subline" style="margin-bottom:12px">点一下换颜色。同一门课在所有周都用这个颜色。</p>
      <div class="stack">
        ${courses.map((course) => `<div class="look-item"><div class="look-name"><i class="dot" style="--c:${colorOf(course)}"></i><h3>${esc(course.name)}</h3></div>
          <span class="colors">${PALETTE.map((color) => `<button type="button" style="background:${color}" data-act="color" data-name="${esc(course.name)}" data-color="${color}" aria-label="${esc(course.name)} ${color}"></button>`).join("")}</span>
        </div>`).join("")}
      </div>
    `;
  }
  if (page === "widget") {
    const { items } = sessionsOn(state.courses, state.now, state.snap.term.start);
    const hero = pickHero(items, state.now);
    const course = hero.item && hero.item.course;
    return `
      ${nav("桌面小组件", "#/settings")}
      <div class="hero">
        <span class="pill">下一节</span>
        <h2>${course ? esc(course.name) : "今天没有课"}</h2>
        <p>${course ? `${hero.item.seg.startTime} · ${esc(placeOf(course))}` : "小组件会显示这句话"}</p>
      </div>
      <p class="subline">桌面小组件是 App 版的能力。网页预览只能把卡片做出来，不能放到主屏幕。</p>
    `;
  }
  const rows = [
    ["学号、姓名、学院、专业、导师", "用来显示你是谁"],
    ["课表、已选课、培养计划", "用来排课和算学分"],
    ["成绩统计", "这次导出没有具体分数"],
    ["评教是否完成、申请走到哪一步", "用来排首页待办"],
  ];
  return `
    ${nav("我们读取了哪些数据", "#/settings")}
    <div class="card kv-page">${rows.map(([label, value]) => `<div class="kv"><span>${esc(label)}</span><b>${esc(value)}</b></div>`).join("")}</div>
    <div class="note"><strong>没有读取的</strong><p>密码、证件号、手机号、家庭住址。记住学号只存在这台浏览器里。退出登录会清掉会话，不会清掉学号，除非你关掉「记住学号」。</p></div>
    <p class="fine">${esc(state.snap.campusNote)} 学期第一周周一按 ${esc(state.snap.term.startLabel)} 计算，没有写死在课表格子里。</p>
  `;
}

function viewLegal(kind) {
  const terms = kind === "privacy";
  const title = terms ? "隐私政策" : "服务条款";
  const body = terms
    ? "这个预览只在你的浏览器里使用一份已经导出的学业快照，用来显示课表、学分和流程状态。它不把密码发到任何服务器，也不保存密码。证件号、电话和住址被排除在快照之外。你可以在设置里清掉本机偏好，或退出登录。"
    : "化研助手不是学校官方客户端。课表、成绩和流程以研究生管理系统为准。不要用它自动抢课、代选或批量尝试。选课、退选在正式版本里也必须由你本人确认。";
  return `${nav(title, "#/login")}<div class="card"><p style="margin:0;line-height:1.7;font-size:15px">${body}</p></div><p class="fine">更新于 ${esc(state.snap.updatedLabel)}。正式上架前需要换成完整文本。</p>`;
}

function dialog() {
  const logout = state.confirm === "logout";
  return `
    <div class="dialog-mask" data-act="confirm-no">
      <div class="dialog" data-act="stop" role="dialog" aria-modal="true">
        <h3>${logout ? "退出登录？" : "清理本机偏好？"}</h3>
        <p>${logout ? "需要重新输入验证码才能回来。记住的学号会留下，密码不会。" : "提醒开关和课程颜色会恢复默认。登录状态和快照还在。"}</p>
        <div class="actions">
          <button class="btn" type="button" data-act="confirm-no">取消</button>
          <button class="btn ${logout ? "danger" : "primary"}" type="button" data-act="confirm-ok">${logout ? "退出" : "清除"}</button>
        </div>
      </div>
    </div>
  `;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  return `${(bytes / 1024).toFixed(1)} KB`;
}

function bodyFor(route) {
  const page = route.parts[0];
  if (page === "start") return viewStart();
  if (page === "guide") return viewGuide();
  if (page === "login") return viewLogin();
  if (page === "legal") return viewLegal(route.parts[1]);
  if (page === "home") return viewHome();
  if (page === "timetable") return viewTimetable();
  if (page === "course") return viewCourse(route.parts[1]);
  if (page === "online") return viewOnline();
  if (page === "services") return viewServices();
  if (page === "group") return viewGroup(route.parts[1]);
  if (page === "webview") return viewWebview();
  if (page === "me") return viewMe();
  if (page === "progress") return viewProgress();
  if (page === "grades") return viewGrades();
  if (page === "exams") return viewExams();
  if (page === "notices") return viewNotices();
  if (page === "eval") return viewEval();
  if (page === "selected") return viewSelected();
  if (page === "apps") return viewApps();
  if (page === "profile") return viewProfile();
  if (page === "settings") return route.parts[1] ? viewSettingsSub(route.parts[1]) : viewSettings();
  return viewHome();
}

let lastKey = "";
function render() {
  const route = gate(parseHash());
  const key = `${route.path}?${route.query}`;
  const scroller = document.querySelector(".screen");
  const prevTop = scroller ? scroller.scrollTop : 0;
  const activeId = document.activeElement ? document.activeElement.id : "";
  const caret = document.activeElement ? document.activeElement.selectionStart : null;
  app.innerHTML = shell(route, bodyFor(route));
  const next = document.querySelector(".screen");
  if (next && key === lastKey) next.scrollTop = prevTop;
  lastKey = key;
  if (activeId) {
    const el = document.getElementById(activeId);
    if (el) {
      el.focus();
      if (typeof caret === "number" && el.setSelectionRange) {
        try { el.setSelectionRange(caret, caret); } catch { /* 数字输入框在部分浏览器不能设光标 */ }
      }
    }
  }
}

function onClick(event) {
  if (ignoreClick) {
    ignoreClick = false;
    event.preventDefault();
    return;
  }
  const el = event.target.closest("[data-act]");
  if (!el || !app.contains(el)) return;
  const act = el.dataset.act;
  if (act === "stop") {
    event.stopPropagation();
    return;
  }
  if (act === "go") go(el.dataset.href);
  else if (act === "back") back(el.dataset.fallback || "#/home");
  else if (act === "skip") {
    localStorage.setItem("buct_onboarded", "1");
    go("#/login");
  } else if (act === "sheet") {
    state.sheet = el.dataset.id;
    render();
  } else if (act === "close-sheet") {
    state.sheet = null;
    render();
  } else if (act === "week") {
    state.week = clampWeek(state.week + Number(el.dataset.delta));
    render();
  } else if (act === "today") {
    state.week = clampWeek(currentWeek());
    render();
  } else if (act === "captcha") {
    refreshCaptcha();
    state.login.code = "";
    render();
  } else if (act === "toggle-pwd") {
    state.login.showPwd = !state.login.showPwd;
    render();
  } else if (act === "forgot") toast("请到学校研究生系统找回密码。这里不保存密码。");
  else if (act === "ics") exportIcs(el.dataset.id);
  else if (act === "ics-all") exportIcs();
  else if (act === "remind") toggleCourseRemind(el.dataset.id);
  else if (act === "setting") {
    const key = el.dataset.setting;
    state.settings[key] = !state.settings[key];
    saveSettings();
    render();
  } else if (act === "week-start") {
    state.settings.weekStart = state.settings.weekStart === "mon" ? "sun" : "mon";
    saveSettings();
    render();
  } else if (act === "color") {
    state.settings.colors[el.dataset.name] = el.dataset.color;
    saveSettings();
    render();
  } else if (act === "logout") {
    state.confirm = "logout";
    render();
  } else if (act === "clear") {
    state.confirm = "clear";
    render();
  } else if (act === "confirm-no") {
    state.confirm = null;
    render();
  } else if (act === "confirm-ok") confirmOk();
  else if (act === "service") openService(el.dataset.path, el.dataset.native, el.dataset.title);
  else if (act === "filter") {
    state.filter = el.dataset.filter;
    render();
  }
}

function confirmOk() {
  if (state.confirm === "logout") {
    sessionStorage.removeItem("buct_session");
    state.login.pwd = "";
    state.login.code = "";
    state.login.error = "";
    state.sheet = null;
    state.confirm = null;
    refreshCaptcha();
    go("#/login");
    return;
  }
  const sid = localStorage.getItem("buct_sid");
  localStorage.removeItem("buct_settings");
  state.settings = defaultSettings();
  if (sid) localStorage.setItem("buct_sid", sid);
  state.confirm = null;
  toast("本机偏好已清除");
}

function openService(path, native, title) {
  if (native) go(`#/${native}`);
  else go(`#/webview?path=${encodeURIComponent(path)}&title=${encodeURIComponent(title || "学校网页")}`);
}

function onInput(event) {
  const target = event.target;
  if (target.id === "sid") state.login.sid = target.value;
  if (target.id === "pwd") state.login.pwd = target.value;
  if (target.id === "code") state.login.code = target.value;
  if (target.id === "q") {
    state.query = target.value;
    render();
  }
}

function onChange(event) {
  if (event.target.id === "remember") state.login.remember = event.target.checked;
  if (event.target.id === "agree") state.login.agree = event.target.checked;
}

function onSubmit(event) {
  event.preventDefault();
  const login = state.login;
  const sid = login.sid.trim();
  if (!sid || !login.pwd) {
    login.error = "请填写学号和密码";
    render();
    return;
  }
  if (login.code.trim() !== state.captcha) {
    login.fails += 1;
    refreshCaptcha();
    login.code = "";
    login.error = login.fails >= 3 ? "验证码错误。请核对学号和密码，不会锁定账号。" : "验证码错误";
    render();
    return;
  }
  if (sid !== state.snap.demoStudentId) {
    login.fails += 1;
    refreshCaptcha();
    login.code = "";
    login.error = `演示快照只有学号 ${state.snap.demoStudentId} 的数据`;
    render();
    return;
  }
  if (login.remember) localStorage.setItem("buct_sid", sid);
  else localStorage.removeItem("buct_sid");
  login.pwd = "";
  login.code = "";
  login.fails = 0;
  login.error = "";
  sessionStorage.setItem("buct_session", "1");
  localStorage.setItem("buct_onboarded", "1");
  const ret = sessionStorage.getItem("buct_return") || "#/home";
  sessionStorage.removeItem("buct_return");
  go(ret.startsWith("#/") ? ret : "#/home");
}

function activePeriods(snap) {
  const list = snap && snap.periods;
  if (!Array.isArray(list) || !list.length) return PERIODS;
  return list;
}

function boot(snap) {
  state.snap = snap;
  state.periods = activePeriods(snap);
  state.courses = snap.courses.map((course) => decorateCourse(course, state.periods));
  state.settings = loadSettings();
  state.login.sid = localStorage.getItem("buct_sid") || snap.demoStudentId;
  state.login.remember = true;
  state.week = clampWeek(Math.max(currentWeek(), 1));
  state.cacheBytes = new Blob([JSON.stringify(snap)]).size;
  refreshCaptcha();
  let swipe = null;
  app.addEventListener("pointerdown", (event) => {
    if (!event.target.closest(".tt")) return;
    swipe = { x: event.clientX, y: event.clientY };
  });
  app.addEventListener("pointerup", (event) => {
    if (!swipe || state.sheet) {
      swipe = null;
      return;
    }
    const dx = event.clientX - swipe.x;
    const dy = event.clientY - swipe.y;
    swipe = null;
    if (!location.hash.startsWith("#/timetable")) return;
    if (Math.abs(dx) < 56 || Math.abs(dx) < Math.abs(dy) * 1.4) return;
    ignoreClick = true;
    state.week = clampWeek(state.week + (dx < 0 ? 1 : -1));
    render();
  });
  app.addEventListener("pointercancel", () => { swipe = null; });
  app.addEventListener("click", onClick);
  app.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    const el = event.target.closest("[data-act]");
    if (!el || ["INPUT", "BUTTON", "A", "TEXTAREA"].includes(el.tagName)) return;
    event.preventDefault();
    el.click();
  });
  app.addEventListener("input", onInput);
  app.addEventListener("change", onChange);
  app.addEventListener("submit", onSubmit);
  window.addEventListener("hashchange", render);
  if (!location.hash || location.hash === "#" || location.hash === "#/") {
    if (!localStorage.getItem("buct_onboarded")) location.replace("#/start");
    else if (!sessionStorage.getItem("buct_session")) location.replace("#/login");
    else location.replace("#/home");
  }
  render();
  maybeRemind();
}

function loadSnapshot() {
  const liveUrl = new URL("../data/live.json", import.meta.url);
  const snapUrl = new URL("../data/snapshot.json", import.meta.url);
  return fetch(liveUrl).then((live) => {
    if (live.ok) return live.json();
    return fetch(snapUrl).then((response) => {
      if (!response.ok) throw new Error("快照没有加载");
      return response.json();
    });
  });
}

loadSnapshot()
  .then(boot)
  .catch((error) => {
    app.innerHTML = `<div class="screen">${empty("数据没有载入", error.message || "请从 web 目录打开这个页面")}</div>`;
  });

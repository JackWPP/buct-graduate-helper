import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import {
  blocksForWeek,
  buildIcs,
  decorateCourse,
  parseSjms,
  pickHero,
  sessionsOn,
  visibleWeekdays,
  weekIndex,
  weekMonday,
} from "./schedule.mjs";

const raw = fs.readFileSync(new URL("../data/snapshot.json", import.meta.url), "utf8");
const snap = JSON.parse(raw);
const courses = snap.courses.map(decorateCourse);

test("2026-11-03 is week 10 and that week starts on Nov 2", () => {
  assert.equal(weekIndex(new Date(2026, 10, 3, 11, 37), snap.term.start), 10);
  const monday = weekMonday(10, snap.term.start);
  assert.equal(monday.getMonth(), 10);
  assert.equal(monday.getDate(), 2);
});

test("tuesday of week 10 shows the two offline classes", () => {
  const names = blocksForWeek(courses, 10, false)
    .filter((block) => block.weekday === 1)
    .map((block) => block.name)
    .sort();
  assert.deepEqual(names, ["化学生物学导论", "数值分析"]);
});

test("online courses stay off the grid and sunday is hidden", () => {
  const blocks = blocksForWeek(courses, 10, true);
  assert.equal(blocks.some((block) => block.name.includes("科研伦理")), false);
  assert.equal(courses.filter((course) => course.online).length, 7);
  assert.equal(visibleWeekdays(courses).includes(6), false);
  assert.equal(visibleWeekdays(courses).includes(3), true);
});

test("numeric analysis splits across tuesday morning and saturday", () => {
  const course = courses.find((item) => item.name === "数值分析");
  const segments = parseSjms(course.sjms);
  assert.equal(segments.length, 2);
  assert.deepEqual(segments.map((seg) => seg.weekday), [1, 5]);
  assert.equal(segments[0].startTime, "08:00");
  assert.equal(segments[0].endTime, "09:35");
});

test("at 11:37 the next class is chemical biology", () => {
  const now = new Date(2026, 10, 3, 11, 37);
  const day = sessionsOn(courses, now, snap.term.start);
  const hero = pickHero(day.items, now);
  assert.equal(hero.kind, "next");
  assert.equal(hero.item.course.name, "化学生物学导论");
  assert.equal(hero.item.seg.startTime, "13:30");
});

test("ics exports offline courses only", () => {
  const ics = buildIcs(courses, snap.term.start);
  assert.match(ics, /SUMMARY:催化化学/);
  assert.match(ics, /RRULE:FREQ=WEEKLY/);
  assert.doesNotMatch(ics, /科研伦理/);
  assert.doesNotMatch(ics, /英文科技论文/);
});

test("timetable renders the full course name instead of a four-character hard wrap", () => {
  const app = fs.readFileSync(new URL("./app.js", import.meta.url), "utf8");
  assert.equal(app.includes("function blockTitle"), false);
  assert.match(app, /<strong>\$\{esc\(block\.name\)\}<\/strong>/);
});

test("credit buckets and snapshot stay free of contact data", () => {
  const selected = snap.credits.categories.reduce((sum, item) => sum + item.got, 0) + snap.credits.orphanCredits;
  assert.equal(selected, snap.credits.selected);
  assert.equal(snap.credits.selected, 28);
  assert.equal(snap.credits.required, 40);
  assert.equal(snap.credits.recorded, 0);
  for (const key of ["sfzh", "sjhm", "jtdh", "jtdz", "lxdh", "passwd", "email"]) {
    assert.equal(raw.includes(`"${key}"`), false, key);
  }
});

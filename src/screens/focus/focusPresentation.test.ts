import {
  createPeriodDraft,
  focusDateTime,
  formatClock,
  hasApps,
  isValidPeriod,
} from "./focusPresentation";

test("editing a routine preserves scope and never turns a cleared selection into all apps", () => {
  const period = {
    id: "p",
    name: "Evening",
    allApps: false,
    appIDs: ["a"],
    weekdays: [2],
    startMinutes: 1380,
    endMinutes: 60,
    isEnabled: false,
  };
  const draft = createPeriodDraft(period);
  draft.appIDs.pop();
  draft.weekdays.push(3);
  expect(period.appIDs).toEqual(["a"]);
  expect(period.weekdays).toEqual([2]);
  expect(draft.isEnabled).toBe(false);
  expect(hasApps(draft, [{ id: "a" }])).toBe(false);
  expect(hasApps({ ...draft, allApps: true }, [{ id: "a" }])).toBe(true);
  expect(hasApps(createPeriodDraft(), [{ id: "a" }])).toBe(false);
});

test("routine editor allows the 15-minute overnight boundary", () => {
  const draft = {
    ...createPeriodDraft(),
    name: "Evening",
    startMinutes: 1435,
    endMinutes: 10,
  };
  expect(isValidPeriod(draft)).toBe(true);
  expect(isValidPeriod({ ...draft, endMinutes: 9 })).toBe(false);
  expect(isValidPeriod({ ...draft, weekdays: [] })).toBe(false);
});

test("time and weekday copy use the language selected in Volition", () => {
  expect(formatClock(13 * 60 + 15, "en")).toMatch(/PM/i);
  expect(formatClock(13 * 60 + 15, "es")).toBe("13:15");
  expect(focusDateTime("2026-11-05T16:00:00Z", "zh")).toMatch(/周[四五]/);
});

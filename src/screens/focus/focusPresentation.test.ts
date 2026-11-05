import {
  createPeriodDraft,
  formatSchedule,
  parseTime,
  validatePeriodDraft,
} from "./focusPresentation";

test("period drafts copy selections and preserve paused state", () => {
  const period = {
    id: "p",
    name: "Evening",
    appIDs: ["a"],
    weekdays: [2],
    startMinutes: 1380,
    endMinutes: 60,
    isEnabled: false,
  };
  const draft = createPeriodDraft(period);
  draft.appIDs.push("b");
  draft.weekdays.push(3);
  expect(period.appIDs).toEqual(["a"]);
  expect(period.weekdays).toEqual([2]);
  expect(validatePeriodDraft(draft, "new").isEnabled).toBe(false);
  expect(formatSchedule(period)).toBe("Mon · 23:00–01:00 · next day");
});

test("time and period validation retain minimum and overnight semantics", () => {
  expect(parseTime("9:05")).toBe(545);
  expect(() => parseTime("24:00")).toThrow();
  const draft = createPeriodDraft();
  expect(() =>
    validatePeriodDraft({ ...draft, start: "09:00", end: "09:14" }, "id"),
  ).toThrow();
  expect(
    validatePeriodDraft({ ...draft, start: "23:55", end: "00:10" }, "id")
      .endMinutes,
  ).toBe(10);
  expect(() => validatePeriodDraft({ ...draft, weekdays: [] }, "id")).toThrow();
});

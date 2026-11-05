import { buildInsights } from "./insightsData";

const grant = (date: Date, minutes: number, appId = "a") => ({
  grantId: date.toISOString(),
  appId,
  date: date.toISOString(),
  minutes,
});

test("uses the same local calendar period for totals and chart, excluding future grants", () => {
  const now = new Date(2026, 2, 9, 15);
  const history = [
    grant(new Date(2026, 2, 9, 1), 5),
    grant(new Date(2026, 2, 8, 23), 10),
    grant(new Date(2026, 2, 9, 18), 20),
  ];
  const today = buildInsights(history, "today", now);
  expect(today.sessions).toBe(1);
  expect(today.minutes).toBe(5);
  expect(today.buckets.reduce((sum, bucket) => sum + bucket.minutes, 0)).toBe(
    5,
  );
  const week = buildInsights(history, "week", now);
  expect(week.sessions).toBe(2);
  expect(week.buckets.reduce((sum, bucket) => sum + bucket.minutes, 0)).toBe(
    15,
  );
});

test("buckets calendar days across daylight saving changes and groups apps", () => {
  const now = new Date(2026, 2, 9, 15);
  const data = buildInsights(
    [
      grant(new Date(2026, 2, 8, 23, 30), 12),
      grant(new Date(2026, 2, 9, 1), 8, "b"),
    ],
    "week",
    now,
  );
  expect(data.buckets.map((bucket) => bucket.minutes)).toEqual([
    0, 0, 0, 0, 0, 12, 8,
  ]);
  expect(data.apps.a).toEqual({ sessions: 1, minutes: 12 });
  expect(data.apps.b).toEqual({ sessions: 1, minutes: 8 });
});

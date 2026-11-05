import type { GrantsState } from "../../redux/grantsSlice";

export type InsightsPeriod = "today" | "week";

/** Groups allocated grants by local calendar time, never by measured app use. */
export function buildInsights(
  history: GrantsState["accessHistory"],
  period: InsightsPeriod,
  now: Date,
) {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  if (period === "week") start.setDate(start.getDate() - 6);
  const buckets =
    period === "today"
      ? ["12 AM", "6 AM", "12 PM", "6 PM"].map((label) => ({
          label,
          minutes: 0,
        }))
      : Array.from({ length: 7 }, (_, index) => {
          const date = new Date(start);
          date.setDate(date.getDate() + index);
          return {
            label: date.toLocaleDateString(undefined, { weekday: "short" }),
            minutes: 0,
          };
        });
  const apps: Record<string, { sessions: number; minutes: number }> = {};
  let sessions = 0;
  let minutes = 0;
  for (const grant of history) {
    const date = new Date(grant.date);
    if (!(date.getTime() >= start.getTime() && date.getTime() <= now.getTime()))
      continue;
    const index =
      period === "today"
        ? Math.floor(date.getHours() / 6)
        : buckets.findIndex((_, i) => {
            const day = new Date(start);
            day.setDate(day.getDate() + i);
            return (
              date.getFullYear() === day.getFullYear() &&
              date.getMonth() === day.getMonth() &&
              date.getDate() === day.getDate()
            );
          });
    const bucket = buckets[index];
    if (!bucket) continue;
    bucket.minutes += grant.minutes;
    sessions += 1;
    minutes += grant.minutes;
    const app = apps[grant.appId] ?? { sessions: 0, minutes: 0 };
    app.sessions += 1;
    app.minutes += grant.minutes;
    apps[grant.appId] = app;
  }
  return { sessions, minutes, buckets, apps, start };
}

import type { FocusPeriod } from "../../redux/focusSlice";

export type PeriodDraft = {
  id: string | null;
  name: string;
  start: string;
  end: string;
  weekdays: number[];
  appIDs: string[];
  isEnabled: boolean;
};
export const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
export function formatTime(minutes: number): string {
  return `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
}
export function parseTime(value: string): number {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!match) throw new Error("Use a time such as 09:00.");
  const hour = Number(match[1]),
    minute = Number(match[2]);
  if (hour > 23 || minute > 59) throw new Error("Enter a valid time.");
  return hour * 60 + minute;
}
export function createPeriodDraft(period?: FocusPeriod): PeriodDraft {
  return {
    id: period?.id ?? null,
    name: period?.name ?? "Focus time",
    start: formatTime(period?.startMinutes ?? 540),
    end: formatTime(period?.endMinutes ?? 600),
    weekdays: [...(period?.weekdays ?? [2, 3, 4, 5, 6])],
    appIDs: [...(period?.appIDs ?? [])],
    isEnabled: period?.isEnabled ?? true,
  };
}
export function validatePeriodDraft(
  draft: PeriodDraft,
  id: string,
): FocusPeriod {
  const startMinutes = parseTime(draft.start),
    endMinutes = parseTime(draft.end);
  if (
    !draft.name.trim() ||
    !draft.weekdays.length ||
    (endMinutes - startMinutes + 1440) % 1440 < 15
  )
    throw new Error(
      "Choose a name, weekdays, and a period of at least 15 minutes.",
    );
  return {
    id: draft.id ?? id,
    name: draft.name.trim(),
    appIDs: [...draft.appIDs],
    weekdays: [...draft.weekdays],
    startMinutes,
    endMinutes,
    isEnabled: draft.isEnabled,
  };
}
export function formatSchedule(period: FocusPeriod): string {
  const dayText = days
    .filter((_, index) => period.weekdays.includes(index + 1))
    .join(", ");
  return `${dayText} · ${formatTime(period.startMinutes)}–${formatTime(period.endMinutes)}${period.endMinutes <= period.startMinutes ? " · next day" : ""}`;
}
export function appSummary(
  ids: string[],
  apps: { id: string; name: string }[],
): string {
  if (!ids.length) return "All apps";
  return ids
    .map((id) => apps.find((app) => app.id === id)?.name ?? "Unavailable app")
    .join(", ");
}

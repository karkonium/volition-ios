import type {
  FocusOccurrence,
  FocusPeriod,
  FocusScope,
} from "../../redux/focusSlice";

export type PeriodDraft = Omit<FocusPeriod, "id" | "allApps"> & {
  id: string | null;
  allApps: boolean | null;
};
export const days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
export const weekdays = [2, 3, 4, 5, 6];
export const everyDay = [1, 2, 3, 4, 5, 6, 7];

export function createPeriodDraft(period?: FocusPeriod): PeriodDraft {
  return {
    id: period?.id ?? null,
    name: period?.name ?? "",
    startMinutes: period?.startMinutes ?? 540,
    endMinutes: period?.endMinutes ?? 600,
    weekdays: [...(period?.weekdays ?? weekdays)],
    appIDs: [...(period?.appIDs ?? [])],
    allApps: period?.allApps ?? null,
    isEnabled: period?.isEnabled ?? true,
  };
}

export function hasApps(
  scope: { allApps: boolean | null; appIDs: string[] },
  apps: { id: string }[],
): scope is FocusScope {
  return (
    scope.allApps !== null &&
    (scope.allApps
      ? apps.length > 0
      : apps.some(({ id }) => scope.appIDs.includes(id)))
  );
}

export function isValidPeriod(draft: PeriodDraft): boolean {
  return (
    Boolean(draft.name.trim()) &&
    draft.weekdays.length > 0 &&
    (draft.endMinutes - draft.startMinutes + 1440) % 1440 >= 15
  );
}

export function formatClock(minutes: number, locale?: string): string {
  return new Intl.DateTimeFormat(locale, {
    hour: "numeric",
    minute: "2-digit",
    timeZone: "UTC",
  }).format(new Date(minutes * 60000));
}

export function focusTime(date: string, locale?: string): string {
  return new Intl.DateTimeFormat(locale, {
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(date));
}

export function focusDateTime(date: string, locale?: string): string {
  return new Intl.DateTimeFormat(locale, {
    weekday: "short",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(date));
}

export function focusName(reason: FocusOccurrence, quickFocus: string): string {
  return reason.name ?? quickFocus;
}

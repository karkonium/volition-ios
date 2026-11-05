import {
  emptyFocus,
  type FocusOccurrence,
  type FocusScope,
  type FocusState,
} from "../redux/focusSlice";

function normalizeScope<T extends FocusScope>(scope: T): T {
  return {
    ...scope,
    allApps: scope.allApps ?? scope.appIDs.length === 0,
    appIDs: scope.appIDs.map((id) => id.toLowerCase()),
  };
}

/** Native owns time and scope calculations. Normalize UUIDs at the bridge. */
export function readFocusSnapshot(json: string): FocusState {
  const value = JSON.parse(json) as FocusState;
  const occurrence = (item: FocusOccurrence): FocusOccurrence => ({
    ...item,
    sourceId: item.sourceId.toLowerCase(),
    appIDs: item.appIDs.map((id) => id.toLowerCase()),
    exceptedAppIDs: item.exceptedAppIDs.map((id) => id.toLowerCase()),
  });
  return {
    ...emptyFocus,
    ...value,
    periods: value.periods.map((item) =>
      normalizeScope({ ...item, id: item.id.toLowerCase() }),
    ),
    session: value.session
      ? normalizeScope({ ...value.session, id: value.session.id.toLowerCase() })
      : null,
    preferences: value.preferences ? normalizeScope(value.preferences) : null,
    active: (value.active ?? []).map(occurrence),
    upcoming: (value.upcoming ?? []).map(occurrence),
  };
}

export function focusReasons(
  focus: FocusState,
  appId: string,
  now: number,
): FocusOccurrence[] {
  return focus.active.filter(
    (item) =>
      item.appIDs.includes(appId) &&
      !item.exceptedAppIDs.includes(appId) &&
      Date.parse(item.startsAt) <= now &&
      now < Date.parse(item.endsAt),
  );
}

export function nextFocusStart(
  focus: FocusState,
  appId: string,
  now: number,
): FocusOccurrence | undefined {
  return focus.upcoming.find(
    (item) => item.appIDs.includes(appId) && Date.parse(item.startsAt) >= now,
  );
}

export function focusAccessLimit(
  focus: FocusState,
  appId: string,
  now: number,
) {
  if (focusReasons(focus, appId, now).length) return { minutes: 0 };
  const next = nextFocusStart(focus, appId, now);
  return next
    ? {
        minutes: Math.floor((Date.parse(next.startsAt) - now) / 60000),
        until: next.startsAt,
      }
    : { minutes: Infinity };
}

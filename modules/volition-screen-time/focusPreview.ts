import {
  emptyFocus,
  type FocusCommand,
  type FocusOccurrence,
  type FocusScope,
} from "../../src/redux/focusSlice";

// Preview uses synthetic profiles only. Production dates and enforcement come from Swift.
export function createFocusPreview(now: () => number = Date.now) {
  let focus = { ...emptyFocus, revision: 0 };
  const revisions = new Map<string, number>();
  const exceptions = new Map<string, Set<string>>();

  function snapshot(apps: string[]) {
    const observedAt = new Date(now());
    const current = observedAt.getTime();
    const active: FocusOccurrence[] = [];
    const upcoming: FocusOccurrence[] = [];
    function add(
      scope: FocusScope,
      sourceId: string,
      start: Date,
      end: Date,
      kind: FocusOccurrence["kind"],
      name?: string,
    ) {
      const appIDs = apps.filter(
        (app) => scope.allApps || scope.appIDs.includes(app),
      );
      if (!appIDs.length || end <= observedAt || end <= start) return;
      const id = `${sourceId}:${revisions.get(sourceId) ?? 0}:${start.getTime()}`;
      (start.getTime() > current ? upcoming : active).push({
        id,
        sourceId,
        kind,
        name,
        appIDs,
        exceptedAppIDs: [...(exceptions.get(id) ?? [])].filter((app) =>
          appIDs.includes(app),
        ),
        startsAt: start.toISOString(),
        endsAt: end.toISOString(),
      });
    }
    for (const period of focus.periods) {
      if (!period.isEnabled) continue;
      for (let offset = -1; offset <= 7; offset++) {
        const day = new Date(observedAt);
        day.setDate(day.getDate() + offset);
        if (!period.weekdays.includes(day.getDay() + 1)) continue;
        const time = (minutes: number, nextDay: boolean) =>
          new Date(
            day.getFullYear(),
            day.getMonth(),
            day.getDate() + Number(nextDay),
            0,
            minutes,
          );
        const start = time(period.startMinutes, false);
        const end = time(
          period.endMinutes,
          period.endMinutes < period.startMinutes,
        );
        add(period, period.id, start, end, "routine", period.name);
        if (start > observedAt && end > start) break;
      }
    }
    const session = focus.session;
    const sessionEnd =
      session && new Date(Date.parse(session.start) + session.minutes * 60000);
    if (session && sessionEnd && sessionEnd > observedAt) {
      add(session, session.id, new Date(session.start), sessionEnd, "session");
    }
    active.sort((a, b) => a.endsAt.localeCompare(b.endsAt));
    upcoming.sort((a, b) => a.startsAt.localeCompare(b.startsAt));
    return {
      ...focus,
      session: sessionEnd && sessionEnd > observedAt ? session : null,
      observedAt: observedAt.toISOString(),
      active,
      upcoming,
      nextRefreshAt:
        [active[0]?.endsAt, upcoming[0]?.startsAt].filter(Boolean).sort()[0] ??
        null,
    };
  }

  function apply(command: FocusCommand, apps: string[]) {
    const current = snapshot(apps);
    const fail = (code: string): never => {
      throw Object.assign(new Error(code), { code });
    };
    if (
      "expectedRevision" in command &&
      command.expectedRevision !== focus.revision
    )
      fail("FOCUS_STALE");
    const coversApps = (scope: FocusScope) =>
      apps.some((app) => scope.allApps || scope.appIDs.includes(app));
    switch (command.kind) {
      case "saveRoutine": {
        const { period } = command;
        if (period.isEnabled && !period.allApps && !coversApps(period))
          fail("FOCUS_APPS");
        if (
          !focus.periods.some(({ id }) => id === period.id) &&
          period.isEnabled &&
          focus.periods.filter(({ isEnabled }) => isEnabled).length >= 18
        )
          fail("FOCUS_REGISTRATION");
        const exists = focus.periods.some(({ id }) => id === period.id);
        focus.periods = exists
          ? focus.periods.map((item) => (item.id === period.id ? period : item))
          : [...focus.periods, period];
        revisions.set(period.id, focus.revision + 1);
        break;
      }
      case "deleteRoutine":
        focus.periods = focus.periods.filter(
          ({ id }) => id !== command.sourceId,
        );
        break;
      case "savePreferences":
        if (!coversApps(command.preferences)) fail("FOCUS_APPS");
        focus.preferences = command.preferences;
        break;
      case "startSession":
        if (current.session) return current;
        if (!focus.preferences || !coversApps(focus.preferences))
          fail("FOCUS_APPS");
        focus.session = {
          ...focus.preferences!,
          id: `preview-focus-${focus.revision}`,
          start: new Date(now()).toISOString(),
        };
        break;
      case "endSession":
        if (command.sourceId !== current.session?.id) fail("FOCUS_STALE");
        focus.session = null;
        break;
      case "exceptApp": {
        const occurrence = current.active.find(
          ({ id, appIDs, exceptedAppIDs }) =>
            id === command.occurrenceID &&
            appIDs.includes(command.appID) &&
            !exceptedAppIDs.includes(command.appID),
        );
        if (!occurrence) return fail("FOCUS_STALE");
        const skipped = exceptions.get(occurrence.id) ?? new Set<string>();
        skipped.add(command.appID);
        exceptions.set(occurrence.id, skipped);
        break;
      }
    }
    focus.revision++;
    return snapshot(apps);
  }
  return { snapshot, apply };
}

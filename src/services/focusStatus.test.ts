import { createFocusPreview } from "../../modules/volition-screen-time/focusPreview";
import reducer, { focusActions, type FocusPeriod } from "../redux/focusSlice";
import {
  focusAccessLimit,
  focusReasons,
  readFocusSnapshot,
} from "./focusStatus";

const apps = ["a", "b"];
const monday = new Date(2026, 10, 2, 23, 0).getTime();
const overnight: FocusPeriod = {
  id: "bedtime",
  name: "Bedtime",
  weekdays: [2],
  allApps: true,
  appIDs: [],
  startMinutes: 1380,
  endMinutes: 60,
  isEnabled: true,
};

test("the bridge preserves a legacy all-app scope and a modern empty selected scope", () => {
  const snapshot = readFocusSnapshot(
    JSON.stringify({
      periods: [
        { ...overnight, id: "ABC", allApps: undefined },
        { ...overnight, id: "DEF", allApps: false },
        { ...overnight, id: "GHI", allApps: undefined, appIDs: ["A"] },
      ],
      session: {
        id: "SESSION",
        appIDs: [],
        start: new Date(monday),
        minutes: 25,
      },
    }),
  );
  expect(
    snapshot.periods.map(({ id, allApps, appIDs }) => [id, allApps, appIDs]),
  ).toEqual([
    ["abc", true, []],
    ["def", false, []],
    ["ghi", false, ["a"]],
  ]);
  expect(snapshot.session).toMatchObject({ id: "session", allApps: true });
});

test("each overlapping reason needs its own exception and an edited occurrence rejects old requests", () => {
  let now = monday;
  const bridge = createFocusPreview(() => now);
  bridge.apply(
    { kind: "saveRoutine", period: overnight, expectedRevision: 0 },
    apps,
  );
  bridge.apply(
    {
      kind: "savePreferences",
      preferences: { allApps: true, appIDs: [], minutes: 25 },
      expectedRevision: 1,
    },
    apps,
  );
  const started = bridge.apply({ kind: "startSession" }, apps);
  const routine = started.active.find(({ kind }) => kind === "routine")!;
  expect(focusReasons(started, "a", now)).toHaveLength(2);
  const partial = bridge.apply(
    { kind: "exceptApp", occurrenceID: routine.id, appID: "a" },
    apps,
  );
  const remaining = focusReasons(partial, "a", now);
  expect(remaining.map(({ kind }) => kind)).toEqual(["session"]);
  expect(focusReasons(partial, "b", now)).toHaveLength(2);
  const finished = bridge.apply(
    { kind: "exceptApp", occurrenceID: remaining[0]!.id, appID: "a" },
    apps,
  );
  expect(focusReasons(finished, "a", now)).toHaveLength(0);
  const edited = bridge.apply(
    {
      kind: "saveRoutine",
      expectedRevision: finished.revision,
      period: { ...overnight, endMinutes: 90 },
    },
    apps,
  );
  expect(focusReasons(edited, "a", now)).toHaveLength(1);
  expect(() =>
    bridge.apply(
      { kind: "exceptApp", occurrenceID: routine.id, appID: "a" },
      apps,
    ),
  ).toThrow("FOCUS_STALE");
  now += 2 * 3600000;
  expect(focusReasons(bridge.snapshot(apps), "a", now)).toHaveLength(1);
  now += 30 * 60000;
  expect(focusReasons(bridge.snapshot(apps), "a", now)).toHaveLength(0);
});

test("a failed routine admission preserves existing state", () => {
  const bridge = createFocusPreview(() => monday);
  for (let i = 0; i < 18; i++) {
    bridge.apply(
      {
        kind: "saveRoutine",
        expectedRevision: i,
        period: { ...overnight, id: String(i) },
      },
      apps,
    );
  }
  const before = bridge.snapshot(apps);
  expect(() =>
    bridge.apply(
      { kind: "saveRoutine", expectedRevision: 18, period: overnight },
      apps,
    ),
  ).toThrow("FOCUS_REGISTRATION");
  expect(bridge.snapshot(apps)).toEqual(before);
});

test("foreground refresh adopts a system session and ignores an older response", () => {
  let now = monday - 180000;
  const bridge = createFocusPreview(() => now);
  const prior = bridge.apply(
    { kind: "saveRoutine", period: overnight, expectedRevision: 0 },
    apps,
  );
  expect(focusAccessLimit(prior, "a", now)).toMatchObject({ minutes: 3 });
  const configured = bridge.apply(
    {
      kind: "savePreferences",
      preferences: { allApps: true, appIDs: [], minutes: 25 },
      expectedRevision: prior.revision,
    },
    apps,
  );
  const state = reducer(undefined, focusActions.synced(configured));
  const started = bridge.apply({ kind: "startSession" }, apps);
  now += 1000;
  expect(bridge.apply({ kind: "startSession" }, apps).session).toEqual(
    started.session,
  );
  const refreshed = reducer(state, focusActions.synced(started));
  expect(focusAccessLimit(refreshed, "a", now)).toEqual({ minutes: 0 });
  expect(reducer(refreshed, focusActions.synced(prior))).toEqual(refreshed);
});

import { parseLegacyHistory } from "./legacyImport";
test("preserves confirmed allocated grants, private outcomes, and check-in cooldown", () => {
  const result = parseLegacyHistory(
    {
      lastEmotionQuestionAt: "2026-11-03T05:00:00Z",
      recordedAccess: [
        {
          appID: "a",
          grantID: "g",
          date: "2026-11-03T04:00:00Z",
          expiresAt: "2026-11-03T04:05:00Z",
          decision: "approve",
        },
      ],
      recordedActivity: [
        {
          id: "log",
          appID: "a",
          date: "2026-11-03T04:00:00Z",
          message: "hello",
          outcome: "unlocked",
          modelDecision: "approve",
          grantID: "g",
          experienceRating: "helpful",
        },
      ],
      savedReflections: [
        {
          appID: "a",
          createdAt: "2026-11-03T04:00:00Z",
          deadline: "2026-11-03T04:00:10Z",
          emotion: "boredom",
        },
      ],
    },
    ["a"],
  );
  expect(result.accessHistory).toEqual([
    { grantId: "g", appId: "a", date: "2026-11-03T04:00:00Z", minutes: 5 },
  ]);
  expect(result.entries[0]).toMatchObject({
    outcome: "approved",
    feedback: "helpful",
  });
  expect(result.lastCheckInAt).toBe("2026-11-03T05:00:00Z");
  expect(result.pauseAttempts).toHaveLength(1);
});
test("legacy pending outcomes are interrupted and unconfirmed approvals never count as access", () => {
  const result = parseLegacyHistory(
    {
      recordedAccess: [
        { appID: "a", date: "2026-11-03T04:00:00Z", decision: "approve" },
      ],
      recordedActivity: [
        {
          id: "log",
          date: "2026-11-03T04:00:00Z",
          message: "request",
          outcome: "pending",
        },
      ],
    },
    ["a"],
  );
  expect(result.accessHistory).toHaveLength(0);
  expect(result.entries[0]?.outcome).toBe("interrupted");
});
test("legacy enforced waits cover saved apps", () => {
  expect(
    parseLegacyHistory({ cooldownUntil: "2026-11-03T05:10:00Z" }, ["a", "b"])
      .hardWaits,
  ).toEqual({ a: "2026-11-03T05:10:00Z", b: "2026-11-03T05:10:00Z" });
});

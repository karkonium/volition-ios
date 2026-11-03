import { validateDecision } from "./decision";
const base = {
  reply: "Consider your intention.",
  decision: "ask",
  unlock_minutes: null,
  wait_minutes: null,
  pause_seconds: null,
  block_minutes: null,
};
test.each([
  "ask",
  "deny",
  "approve",
  "wait",
  "pause",
  "deal",
  "choice",
  "override",
  "urgent",
  "frustration",
])("accepts %s with matching terms", (decision) => {
  const unlock = [
    "approve",
    "pause",
    "deal",
    "choice",
    "override",
    "urgent",
    "frustration",
  ].includes(decision);
  expect(
    validateDecision({
      ...base,
      decision,
      unlock_minutes: unlock ? 60 : null,
      wait_minutes: decision === "wait" ? 5 : null,
      pause_seconds: ["pause", "choice"].includes(decision) ? 1800 : null,
      block_minutes: ["deal", "choice", "override"].includes(decision)
        ? 1440
        : null,
    }).decision,
  ).toBe(decision);
});
test.each([0, 61, 1.5, "5", NaN])("rejects bad unlock %s", (unlock_minutes) =>
  expect(() =>
    validateDecision({ ...base, decision: "approve", unlock_minutes }),
  ).toThrow(),
);
test.each([
  { decision: "ask", unlock_minutes: 5 },
  { decision: "pause", unlock_minutes: 5, pause_seconds: 9 },
  { decision: "deal", unlock_minutes: 5, block_minutes: 1441 },
  { decision: "wait", wait_minutes: 6 },
  { decision: "urgent", unlock_minutes: 2, block_minutes: 30 },
  { reply: " " },
  { extra: true },
])("rejects malformed terms", (patch) =>
  expect(() => validateDecision({ ...base, ...patch })).toThrow(),
);

import {
  checkInDue,
  recommendedPauseSeconds,
  validateEmotion,
} from "./policy";
import reducer from "../redux/grantsSlice";
test("global check-in boundary is exactly 120 seconds", () => {
  expect(checkInDue(new Date(0).toISOString(), 119999)).toBe(false);
  expect(checkInDue(new Date(0).toISOString(), 120000)).toBe(true);
});
test("pause progression only uses this app and recent starts", () => {
  const state = {
    ...reducer(undefined, { type: "init" }),
    pauseAttempts: Array.from({ length: 10 }, () => ({
      appId: "a",
      startedAt: new Date(100).toISOString(),
    })),
  };
  expect(recommendedPauseSeconds(state, "a", 1000)).toBe(60);
  expect(recommendedPauseSeconds(state, "b", 1000)).toBe(10);
  expect(recommendedPauseSeconds(state, "a", 86400200)).toBe(10);
});
test("emotions accept trimmed Unicode and reject oversized text", () => {
  expect(validateEmotion("  tired  ")).toBe("tired");
  expect(() => validateEmotion(" ")).toThrow();
  expect(() => validateEmotion("x".repeat(161))).toThrow();
});

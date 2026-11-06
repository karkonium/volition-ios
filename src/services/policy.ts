import type { GrantsState } from "../redux/grantsSlice";
export function recommendedPauseSeconds(
  state: GrantsState,
  appId: string,
  now: number,
): number {
  const attempts = state.pauseAttempts.filter(
    (item) =>
      item.appId === appId &&
      Date.parse(item.startedAt) > now - 86400000 &&
      Date.parse(item.startedAt) <= now,
  ).length;
  const broken = state.commitments.filter(
    (item) =>
      item.appId === appId &&
      item.overriddenAt &&
      Date.parse(item.overriddenAt) > now - 86400000,
  ).length;
  return Math.min(1800, 10 + Math.min(5, attempts) * 10 + broken * 60);
}
export function checkInDue(last: string | null, now: number): boolean {
  return !last || now - Date.parse(last) >= 120000;
}
export function validateEmotion(value: string): string {
  const text = value.trim();
  if (!text || [...text].length > 160) throw new Error("Use 1–160 characters.");
  return text;
}

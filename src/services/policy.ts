import type { FocusState } from "../redux/focusSlice";
import type { GrantsState } from "../redux/grantsSlice";
export function focusProtects(
  focus: FocusState,
  appId: string,
  now: number,
): boolean {
  const session = focus.session;
  if (
    session &&
    Date.parse(session.start) <= now &&
    Date.parse(session.start) + session.minutes * 60000 > now &&
    (!session.appIDs.length || session.appIDs.includes(appId))
  )
    return true;
  const date = new Date(now);
  const minute = date.getHours() * 60 + date.getMinutes();
  return focus.periods.some((period) => {
    if (
      !period.isEnabled ||
      (period.appIDs.length && !period.appIDs.includes(appId))
    )
      return false;
    const overnight = period.endMinutes <= period.startMinutes;
    const owner = new Date(date);
    if (overnight && minute < period.endMinutes)
      owner.setDate(owner.getDate() - 1);
    return (
      period.weekdays.includes(owner.getDay() + 1) &&
      (overnight
        ? minute >= period.startMinutes || minute < period.endMinutes
        : minute >= period.startMinutes && minute < period.endMinutes)
    );
  });
}
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

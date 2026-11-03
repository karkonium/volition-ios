import type {
  ActivityLogEntry,
  ActivityOutcome,
} from "../redux/activityLogSlice";
import type {
  GrantsState,
  PauseAttempt,
  Reflection,
} from "../redux/grantsSlice";
import { decisions, type CoachDecision } from "./decision";
export function legacyObject(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}
const list = (value: unknown): Record<string, unknown>[] =>
  Array.isArray(value) ? value.map(legacyObject) : [];
const date = (value: unknown): string | undefined =>
  typeof value === "string" && Number.isFinite(Date.parse(value))
    ? value
    : undefined;
const text = (value: unknown): string | undefined =>
  typeof value === "string" ? value : undefined;
export interface LegacyHistory {
  entries: ActivityLogEntry[];
  accessHistory: GrantsState["accessHistory"];
  lastCheckInAt: string | null;
  pauseAttempts: PauseAttempt[];
  reflections: Reflection[];
  hardWaits: Record<string, string>;
}
export function parseLegacyHistory(
  value: unknown,
  appIds: readonly string[],
): LegacyHistory {
  const history = legacyObject(value);
  const result: LegacyHistory = {
    entries: [],
    accessHistory: [],
    lastCheckInAt: date(history.lastEmotionQuestionAt) ?? null,
    pauseAttempts: [],
    reflections: [],
    hardWaits: {},
  };
  const globalWait = date(history.cooldownUntil);
  if (globalWait) for (const id of appIds) result.hardWaits[id] = globalWait;
  for (const event of list(history.recordedAccess)) {
    const appId = text(event.appID)?.toLowerCase(),
      grantId = text(event.grantID)?.toLowerCase(),
      started = date(event.date),
      expires = date(event.expiresAt),
      wait = date(event.waitUntil);
    if (
      appId &&
      wait &&
      Date.parse(wait) > Date.parse(result.hardWaits[appId] ?? "1970-01-01")
    )
      result.hardWaits[appId] = wait;
    if (appId && grantId && started && expires) {
      const minutes = Math.round(
        (Date.parse(expires) - Date.parse(started)) / 60000,
      );
      if (minutes >= 1 && minutes <= 60)
        result.accessHistory.push({ grantId, appId, date: started, minutes });
    }
  }
  const outcomes: Record<string, ActivityOutcome> = {
    unlocked: "approved",
    pending: "interrupted",
    asked: "asked",
    denied: "denied",
    wait: "wait",
    failed: "failed",
    cancelled: "cancelled",
    unconfirmed: "unconfirmed",
    interrupted: "interrupted",
    blocked_by_wait: "blockedByWait",
    already_unlocked: "alreadyUnlocked",
    reflection: "reflection",
    dealOffered: "dealOffered",
    dealDeclined: "dealDeclined",
    removalRequested: "removalRequested",
    app_selection_required: "selectionRequired",
  };
  for (const entry of list(history.recordedActivity)) {
    const id = text(entry.id),
      created = date(entry.date),
      message = text(entry.message);
    if (!id || !created || message === undefined)
      throw new Error("Private history could not be migrated.");
    const decision = decisions.includes(entry.modelDecision as CoachDecision)
      ? (entry.modelDecision as CoachDecision)
      : "ask";
    const rating = entry.experienceRating;
    const feedback =
      rating === "helpful" || rating === "neutral" || rating === "annoying"
        ? rating
        : undefined;
    result.entries.push({
      id,
      date: created,
      message,
      appId: text(entry.appID)?.toLowerCase(),
      appName: text(entry.appName),
      coachResponse: text(entry.coachResponse),
      decision,
      outcome: outcomes[String(entry.outcome)] ?? "unconfirmed",
      grantId: text(entry.grantID)?.toLowerCase(),
      ...(feedback ? { feedback } : {}),
    });
  }
  for (const item of list(history.savedReflections)) {
    const appId = text(item.appID)?.toLowerCase(),
      created = date(item.createdAt);
    if (!appId || !created) continue;
    if (
      date(item.deadline) &&
      item.blockMinutes === undefined &&
      item.openedWithoutIntervention !== true
    )
      result.pauseAttempts.push({ appId, startedAt: created });
    const emotion =
      text(item.customEmotion) ??
      (item.emotion === "skip" ? null : text(item.emotion));
    if (emotion !== undefined)
      result.reflections.push({ appId, date: created, emotion });
    if (
      item.checkInRequested === true &&
      (!result.lastCheckInAt ||
        Date.parse(created) > Date.parse(result.lastCheckInAt))
    )
      result.lastCheckInAt = created;
  }
  return result;
}

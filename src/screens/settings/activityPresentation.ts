import type { ActivityOutcome } from "../../redux/activityLogSlice";

const labels: Record<ActivityOutcome, string> = {
  pending: "Pending",
  approved: "Access granted",
  wait: "Delay",
  denied: "Request declined",
  interrupted: "Interrupted",
  expired: "Access ended",
  earlyEnded: "Access ended early",
  keptLocked: "Kept locked",
  removed: "App removed",
  asked: "Request made",
  failed: "Access failed",
  cancelled: "Cancelled",
  unconfirmed: "Access unconfirmed",
  blockedByWait: "Blocked by wait",
  alreadyUnlocked: "Already unlocked",
  reflection: "Check-in",
  dealOffered: "Deal offered",
  dealDeclined: "Deal declined",
  removalRequested: "Removal requested",
  selectionRequired: "App selection needed",
};
export function outcomeLabel(outcome: ActivityOutcome): string {
  return labels[outcome];
}

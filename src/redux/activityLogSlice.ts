import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
import type { CoachDecision } from "../services/decision";
export type ActivityOutcome =
  | "pending"
  | "approved"
  | "wait"
  | "denied"
  | "interrupted"
  | "expired"
  | "earlyEnded"
  | "keptLocked"
  | "removed"
  | "asked"
  | "failed"
  | "cancelled"
  | "unconfirmed"
  | "blockedByWait"
  | "alreadyUnlocked"
  | "reflection"
  | "dealOffered"
  | "dealDeclined"
  | "removalRequested"
  | "selectionRequired";
export type OutcomeFeedback = "helpful" | "neutral" | "annoying";
export interface ActivityLogEntry {
  id: string;
  appId?: string;
  appName?: string;
  date: string;
  message: string;
  coachResponse?: string;
  decision: CoachDecision | null;
  outcome: ActivityOutcome;
  feedback?: OutcomeFeedback;
  grantId?: string;
  feedbackSignal?: "high_frustration";
}
const slice = createSlice({
  name: "activityLog",
  initialState: {
    entries: [] as ActivityLogEntry[],
    removalLedger: [] as {
      appId: string;
      date: string;
      reason: string;
      disposition: string;
      feedbackSignal: "high_frustration";
    }[],
  },
  reducers: {
    added(state, action: PayloadAction<ActivityLogEntry>) {
      state.entries.push(action.payload);
    },
    adviceRecorded(
      state,
      action: PayloadAction<{
        id: string;
        decision: CoachDecision;
        coachResponse: string;
      }>,
    ) {
      const entry = state.entries.find((item) => item.id === action.payload.id);
      if (entry) {
        entry.decision = action.payload.decision;
        entry.coachResponse = action.payload.coachResponse;
      }
    },
    outcomeRecorded(
      state,
      action: PayloadAction<{
        id: string;
        outcome: ActivityOutcome;
        grantId?: string;
        feedbackSignal?: "high_frustration";
      }>,
    ) {
      const entry = state.entries.find((item) => item.id === action.payload.id);
      if (entry) {
        entry.outcome = action.payload.outcome;
        entry.grantId = action.payload.grantId;
      }
    },
    rated(
      state,
      action: PayloadAction<{ id: string; feedback: OutcomeFeedback }>,
    ) {
      const entry = state.entries.find((item) => item.id === action.payload.id);
      if (
        entry &&
        ["approved", "keptLocked", "earlyEnded", "expired"].includes(
          entry.outcome,
        )
      )
        entry.feedback = action.payload.feedback;
    },
    removalRecorded(
      state,
      action: PayloadAction<{
        appId: string;
        date: string;
        reason: string;
        disposition: string;
      }>,
    ) {
      state.removalLedger.push({
        ...action.payload,
        feedbackSignal: "high_frustration",
      });
    },
    cleared(state) {
      state.entries = [];
    },
    recovered(state) {
      for (const entry of state.entries)
        if (entry.outcome === "pending") entry.outcome = "interrupted";
    },
  },
});
export const activityLogActions = slice.actions;
export default slice.reducer;

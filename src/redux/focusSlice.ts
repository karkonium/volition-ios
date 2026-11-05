import { createSlice, type PayloadAction } from "@reduxjs/toolkit";

export interface FocusScope {
  allApps: boolean;
  appIDs: string[];
}
export interface FocusPeriod extends FocusScope {
  id: string;
  name: string;
  weekdays: number[];
  startMinutes: number;
  endMinutes: number;
  isEnabled: boolean;
}
export interface QuickFocusPreferences extends FocusScope {
  minutes: number;
}
export interface FocusSession extends QuickFocusPreferences {
  id: string;
  start: string;
}
export interface FocusOccurrence {
  id: string;
  sourceId: string;
  kind: "routine" | "session";
  name?: string;
  appIDs: string[];
  exceptedAppIDs: string[];
  startsAt: string;
  endsAt: string;
}
export interface FocusState {
  revision: number;
  observedAt: string | null;
  periods: FocusPeriod[];
  session: FocusSession | null;
  preferences: QuickFocusPreferences | null;
  active: FocusOccurrence[];
  upcoming: FocusOccurrence[];
  nextRefreshAt: string | null;
  monitoringUnavailable?: boolean;
}
export type FocusCommand =
  | { kind: "saveRoutine"; period: FocusPeriod; expectedRevision: number }
  | { kind: "deleteRoutine"; sourceId: string; expectedRevision: number }
  | {
      kind: "savePreferences";
      preferences: QuickFocusPreferences;
      expectedRevision: number;
    }
  | { kind: "startSession" }
  | { kind: "endSession"; sourceId: string }
  | { kind: "exceptApp"; occurrenceID: string; appID: string };

export const emptyFocus: FocusState = {
  revision: -1,
  observedAt: null,
  periods: [],
  session: null,
  preferences: null,
  active: [],
  upcoming: [],
  nextRefreshAt: null,
};

const slice = createSlice({
  name: "focus",
  initialState: emptyFocus,
  reducers: {
    synced(state, action: PayloadAction<FocusState>) {
      const next = action.payload;
      if (
        state.revision > next.revision ||
        (state.revision === next.revision &&
          Date.parse(state.observedAt ?? "") >
            Date.parse(next.observedAt ?? ""))
      )
        return;
      return { ...next, monitoringUnavailable: state.monitoringUnavailable };
    },
    monitoringChanged(state, action: PayloadAction<boolean>) {
      state.monitoringUnavailable = action.payload;
    },
  },
});
export const focusActions = slice.actions;
export default slice.reducer;

import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
export interface FocusPeriod {
  id: string;
  name: string;
  appIDs: string[];
  weekdays: number[];
  startMinutes: number;
  endMinutes: number;
  isEnabled: boolean;
}
export interface FocusSession {
  id: string;
  appIDs: string[];
  start: string;
  minutes: number;
}
export interface FocusState {
  periods: FocusPeriod[];
  session: FocusSession | null;
}
const initialState: FocusState = { periods: [], session: null };
const slice = createSlice({
  name: "focus",
  initialState,
  reducers: {
    synced(_state, action: PayloadAction<FocusState>) {
      return action.payload;
    },
  },
});
export const focusActions = slice.actions;
export default slice.reducer;

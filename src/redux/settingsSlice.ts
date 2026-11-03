import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
export type CoachTone = "warm" | "balanced" | "direct";
const slice = createSlice({
  name: "settings",
  initialState: {
    legacyImported: false,
    tone: "balanced" as CoachTone,
    keyConfigured: false,
    notificationsEnabled: false,
  },
  reducers: {
    legacyImported(state) {
      state.legacyImported = true;
    },
    toneChanged(state, action: PayloadAction<CoachTone>) {
      state.tone = action.payload;
    },
    keyConfigured(state, action: PayloadAction<boolean>) {
      state.keyConfigured = action.payload;
    },
    notificationsChanged(state, action: PayloadAction<boolean>) {
      state.notificationsEnabled = action.payload;
    },
  },
});
export const settingsActions = slice.actions;
export default slice.reducer;

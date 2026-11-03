import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
export interface VolitionSavedApp {
  id: string;
  name: string;
  goal: string;
  notes?: string;
  tokenBase64: string;
  isEnabled: boolean;
  createdAt: string;
  purposes: string[];
  changes: string[];
  sessionStyle: string;
}
export function validateApp(
  app: VolitionSavedApp,
  others: readonly VolitionSavedApp[],
): void {
  if (
    !app.name.trim() ||
    app.name.trim().length > 600 ||
    !app.goal.trim() ||
    app.goal.length > 2000 ||
    (app.notes?.length ?? 0) > 2000 ||
    !app.tokenBase64 ||
    others.some(
      (other) => other.id !== app.id && other.tokenBase64 === app.tokenBase64,
    )
  )
    throw new Error("Choose one app and provide a unique name and intention.");
}
const slice = createSlice({
  name: "apps",
  initialState: { items: [] as VolitionSavedApp[], nativeFingerprint: "" },
  reducers: {
    saved(state, action: PayloadAction<VolitionSavedApp>) {
      validateApp(action.payload, state.items);
      state.items = state.items.filter((app) => app.id !== action.payload.id);
      state.items.push({ ...action.payload, name: action.payload.name.trim() });
    },
    removed(state, action: PayloadAction<string>) {
      state.items = state.items.filter((app) => app.id !== action.payload);
    },
    fingerprintUpdated(state, action: PayloadAction<string>) {
      state.nativeFingerprint = action.payload;
    },
  },
});
export const appsActions = slice.actions;
export default slice.reducer;

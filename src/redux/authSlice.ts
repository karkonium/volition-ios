import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
import type { AuthorizationStatus } from "../../modules/volition-screen-time";
interface AuthState {
  authorization: AuthorizationStatus;
  aiConsent: boolean;
  onboarded: boolean;
  consentRevision: number;
}
const initialState: AuthState = {
  authorization: "notDetermined",
  aiConsent: true,
  onboarded: false,
  consentRevision: 0,
};
const slice = createSlice({
  name: "auth",
  initialState,
  reducers: {
    authorizationChanged(state, action: PayloadAction<AuthorizationStatus>) {
      state.authorization = action.payload;
    },
    consentChanged(state, action: PayloadAction<boolean>) {
      state.aiConsent = action.payload;
      state.consentRevision++;
    },
    onboardingCompleted(state) {
      state.onboarded = true;
    },
  },
});
export const authActions = slice.actions;
export default slice.reducer;

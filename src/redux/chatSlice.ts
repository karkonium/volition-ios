import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
import type { CoachDecision } from "../services/decision";
export type { CoachDecision };
export interface ChatMessage {
  id: string;
  role: "user" | "assistant" | "system";
  text: string;
  timestamp: string;
  appId?: string;
  decision?: CoachDecision;
}
const slice = createSlice({
  name: "chat",
  initialState: {
    routeVersion: 0,
    selectionAttention: 0,
    memory: "",
    messages: [] as ChatMessage[],
    draft: "",
    boundAppId: null as string | null,
    selectedAppId: null as string | null,
    pendingRequestId: null as string | null,
    visibleCount: 60,
    error: null as string | null,
  },
  reducers: {
    memoryImported(state, action: PayloadAction<string>) {
      state.memory = action.payload;
    },
    selectionRequired(state) {
      state.selectionAttention++;
    },
    shieldRequested(state, action: PayloadAction<string>) {
      state.selectionAttention = 0;
      state.selectedAppId = action.payload;
      state.boundAppId = action.payload;
      state.routeVersion++;
    },
    boundRequest(
      state,
      action: PayloadAction<{ appId: string; draft: string }>,
    ) {
      state.selectedAppId = action.payload.appId;
      state.boundAppId = action.payload.appId;
      state.draft = action.payload.draft;
    },
    draftChanged(state, action: PayloadAction<string>) {
      state.draft = action.payload;
      state.boundAppId = null;
    },
    boundSelected(state, action: PayloadAction<string>) {
      state.selectionAttention = 0;
      state.selectedAppId = action.payload;
      state.boundAppId = action.payload;
    },
    selected(state, action: PayloadAction<string>) {
      state.selectionAttention = 0;
      state.selectedAppId = action.payload;
    },
    messageAdded(state, action: PayloadAction<ChatMessage>) {
      state.messages.push(action.payload);
    },
    requestChanged(state, action: PayloadAction<string | null>) {
      state.pendingRequestId = action.payload;
      if (action.payload !== null) state.error = null;
    },
    failed(state, action: PayloadAction<string>) {
      state.error = action.payload;
      state.pendingRequestId = null;
    },
    loadEarlier(state) {
      state.visibleCount += 60;
    },
    cleared(state) {
      state.messages = [];
      state.memory = "";
      state.draft = "";
      state.pendingRequestId = null;
      state.error = null;
    },
  },
});
export const chatActions = slice.actions;
export default slice.reducer;

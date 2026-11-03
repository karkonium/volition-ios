import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
import type {
  ActiveGrant,
  Commitment,
} from "../../modules/volition-screen-time";
import type { CoachDecisionResponse } from "../services/decision";
export type { ActiveGrant };
export interface Intervention {
  id: string;
  appId: string;
  fingerprint: string;
  consentRevision: number;
  decision: CoachDecisionResponse;
  status:
    "checkIn" | "offered" | "delaying" | "ready" | "activating" | "interrupted";
  deadline?: string;
  createdAt: string;
  expiresAt: string;
  emotion?: string;
  overridingID: string | null;
  logId: string;
}
export interface PauseAttempt {
  appId: string;
  startedAt: string;
}
export interface Reflection {
  appId: string;
  date: string;
  emotion: string | null;
}
export interface GrantsState {
  activeGrants: ActiveGrant[];
  commitments: Commitment[];
  offers: Record<string, Intervention>;
  lastCheckInAt: string | null;
  pauseAttempts: PauseAttempt[];
  reflections: Reflection[];
  accessHistory: {
    grantId: string;
    appId: string;
    date: string;
    minutes: number;
  }[];
  hardWaits: Record<string, string>;
}
const initialState: GrantsState = {
  activeGrants: [],
  commitments: [],
  offers: {},
  lastCheckInAt: null,
  pauseAttempts: [],
  reflections: [],
  accessHistory: [],
  hardWaits: {},
};
const slice = createSlice({
  name: "grants",
  initialState,
  reducers: {
    legacyHistoryImported(
      state,
      action: PayloadAction<{
        accessHistory: GrantsState["accessHistory"];
        lastCheckInAt: string | null;
        pauseAttempts: PauseAttempt[];
        reflections: Reflection[];
        hardWaits: Record<string, string>;
      }>,
    ) {
      Object.assign(state, action.payload);
    },
    legacyWaitImported(state, action: PayloadAction<Record<string, string>>) {
      state.hardWaits = action.payload;
    },
    nativeSynced(
      state,
      action: PayloadAction<{
        grants: ActiveGrant[];
        commitments: Commitment[];
      }>,
    ) {
      state.activeGrants = action.payload.grants;
      state.commitments = action.payload.commitments;
    },
    offered(state, action: PayloadAction<Intervention>) {
      state.offers[action.payload.appId] = action.payload;
      if (action.payload.status === "checkIn")
        state.lastCheckInAt = action.payload.createdAt;
    },
    offerUpdated(state, action: PayloadAction<Intervention>) {
      state.offers[action.payload.appId] = action.payload;
    },
    offerRemoved(state, action: PayloadAction<string>) {
      delete state.offers[action.payload];
    },
    pauseStarted(state, action: PayloadAction<PauseAttempt>) {
      state.pauseAttempts.push(action.payload);
    },
    reflected(state, action: PayloadAction<Reflection>) {
      state.reflections = [
        ...state.reflections.filter(
          (item) =>
            Date.parse(item.date) >= Date.parse(action.payload.date) - 86400000,
        ),
        action.payload,
      ].slice(-10);
    },
    publicationRolledBack(state, action: PayloadAction<string>) {
      state.activeGrants = state.activeGrants.filter(
        (grant) => grant.grantId !== action.payload,
      );
      state.accessHistory = state.accessHistory.filter(
        (item) => item.grantId !== action.payload,
      );
    },
    granted(state, action: PayloadAction<ActiveGrant>) {
      state.activeGrants = state.activeGrants.filter(
        (grant) => grant.grantId !== action.payload.grantId,
      );
      state.activeGrants.push(action.payload);
      if (
        !state.accessHistory.some(
          (item) => item.grantId === action.payload.grantId,
        )
      )
        state.accessHistory.push({
          grantId: action.payload.grantId,
          appId: action.payload.appId,
          date: new Date().toISOString(),
          minutes: action.payload.minutes,
        });
      delete state.offers[action.payload.appId];
    },
    offersCancelled(state) {
      state.offers = {};
    },
    recovered(state) {
      for (const offer of Object.values(state.offers)) {
        if (offer.status === "activating") offer.status = "interrupted";
      }
    },
  },
});
export const grantsActions = slice.actions;
export default slice.reducer;

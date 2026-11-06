import { configureStore } from "@reduxjs/toolkit";
import auth, { authActions } from "../redux/authSlice";
import apps, { appsActions } from "../redux/appsSlice";
import chat, { chatActions } from "../redux/chatSlice";
import grants, { grantsActions } from "../redux/grantsSlice";
import focus from "../redux/focusSlice";
import activityLog from "../redux/activityLogSlice";
import settings from "../redux/settingsSlice";
import { ConversationCoordinator } from "./conversationCoordinator";
import type { ScreenTimeBridge } from "../../modules/volition-screen-time";
import type { CoachDecisionResponse } from "./decision";
const app = {
  id: "a",
  name: "YouTube",
  goal: "Learn",
  tokenBase64: "token",
  isEnabled: true,
  createdAt: new Date(0).toISOString(),
  purposes: [],
  changes: [],
  sessionStyle: "unsure",
};
function setup(response: CoachDecisionResponse, random = 1) {
  const store = configureStore({
    reducer: { auth, apps, chat, grants, focus, activityLog, settings },
  });
  let now = 1000000;
  store.dispatch(authActions.authorizationChanged("approved"));
  store.dispatch(appsActions.saved(app));
  store.dispatch(appsActions.fingerprintUpdated("config"));
  store.dispatch(chatActions.draftChanged("youtube to learn"));
  const createGrant = jest.fn(async () => ({
    grantId: "g",
    appId: "a",
    tokenBase64: "token",
    minutes: 5,
    expiresAt: new Date(now + 300000).toISOString(),
  }));
  const native = {
    getAPIKey: async () => "key",
    getFocus: async () => JSON.stringify({ revision: 0, periods: [] }),
    createGrant,
    rollbackGrant: jest.fn(async () => undefined),
    revokeGrant: jest.fn(async () => undefined),
    syncPresentation: async () => undefined,
    recordPushback: async () => undefined,
    getCommitments: jest.fn(async () => []),
  } as unknown as ScreenTimeBridge;
  const request = jest.fn(
    async (_request: import("./openaiClient").DecisionRequest) => response,
  );
  const flush = jest.fn(async () => undefined);
  const coordinator = new ConversationCoordinator({
    getState: store.getState,
    dispatch: store.dispatch,
    native,
    flush,
    request,
    foreground: () => true,
    now: () => now,
    id: () => String(Math.random()),
    random: () => random,
  });
  return {
    store,
    coordinator,
    native,
    createGrant,
    request,
    flush,
    advance: (ms: number) => {
      now += ms;
    },
  };
}
const pause: CoachDecisionResponse = {
  reply: "Pause first.",
  decision: "pause",
  unlock_minutes: 5,
  wait_minutes: null,
  pause_seconds: 10,
  block_minutes: null,
};
test("elapsed delay never unlocks without an explicit action", async () => {
  const s = setup(pause);
  await s.coordinator.send();
  expect(s.store.getState().grants.offers.a?.status).toBe("delaying");
  s.advance(10000);
  expect(s.createGrant).not.toHaveBeenCalled();
  await s.coordinator.activate("a", "delay");
  expect(s.createGrant).toHaveBeenCalledTimes(1);
  expect(s.store.getState().activityLog.entries[0]?.outcome).toBe("approved");
});
test("skip reveals separate intervention and starts ten seconds then", async () => {
  const s = setup(pause, 0);
  await s.coordinator.send();
  expect(s.store.getState().grants.offers.a?.status).toBe("checkIn");
  expect(s.store.getState().chat.messages).toHaveLength(1);
  s.advance(15000);
  await s.coordinator.answerCheckIn("a", null);
  expect(s.store.getState().grants.offers.a?.deadline).toBe(
    new Date(1025000).toISOString(),
  );
  expect(s.createGrant).not.toHaveBeenCalled();
});
test("long pause requires Start", async () => {
  const s = setup({ ...pause, pause_seconds: 60 });
  await s.coordinator.send();
  expect(s.store.getState().grants.offers.a?.status).toBe("offered");
  expect(s.store.getState().grants.pauseAttempts).toHaveLength(0);
});
test("declined offer gives feedback without a grant", async () => {
  const s = setup(pause);
  await s.coordinator.send();
  await s.coordinator.keepLocked("a");
  expect(s.createGrant).not.toHaveBeenCalled();
  expect(s.store.getState().activityLog.entries[0]?.outcome).toBe("keptLocked");
});
test("consent withdrawal invalidates persisted offers", async () => {
  const s = setup(pause);
  await s.coordinator.send();
  s.store.dispatch(authActions.consentChanged(false));
  await expect(s.coordinator.activate("a", "delay")).rejects.toThrow();
  expect(s.createGrant).not.toHaveBeenCalled();
});
test("failed activation never logs an unlock", async () => {
  const s = setup({ ...pause, decision: "approve", pause_seconds: null });
  s.createGrant.mockRejectedValueOnce(new Error("shield remains"));
  await s.coordinator.send();
  expect(s.store.getState().activityLog.entries[0]?.outcome).toBe(
    "interrupted",
  );
  expect(s.store.getState().grants.accessHistory).toHaveLength(0);
  expect(s.store.getState().chat.draft).toBe("youtube to learn");
});
test("native deal terms require explicit acceptance", async () => {
  const s = setup({
    ...pause,
    decision: "deal",
    pause_seconds: null,
    block_minutes: 30,
  });
  await s.coordinator.send();
  expect(s.createGrant).not.toHaveBeenCalled();
  await s.coordinator.activate("a", "deal");
  expect(s.createGrant).toHaveBeenCalledWith(
    "token",
    5,
    "config",
    30,
    null,
    false,
    0,
  );
});
test("recovered activation is interrupted, never replayed", () => {
  const initial = grants(undefined, { type: "init" });
  const offer = {
    id: "offer",
    appId: "a",
    fingerprint: "config",
    consentRevision: 0,
    decision: pause,
    status: "activating" as const,
    createdAt: "",
    expiresAt: "",
    overridingID: null,
    logId: "log",
  };
  const state = grants(
    { ...initial, offers: { a: offer } },
    grantsActions.recovered(),
  );
  expect(state.offers.a?.status).toBe("interrupted");
});

test("consent changing during native activation rolls back the exact grant", async () => {
  const s = setup({ ...pause, decision: "approve", pause_seconds: null });
  s.createGrant.mockImplementationOnce(async () => {
    s.store.dispatch(authActions.consentChanged(false));
    return {
      grantId: "g",
      appId: "a",
      tokenBase64: "token",
      minutes: 5,
      expiresAt: new Date().toISOString(),
    };
  });
  await s.coordinator.send();
  expect(s.native.rollbackGrant).toHaveBeenCalledWith("g");
  expect(s.store.getState().grants.accessHistory).toHaveLength(0);
  expect(s.store.getState().activityLog.entries[0]?.outcome).toBe(
    "interrupted",
  );
});

test("failed request keeps its error visible after cleanup and the draft editable", async () => {
  const s = setup(pause);
  s.request.mockRejectedValueOnce(new Error("Coach temporarily unavailable"));
  await s.coordinator.send();
  expect(s.store.getState().chat.error).toBe("Coach temporarily unavailable");
  expect(s.store.getState().chat.pendingRequestId).toBeNull();
  expect(s.store.getState().chat.draft).toBe("youtube to learn");
});

test("a late cancelled request cannot replace a newer request error", async () => {
  const s = setup(pause);
  let rejectOld: (reason: Error) => void = () => {
    throw new Error("Old request did not start");
  };
  s.request.mockImplementationOnce(
    () =>
      new Promise((_resolve, reject) => {
        rejectOld = reject;
      }),
  );
  const old = s.coordinator.send();
  while (s.request.mock.calls.length === 0) await Promise.resolve();
  s.coordinator.cancel();
  s.request.mockRejectedValueOnce(new Error("New request failed"));
  await s.coordinator.send();
  rejectOld(new Error("Old request failed"));
  await old;
  expect(s.store.getState().chat.error).toBe("New request failed");
});

test("cancel during activation revokes the unpublished native grant", async () => {
  const s = setup({ ...pause, decision: "approve", pause_seconds: null });
  s.createGrant.mockImplementationOnce(async () => {
    s.coordinator.cancel();
    return {
      grantId: "g",
      appId: "a",
      tokenBase64: "token",
      minutes: 5,
      expiresAt: new Date().toISOString(),
    };
  });
  await s.coordinator.send();
  expect(s.native.rollbackGrant).toHaveBeenCalledWith("g");
  expect(s.store.getState().grants.accessHistory).toHaveLength(0);
  expect(s.store.getState().activityLog.entries[0]?.outcome).toBe(
    "interrupted",
  );
});

test("the next coach request receives the native commitment even before the refresh loop", async () => {
  const s = setup({
    ...pause,
    decision: "ask",
    unlock_minutes: null,
    pause_seconds: null,
  });
  const commitment = {
    grantId: "deal-g",
    appId: "a",
    blockedUntil: new Date(2000000).toISOString(),
    pushbackCount: 2,
    overriddenAt: null,
    minimumReplacementBreakMinutes: 32,
  };
  jest.mocked(s.native.getCommitments).mockResolvedValue([commitment]);
  await s.coordinator.send();
  expect(s.request.mock.calls[0]?.[0]).toMatchObject({
    context: { deal: { ...commitment, canOverride: true } },
  });
  expect(s.store.getState().activityLog.entries[0]?.outcome).toBe("asked");
});

test("a failed durable activation claim is interrupted without calling native approval", async () => {
  const s = setup({
    ...pause,
    decision: "deal",
    pause_seconds: null,
    block_minutes: 30,
  });
  await s.coordinator.send();
  s.flush.mockRejectedValueOnce(new Error("Local storage unavailable"));
  await expect(s.coordinator.activate("a", "deal")).rejects.toThrow(
    "Local storage unavailable",
  );
  expect(s.createGrant).not.toHaveBeenCalled();
  expect(s.store.getState().grants.offers.a).toBeUndefined();
  expect(s.store.getState().activityLog.entries[0]?.outcome).toBe(
    "interrupted",
  );
});

test("an approval shortened by an upcoming routine needs explicit acceptance", async () => {
  const s = setup({ ...pause, decision: "approve", pause_seconds: null });
  const startAt = new Date(1000000 + 185000).toISOString();
  s.native.getFocus = async () =>
    JSON.stringify({
      revision: 1,
      periods: [],
      session: null,
      preferences: null,
      active: [],
      upcoming: [
        {
          id: "p",
          sourceId: "p",
          kind: "routine",
          name: "Study",
          appIDs: ["a"],
          exceptedAppIDs: [],
          startsAt: startAt,
          endsAt: new Date(1000000 + 3600000).toISOString(),
        },
      ],
    });
  await s.coordinator.send();
  expect(s.createGrant).not.toHaveBeenCalled();
  expect(s.store.getState().grants.offers.a?.decision.unlock_minutes).toBe(3);
  s.advance(65000);
  await s.coordinator.activate("a", "open");
  expect(s.createGrant).not.toHaveBeenCalled();
  expect(s.store.getState().grants.offers.a?.decision.unlock_minutes).toBe(2);
  await s.coordinator.activate("a", "open");
  expect(s.createGrant).toHaveBeenCalledWith(
    "token",
    2,
    "config",
    null,
    null,
    false,
    0,
  );
});

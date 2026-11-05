import { parseLegacyHistory } from "./legacyImport";
import { AppState } from "react-native";
import * as Crypto from "expo-crypto";
import { store, persistor } from "../redux/store";
import {
  VolitionScreenTime,
  previewMode,
} from "../../modules/volition-screen-time";
import { ConversationCoordinator } from "./conversationCoordinator";
import { requestCoachDecision } from "./openaiClient";
import i18n from "../translations/i18n";
import { resolveLanguage } from "../translations/locale";
import {
  appsActions,
  type VolitionSavedApp,
  validateApp,
} from "../redux/appsSlice";
import { authActions } from "../redux/authSlice";
import { chatActions, type ChatMessage } from "../redux/chatSlice";
import { grantsActions } from "../redux/grantsSlice";
import { settingsActions } from "../redux/settingsSlice";
import { activityLogActions } from "../redux/activityLogSlice";
import { focusActions, type FocusState } from "../redux/focusSlice";
export const coordinator = new ConversationCoordinator({
  getState: store.getState,
  dispatch: store.dispatch,
  native: VolitionScreenTime,
  flush: () => persistor.flush(),
  request: previewMode
    ? async () => ({
        reply:
          "Five minutes of learning? Choose a short pause, agree to thirty minutes away afterward, or open now.",
        decision: "choice",
        unlock_minutes: 5,
        wait_minutes: null,
        pause_seconds: 10,
        block_minutes: 30,
      })
    : (request) => requestCoachDecision({ ...request, language: resolveLanguage(i18n.resolvedLanguage ?? null, []) }),
  foreground: () => AppState.currentState === "active",
  now: Date.now,
  id: Crypto.randomUUID,
  random: Math.random,
});
let syncQueue: Promise<void> = Promise.resolve();
export function syncNative(): Promise<void> {
  const task = async (): Promise<void> => {
    if (AppState.currentState !== "active") return;
    const status = VolitionScreenTime.getAuthorizationStatus();
    store.dispatch(authActions.authorizationChanged(status));
    if (status !== "approved") return;
    const fingerprint = await VolitionScreenTime.reconcileShields(
      store.getState().apps.items,
    );
    store.dispatch(appsActions.fingerprintUpdated(fingerprint));
    const [grants, commitments] = await Promise.all([
      VolitionScreenTime.getActiveGrants(),
      VolitionScreenTime.getCommitments(),
    ]);
    store.dispatch(grantsActions.nativeSynced({ grants, commitments }));
    const appId = await VolitionScreenTime.consumeShieldRequest();
    if (appId) store.dispatch(chatActions.shieldRequested(appId));
    for (const offer of Object.values(store.getState().grants.offers))
      if (Date.parse(offer.expiresAt) <= Date.now())
        store.dispatch(grantsActions.offerRemoved(offer.appId));
    await VolitionScreenTime.syncPresentation();
  };
  const next = syncQueue.then(task);
  syncQueue = next.catch(() => undefined);
  return next;
}
function object(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}
export async function initializeRuntime(): Promise<void> {
  // Open the original store on every launch, including after the one-time import,
  // so legacy hard waits remain enforceable and unreadable stores fail closed.
  const legacy = object(
    JSON.parse(await VolitionScreenTime.exportLegacyState()) as unknown,
  );
  if (!store.getState().settings.legacyImported) {
    if (!Array.isArray(legacy.apps) || typeof legacy.aiConsent !== "boolean")
      throw new Error("Saved data could not be migrated.");
    for (const value of legacy.apps as unknown[]) {
      const app = value as VolitionSavedApp;
      validateApp(app, store.getState().apps.items);
      store.dispatch(appsActions.saved(app));
    }
    store.dispatch(authActions.consentChanged(legacy.aiConsent));
    if (["warm", "balanced", "direct"].includes(String(legacy.tone)))
      store.dispatch(
        settingsActions.toneChanged(
          legacy.tone as "warm" | "balanced" | "direct",
        ),
      );
    const history = object(legacy.history);
    if (typeof history.memory === "string")
      store.dispatch(chatActions.memoryImported(history.memory));
    if (Array.isArray(history.recordedRemovals))
      for (const raw of history.recordedRemovals as unknown[]) {
        const item = object(raw);
        if (typeof item.appID === "string" && typeof item.date === "string")
          store.dispatch(
            activityLogActions.removalRecorded({
              appId: item.appID.toLowerCase(),
              date: item.date,
              reason: typeof item.reason === "string" ? item.reason : "",
              disposition:
                typeof item.outcome === "string" ? item.outcome : "considering",
            }),
          );
      }
    if (Array.isArray(history.messages))
      for (const value of history.messages as unknown[]) {
        const message = object(value);
        if (
          typeof message.id === "string" &&
          typeof message.text === "string" &&
          typeof message.date === "string"
        )
          store.dispatch(
            chatActions.messageAdded({
              id: message.id,
              text: message.text,
              timestamp: message.date,
              role:
                message.role === "user"
                  ? "user"
                  : message.role === "assistant"
                    ? "assistant"
                    : "system",
            } satisfies ChatMessage),
          );
      }
    const imported = parseLegacyHistory(
      history,
      store.getState().apps.items.map((app) => app.id),
    );
    const { entries, ...grantHistory } = imported;
    store.dispatch(grantsActions.legacyHistoryImported(grantHistory));
    for (const entry of entries)
      store.dispatch(activityLogActions.added(entry));
    if (store.getState().apps.items.length)
      store.dispatch(authActions.onboardingCompleted());
    const focus = JSON.parse(await VolitionScreenTime.getFocus()) as FocusState;
    store.dispatch(
      focusActions.synced({ ...focus, session: focus.session ?? null }),
    );
    store.dispatch(settingsActions.legacyImported());
    await persistor.flush();
  }
  await VolitionScreenTime.setAIConsent(
    store.getState().auth.aiConsent,
    store.getState().auth.consentRevision,
  );
  store.dispatch(grantsActions.recovered());
  store.dispatch(activityLogActions.recovered());
  store.dispatch(chatActions.requestChanged(null));
  if (!store.getState().auth.aiConsent)
    store.dispatch(grantsActions.offersCancelled());
  await syncNative();
}
export async function saveApp(app: VolitionSavedApp): Promise<void> {
  validateApp(app, store.getState().apps.items);
  const previous = store.getState().apps.items;
  await VolitionScreenTime.reconcileShields([
    ...previous.filter((item) => item.id !== app.id),
    app,
  ]);
  store.dispatch(appsActions.saved(app));
  await persistor.flush();
  await syncNative();
}
export function recordRemoval(
  app: VolitionSavedApp,
  reason: string,
  disposition: string,
): void {
  const date = new Date().toISOString();
  store.dispatch(
    activityLogActions.removalRecorded({
      appId: app.id,
      date,
      reason,
      disposition,
    }),
  );
  store.dispatch(
    activityLogActions.added({
      id: Crypto.randomUUID(),
      appId: app.id,
      appName: app.name,
      date,
      message: reason,
      decision: null,
      outcome: disposition === "removed" ? "removed" : "removalRequested",
      feedbackSignal: "high_frustration",
    }),
  );
}
export async function removeApp(appId: string, reason: string): Promise<void> {
  const previous = store
    .getState()
    .apps.items.find((item) => item.id === appId);
  const apps = store.getState().apps.items.filter((item) => item.id !== appId);
  await VolitionScreenTime.reconcileShields(apps);
  store.dispatch(appsActions.removed(appId));
  if (previous) recordRemoval(previous, reason, "removed");
  await persistor.flush();
  await syncNative();
}
export async function updateFocus(state: FocusState): Promise<void> {
  await VolitionScreenTime.updateFocus(JSON.stringify(state));
  store.dispatch(focusActions.synced(state));
  await persistor.flush();
  await syncNative();
}
export async function setConsent(value: boolean): Promise<void> {
  coordinator.cancel();
  store.dispatch(authActions.consentChanged(value));
  if (!value) store.dispatch(grantsActions.offersCancelled());
  await VolitionScreenTime.setAIConsent(
    value,
    store.getState().auth.consentRevision,
  );
  await persistor.flush();
}
export async function endGrant(id: string): Promise<void> {
  await VolitionScreenTime.revokeGrant(id);
  const entry = store
    .getState()
    .activityLog.entries.find((item) => item.grantId === id);
  if (entry)
    store.dispatch(
      activityLogActions.outcomeRecorded({
        id: entry.id,
        outcome: "earlyEnded",
        grantId: id,
      }),
    );
  await syncNative();
}

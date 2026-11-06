import { createFocusPreview } from "./focusPreview";
import { focusAccessLimit, focusReasons } from "../../src/services/focusStatus";
import type {
  ActiveGrant,
  ScreenTimeBridge,
  SavedNativeApp,
  Commitment,
} from "./index";
// Explicit development-only preview. No call reaches FamilyControls or OpenAI.
export function createPreviewBridge(): ScreenTimeBridge {
  let grants: ActiveGrant[] = [];
  let commitments: Commitment[] = [];
  let apps: SavedNativeApp[] = [];
  const focus = createFocusPreview();
  const enabledIDs = () =>
    apps.filter(({ isEnabled }) => isEnabled).map(({ id }) => id);
  const reconcileGrants = () => {
    const now = Date.now();
    const status = focus.snapshot(enabledIDs());
    grants = grants.filter(
      (grant) =>
        Date.parse(grant.expiresAt) > now &&
        enabledIDs().includes(grant.appId) &&
        !focusReasons(status, grant.appId, now).length,
    );
    return grants;
  };
  const sample: SavedNativeApp = {
    id: "00000000-0000-4000-8000-000000000001",
    name: "YouTube",
    goal: "Learn something useful.",
    tokenBase64: "preview-token",
    isEnabled: true,
  };
  return {
    setLanguage: async () => undefined,
    requestAuthorization: async () => "approved",
    getAuthorizationStatus: () => "approved",
    presentAppPicker: async () => ({ tokenBase64: `preview-${Date.now()}` }),
    exportLegacyState: async () =>
      JSON.stringify({
        apps: [
          {
            ...sample,
            createdAt: new Date().toISOString(),
            purposes: ["learning"],
            changes: ["duration"],
            sessionStyle: "both",
          },
        ],
        history: {},
        aiConsent: true,
        tone: "balanced",
      }),
    reconcileShields: async (next) => {
      apps = next;
      return JSON.stringify(next);
    },
    createGrant: async (token, minutes, fingerprint, breakMinutes) => {
      if (fingerprint !== JSON.stringify(apps))
        throw new Error("Preview configuration changed");
      const appId = apps.find((app) => app.tokenBase64 === token)?.id ?? "";
      const limit = focusAccessLimit(
        focus.snapshot(enabledIDs()),
        appId,
        Date.now(),
      );
      if (limit.minutes < minutes)
        throw Object.assign(new Error("Focus boundary"), {
          code: "FOCUS_BOUNDARY",
        });
      const grant = {
        grantId: `preview-${Date.now()}`,
        appId,
        tokenBase64: token,
        minutes,
        expiresAt: new Date(Date.now() + minutes * 60000).toISOString(),
      };
      grants.push(grant);
      if (breakMinutes)
        commitments.push({
          grantId: grant.grantId,
          appId: grant.appId,
          blockedUntil: new Date(
            Date.parse(grant.expiresAt) + breakMinutes * 60000,
          ).toISOString(),
          pushbackCount: 0,
          overriddenAt: null,
          minimumReplacementBreakMinutes: 30,
        });
      return grant;
    },
    revokeGrant: async (id) => {
      grants = grants.filter((grant) => grant.grantId !== id);
    },
    rollbackGrant: async (id) => {
      grants = grants.filter((grant) => grant.grantId !== id);
      commitments = commitments.filter((deal) => deal.grantId !== id);
    },
    getActiveGrants: async () => reconcileGrants(),
    getCommitments: async () => commitments.map((deal) => ({ ...deal })),
    consumeShieldRequest: async () => null,
    recordPushback: async () => undefined,
    syncPresentation: async () => undefined,
    setAIConsent: async () => undefined,
    getAPIKey: async () => "preview",
    setAPIKey: async () => undefined,
    applyFocusCommand: async (json) => {
      const snapshot = focus.apply(JSON.parse(json), enabledIDs());
      reconcileGrants();
      return JSON.stringify(snapshot);
    },
    repairFocusMonitoring: async () => undefined,
    getFocus: async () => JSON.stringify(focus.snapshot(enabledIDs())),
  };
}

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
  const sample: SavedNativeApp = {
    id: "00000000-0000-4000-8000-000000000001",
    name: "YouTube",
    goal: "Learn something useful.",
    tokenBase64: "preview-token",
    isEnabled: true,
  };
  return {
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
      const grant = {
        grantId: `preview-${Date.now()}`,
        appId: apps.find((app) => app.tokenBase64 === token)?.id ?? "",
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
    getActiveGrants: async () =>
      grants.filter((grant) => Date.parse(grant.expiresAt) > Date.now()),
    getCommitments: async () => commitments.map((deal) => ({ ...deal })),
    consumeShieldRequest: async () => null,
    recordPushback: async () => undefined,
    syncPresentation: async () => undefined,
    setAIConsent: async () => undefined,
    getAPIKey: async () => "preview",
    setAPIKey: async () => undefined,
    updateFocus: async () => undefined,
    getFocus: async () => JSON.stringify({ periods: [], session: null }),
  };
}

import { createPreviewBridge } from "./mock";
import { requireOptionalNativeModule } from "expo-modules-core";

export interface SavedNativeApp {
  id: string;
  name: string;
  goal: string;
  tokenBase64: string;
  isEnabled: boolean;
}
export interface ActiveGrant {
  grantId: string;
  appId: string;
  tokenBase64: string;
  minutes: number;
  expiresAt: string;
}
export interface Commitment {
  grantId: string;
  appId: string;
  blockedUntil: string;
  pushbackCount: number;
  overriddenAt: string | null;
  minimumReplacementBreakMinutes: number;
}
export type AuthorizationStatus =
  "approved" | "denied" | "notDetermined" | "unknown";
export interface ScreenTimeBridge {
  exportLegacyState(): Promise<string>;
  updateFocus(json: string): Promise<void>;
  getFocus(): Promise<string>;
  requestAuthorization(): Promise<AuthorizationStatus>;
  getAuthorizationStatus(): AuthorizationStatus;
  presentAppPicker(): Promise<{ tokenBase64: string }>;
  reconcileShields(apps: SavedNativeApp[]): Promise<string>;
  createGrant(
    token: string,
    minutes: number,
    fingerprint: string,
    breakMinutes: number | null,
    overridingID: string | null,
    relief: boolean,
    consentRevision: number,
  ): Promise<ActiveGrant>;
  setAIConsent(allowed: boolean, revision: number): Promise<void>;
  rollbackGrant(id: string): Promise<void>;
  revokeGrant(id: string): Promise<void>;
  getActiveGrants(): Promise<ActiveGrant[]>;
  getCommitments(): Promise<Commitment[]>;
  recordPushback(token: string): Promise<void>;
  consumeShieldRequest(): Promise<string | null>;
  syncPresentation(): Promise<void>;
  setAPIKey(key: string): Promise<void>;
  getAPIKey(): Promise<string | null>;
}
const native =
  requireOptionalNativeModule<ScreenTimeBridge>("VolitionScreenTime");
const unavailable = (): never => {
  throw new Error("Screen Time requires the Volition iOS development build.");
};
// A missing module fails closed. Synthetic enforcement is injected by tests only.
export const previewMode =
  __DEV__ && process.env.EXPO_PUBLIC_VOLITION_PREVIEW === "1";
export const nativeAvailable = Boolean(native);
export const VolitionScreenTime: ScreenTimeBridge = previewMode
  ? createPreviewBridge()
  : (native ?? {
      exportLegacyState: async () => unavailable(),
      updateFocus: async () => unavailable(),
      getFocus: async () => unavailable(),
      requestAuthorization: async () => "notDetermined",
      getAuthorizationStatus: () => "notDetermined",
      presentAppPicker: async () => unavailable(),
      reconcileShields: async () => unavailable(),
      createGrant: async () => unavailable(),
      setAIConsent: async () => unavailable(),
      rollbackGrant: async () => unavailable(),
      revokeGrant: async () => unavailable(),
      getActiveGrants: async () => [],
      getCommitments: async () => [],
      recordPushback: async () => unavailable(),
      consumeShieldRequest: async () => null,
      syncPresentation: async () => undefined,
      setAPIKey: async () => unavailable(),
      getAPIKey: async () => null,
    });

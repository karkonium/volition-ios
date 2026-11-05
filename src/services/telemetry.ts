import Constants from "expo-constants";
import { previewMode } from "../../modules/volition-screen-time";
import { isTelemetryScreen, telemetryPreferences } from "./telemetryPolicy";

export const firebaseConfigured =
  Constants.expoConfig?.extra?.firebaseConfigured === true && !previewMode;
let analyticsAllowed = false;
let updateQueue = Promise.resolve();
let previousCrashPreference: boolean | undefined;

/// These SDK calls are best-effort and must never affect access or app startup.
export function updateTelemetry(
  analytics: boolean | undefined,
  crashReports: boolean | undefined,
): void {
  const preferences = telemetryPreferences(
    analytics,
    crashReports,
    previewMode,
  );
  analyticsAllowed = firebaseConfigured && preferences.analytics;
  if (!firebaseConfigured) return;
  updateQueue = updateQueue
    .catch(() => {})
    .then(async () => {
      const analyticsSdk =
        require("@react-native-firebase/analytics").default();
      const crashSdk = require("@react-native-firebase/crashlytics").default();
      await analyticsSdk
        .setAnalyticsCollectionEnabled(preferences.analytics)
        .catch(() => {});
      // Crashlytics remains in manual-report mode. Only send reports after a
      // launch whose persisted preference opted in; discard opted-out reports.
      if (
        crashReportAction(preferences.crashReports, previousCrashPreference) ===
        "send"
      ) {
        await crashSdk.sendUnsentReports();
      } else {
        await crashSdk.deleteUnsentReports();
      }
      previousCrashPreference = preferences.crashReports;
    })
    .catch(() => {});
}

export function trackScreen(name: string | undefined): void {
  if (
    !firebaseConfigured ||
    !analyticsAllowed ||
    !name ||
    !isTelemetryScreen(name)
  )
    return;
  void updateQueue
    .then(() => {
      if (!analyticsAllowed) return;
      return require("@react-native-firebase/analytics")
        .default()
        .logScreenView({ screen_name: name, screen_class: name });
    })
    .catch(() => {});
}

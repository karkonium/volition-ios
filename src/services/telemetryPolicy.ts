/// Only fixed product screen names may be sent to analytics; user content is never an event parameter.
const screens = [
  "Chat",
  "Apps",
  "Insights",
  "Focus",
  "Settings",
  "SettingsHome",
  "CoachSettings",
  "PrivacyData",
  "ActivityLog",
  "Diagnostics",
] as const;
export type TelemetryScreen = (typeof screens)[number];
export function isTelemetryScreen(value: string): value is TelemetryScreen {
  return (screens as readonly string[]).includes(value);
}
export function telemetryPreferences(
  analytics: boolean | undefined,
  crashReports: boolean | undefined,
  preview: boolean,
) {
  return {
    analytics: !preview && analytics === true,
    crashReports: !preview && crashReports === true,
  };
}

export function crashReportAction(
  enabled: boolean,
  previous: boolean | undefined,
): "send" | "delete" {
  return enabled && previous !== false ? "send" : "delete";
}

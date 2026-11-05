export type MainTabs = {
  Chat: undefined;
  Apps: undefined;
  Insights: undefined;
  Focus: { sourceId: string; visit: number } | undefined;
  Settings: undefined;
};
export type SettingsStack = {
  SettingsHome: undefined;
  Preferences: undefined;
  CoachSettings: undefined;
  PrivacyData: undefined;
  ActivityLog: undefined;
  Diagnostics: undefined;
};

export type AppsStack = {
  AppsHome: undefined;
  AppEditor: { appId?: string };
};

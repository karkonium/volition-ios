module.exports = {
  "type": "widget",
  "name": "VolitionLiveActivity",
  "bundleIdentifier": "com.a5karki.volition.LiveActivity",
  "deploymentTarget": "18.0",
  "frameworks": [
    "FamilyControls",
    "ManagedSettings",
    "ManagedSettingsUI",
    "DeviceActivity",
    "SwiftUI",
    "ActivityKit",
    "UserNotifications"
  ],
  "entitlements": {
    "com.apple.developer.family-controls": true,
    "com.apple.security.application-groups": [
      "group.com.a5karki.volition"
    ]
  }
};

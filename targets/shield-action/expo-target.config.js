module.exports = {
  "type": "shield-action",
  "name": "OpenAppLockShieldAction",
  "bundleIdentifier": "com.a5karki.volition.ShieldAction",
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

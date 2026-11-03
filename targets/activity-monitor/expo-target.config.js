module.exports = {
  "type": "device-activity-monitor",
  "name": "OpenAppLockMonitor",
  "bundleIdentifier": "com.a5karki.volition.Monitor",
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

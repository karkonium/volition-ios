// apple-targets 5.0 has no DeviceActivity report preset. Register the preserved
// extension point before target discovery; all other targets use stock presets.
const target = require("@bacons/apple-targets/build/target");
target.TARGET_REGISTRY["device-activity-report"] = {
  extensionPointIdentifier: "com.apple.deviceactivityui.report-extension",
  frameworks: ["DeviceActivity", "SwiftUI"],
  appGroupsByDefault: true,
  displayName: "Device Activity Report",
};
const getInfo = target.getTargetInfoPlistForType;
target.getTargetInfoPlistForType = (type) =>
  type === "device-activity-report"
    ? {
        NSExtension: {
          NSExtensionPointIdentifier:
            "com.apple.deviceactivityui.report-extension",
        },
      }
    : getInfo(type);
const configuration = require("@bacons/apple-targets/build/configuration-list");
const createConfiguration = configuration.createConfigurationListForType;
configuration.createConfigurationListForType = (project, props) =>
  createConfiguration(
    project,
    props.type === "device-activity-report"
      ? { ...props, type: "widget" }
      : props,
  );
module.exports = require("@bacons/apple-targets/app.plugin");

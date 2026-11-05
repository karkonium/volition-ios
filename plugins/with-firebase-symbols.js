const { withXcodeProject } = require("@expo/config-plugins");

// Crashlytics needs dSYMs from archive builds to symbolicate native crashes.
module.exports = function withFirebaseSymbols(config) {
  return withXcodeProject(config, (result) => {
    const project = result.modResults;
    const target = project.getFirstTarget().uuid;
    project.addBuildPhase(
      [],
      "PBXShellScriptBuildPhase",
      "Upload Crashlytics symbols",
      target,
      {
        shellPath: "/bin/sh",
        shellScript: '"${PODS_ROOT}/FirebaseCrashlytics/run"',
        alwaysOutOfDate: true,
        inputPaths: [
          '"${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"',
          '"${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}"',
          '"${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist"',
          '"$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist"',
          '"$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)"',
        ],
      },
    );
    return result;
  });
};

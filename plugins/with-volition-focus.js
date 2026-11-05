const fs = require("node:fs");
const path = require("node:path");
const { IOSConfig, withXcodeProject } = require("@expo/config-plugins");

module.exports = (config) =>
  withXcodeProject(config, (result) => {
    const { projectName, platformProjectRoot } = result.modRequest;
    const name = "VolitionFocusIntents.swift";
    fs.copyFileSync(
      path.join(__dirname, "ios", name),
      path.join(platformProjectRoot, projectName, name),
    );
    IOSConfig.XcodeUtils.addBuildSourceFileToGroup({
      filepath: `${projectName}/${name}`,
      groupName: projectName,
      project: result.modResults,
      targetUuid: result.modResults.getFirstTarget().uuid,
    });
    return result;
  });

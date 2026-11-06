const path = require("node:path");
const { withPlugins, withPodfile } = require("@expo/config-plugins");

module.exports = (config) => {
  // An iOS plist must not enable the Android Firebase Gradle plugins.
  if (config.ios?.googleServicesFile) {
    const firebase = path.dirname(
      require.resolve("@react-native-firebase/app/package.json"),
    );
    const { withFirebaseAppDelegate, withIosGoogleServicesFile } = require(
      path.join(firebase, "plugin/build/ios"),
    );
    config = withPlugins(config, [
      withFirebaseAppDelegate,
      withIosGoogleServicesFile,
    ]);
  }
  return withPodfile(config, (result) => {
    result.modResults.contents =
      "$RNFirebaseAnalyticsWithoutAdIdSupport = true\n" +
      result.modResults.contents;
    return result;
  });
};

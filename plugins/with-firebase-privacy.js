const { withPodfile } = require("@expo/config-plugins");
module.exports = (config) =>
  withPodfile(config, (result) => {
    result.modResults.contents =
      "$RNFirebaseAnalyticsWithoutAdIdSupport = true\n" +
      result.modResults.contents;
    return result;
  });

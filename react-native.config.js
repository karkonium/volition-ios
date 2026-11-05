// RNFirebase otherwise adds its Crashlytics upload script even in unconfigured
// builds, where the script fails because GoogleService-Info.plist is absent.
const configured = require("./app.config").extra.firebaseConfigured;

module.exports = {
  dependencies: configured
    ? {}
    : {
        "@react-native-firebase/crashlytics": {
          platforms: { ios: { scriptPhases: [] } },
        },
      },
};

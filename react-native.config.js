// RNFirebase otherwise adds its Crashlytics upload script even in unconfigured
// builds, where the script fails because GoogleService-Info.plist is absent.
const configured = require("./app.config").extra.firebaseConfigured;

module.exports = {
  dependencies: {
    "@react-native-firebase/app": { platforms: { android: null } },
    "@react-native-firebase/analytics": { platforms: { android: null } },
    "@react-native-firebase/crashlytics": {
      platforms: {
        android: null,
        ...(configured ? {} : { ios: { scriptPhases: [] } }),
      },
    },
  },
};

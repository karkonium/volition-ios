const fs = require("fs");
const path = require("path");
const base = require("./app.json").expo;

// A build without the Firebase configuration remains a normal, usable build.
const plist =
  process.env.VOLITION_GOOGLE_SERVICES_PLIST || "./GoogleService-Info.plist";
const configured = fs.existsSync(path.resolve(__dirname, plist));
if (process.env.VOLITION_GOOGLE_SERVICES_PLIST && !configured) {
  throw new Error(
    "VOLITION_GOOGLE_SERVICES_PLIST does not point to a readable Firebase plist.",
  );
}
module.exports = {
  ...base,
  ios: { ...base.ios, ...(configured ? { googleServicesFile: plist } : {}) },
  extra: { ...base.extra, firebaseConfigured: configured },
  plugins: [
    ...base.plugins,
    ...(configured
      ? [
          "@react-native-firebase/app",
          "@react-native-firebase/crashlytics",
          "./plugins/with-firebase-symbols",
        ]
      : []),
    "./plugins/with-firebase-privacy",
  ],
};

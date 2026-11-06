/// <reference types="node" />
import { mkdtempSync, cpSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { execFileSync } from "node:child_process";

describe("Firebase native configuration", () => {
  let directory: string;
  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), "volition-firebase-config-"));
    for (const file of [
      "app.config.js",
      "app.json",
      "react-native.config.js",
    ]) {
      cpSync(resolve(file), join(directory, file));
    }
  });
  afterEach(() => rmSync(directory, { recursive: true, force: true }));

  function configuration(): {
    extra: { firebaseConfigured: boolean };
    dependencies: Record<string, unknown>;
  } {
    const env = { ...process.env };
    delete env.VOLITION_GOOGLE_SERVICES_PLIST;
    const output = execFileSync(
      process.execPath,
      [
        "-e",
        'console.log(JSON.stringify({extra: require("./app.config").extra, dependencies: require("./react-native.config").dependencies}))',
      ],
      { cwd: directory, env, encoding: "utf8" },
    );
    return JSON.parse(output);
  }

  it("suppresses the Crashlytics upload phase without a plist", () => {
    const config = configuration();
    expect(config.extra.firebaseConfigured).toBe(false);
    expect(config.dependencies["@react-native-firebase/crashlytics"]).toEqual({
      platforms: { android: null, ios: { scriptPhases: [] } },
    });
  });

  it("preserves the Firebase upload phase when a plist is supplied", () => {
    writeFileSync(join(directory, "GoogleService-Info.plist"), "placeholder");
    const config = configuration();
    expect(config.extra.firebaseConfigured).toBe(true);
    expect(config.dependencies).toEqual({
      "@react-native-firebase/app": { platforms: { android: null } },
      "@react-native-firebase/analytics": { platforms: { android: null } },
      "@react-native-firebase/crashlytics": { platforms: { android: null } },
    });
  });
});

// SDK 57.0.24's legacy exported headers omit nullability and a protocol import.
// Supply declarations rather than disabling Xcode 27 warnings-as-errors.
const fs = require("fs");
const path = require("path");
const root = path.join(
  __dirname,
  "..",
  "node_modules",
  "expo-modules-core",
  "ios",
);
const file = path.join(root, "Interfaces/FileSystem/EXFileSystemInterface.h");
let source = fs.readFileSync(file, "utf8");
if (!source.includes("NS_ASSUME_NONNULL_BEGIN")) {
  source =
    source.replace(
      "#import <Foundation/Foundation.h>",
      "#import <Foundation/Foundation.h>\n\nNS_ASSUME_NONNULL_BEGIN",
    ) + "\nNS_ASSUME_NONNULL_END\n";
  fs.writeFileSync(file, source);
}
const registry = path.join(
  root,
  "Legacy/ModuleRegistryAdapter/EXModuleRegistryHolderReactModule.h",
);
source = fs.readFileSync(registry, "utf8");
if (source.includes("@protocol RCTBridgeModule;")) {
  fs.writeFileSync(
    registry,
    source.replace(
      "@protocol RCTBridgeModule;",
      "#import <React/RCTBridgeModule.h>",
    ),
  );
}

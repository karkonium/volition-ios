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
// React Native removes the legacy architecture for native compilation, but its
// Swift import flags omit that define. Also keep +Internal headers private in
// the generated framework umbrella instead of exporting deprecated internals.
const reactRoot = path.join(__dirname, "..", "node_modules", "react-native");
const specPath = path.join(reactRoot, "React-Core.podspec");
source = fs.readFileSync(specPath, "utf8");
source = source.replace(
  'ss.private_header_files   = "React/Cxx*/*.h"',
  'ss.private_header_files   = ["React/Cxx*/*.h", "React/**/*+Internal.h"]',
);
if (
  !source.includes("ss.source_files = headers\n      ss.private_header_files")
) {
  source = source.replace(
    "ss.source_files = headers\n",
    'ss.source_files = headers\n      ss.private_header_files = "React/**/*+Internal.h"\n',
  );
}
fs.writeFileSync(specPath, source);
for (const relative of [
  "React/Base/RCTMultipartDataTask.h",
  "Libraries/Network/RCTHTTPRequestHandler.h",
]) {
  const header = path.join(reactRoot, relative);
  source = fs.readFileSync(header, "utf8");
  if (!source.includes("NS_ASSUME_NONNULL_BEGIN")) {
    const lines = source.split("\n");
    let lastImport = -1;
    lines.forEach((line, index) => {
      if (line.startsWith("#import")) lastImport = index;
    });
    lines.splice(lastImport + 1, 0, "\nNS_ASSUME_NONNULL_BEGIN\n");
    fs.writeFileSync(header, lines.join("\n") + "\nNS_ASSUME_NONNULL_END\n");
  }
}
const websocket = path.join(
  reactRoot,
  "React/CoreModules/RCTWebSocketModule.h",
);
source = fs.readFileSync(websocket, "utf8");
source = source.replace(
  "typedef SRWebSocket * (^SRWebSocketProvider)(NSURLRequest *request);",
  "typedef SRWebSocket * _Nonnull (^SRWebSocketProvider)(NSURLRequest * _Nonnull request);",
);
fs.writeFileSync(websocket, source);
const http = path.join(reactRoot, 'Libraries/Network/RCTHTTPRequestHandler.h');
source = fs.readFileSync(http, 'utf8');
source = source.replace('typedef NSURLSessionConfiguration * (^NSURLSessionConfigurationProvider)(void);', 'typedef NSURLSessionConfiguration * _Nonnull (^NSURLSessionConfigurationProvider)(void);');
fs.writeFileSync(http, source);

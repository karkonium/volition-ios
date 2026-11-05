#!/usr/bin/env node
// Only format source owners, never the symlinked extension copies or generated iOS project.
const { readdirSync, lstatSync, readFileSync } = require("node:fs");
const { join, relative, resolve } = require("node:path");
const { spawnSync } = require("node:child_process");
const root = resolve(__dirname, "..");
const check = process.argv.includes("--check");
const find = (dir) =>
  readdirSync(dir).flatMap((name) => {
    const file = join(dir, name);
    const stat = lstatSync(file);
    if (stat.isSymbolicLink()) return [];
    if (stat.isDirectory()) return find(file);
    return name.endsWith(".swift") ? [file] : [];
  });
const swift = spawnSync("xcrun", ["--find", "swift-format"], {
  encoding: "utf8",
});
if (swift.status !== 0) {
  console.error(
    "swift-format is unavailable; install Xcode and select its command-line tools.",
  );
  process.exit(1);
}
const files = ["modules/volition-screen-time/ios", "targets"].flatMap((path) =>
  find(join(root, path)),
);
let failed = false;
for (const file of files) {
  const args = ["format", "--configuration", join(root, ".swift-format")];
  if (!check) args.push("--in-place");
  args.push(file);
  const result = spawnSync(swift.stdout.trim(), args, {
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
  });
  if (result.status !== 0 || result.error) {
    console.error(`${relative(root, file)}: ${result.stderr || result.error}`);
    failed = true;
  } else if (check && result.stdout !== readFileSync(file, "utf8")) {
    console.error(`Needs formatting: ${relative(root, file)}`);
    failed = true;
  }
}
if (failed) process.exit(1);
console.log(
  `Swift formatting ${check ? "checked" : "applied"} for ${files.length} files.`,
);

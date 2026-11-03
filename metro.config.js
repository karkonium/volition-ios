const { getDefaultConfig } = require("expo/metro-config");
const {
  withOptionalShims,
} = require("@itsRares/ahhzo-elements/metro/withOptionalShims");
module.exports = withOptionalShims(getDefaultConfig(__dirname), {
  projectRoot: __dirname,
});

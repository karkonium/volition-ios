import { resolveAppName } from "./appResolver";
const apps = ["YouTube", "YouTube Music", "SoundCloud", "音楽"].map(
  (name, index) => ({ id: String(index), name, isEnabled: true }),
);
test.each([
  ["open youtube", "0"],
  ["youtube music please", "1"],
  ["sound cloud", "2"],
  ["音楽 を開く", "3"],
])("routes %s", (text, id) =>
  expect(resolveAppName(text, apps)).toMatchObject({
    type: "selected",
    app: { id },
  }),
);
test("preserves ambiguity", () =>
  expect(resolveAppName("youtube or soundcloud", apps)).toEqual({
    type: "ambiguous",
  }));
test("ignores disabled apps and partial words", () => {
  expect(resolveAppName("youtubers", apps)).toEqual({ type: "none" });
  expect(
    resolveAppName("youtube", [{ ...apps[0]!, isEnabled: false }]),
  ).toEqual({ type: "none" });
});
test("duplicate names stay ambiguous", () =>
  expect(
    resolveAppName("youtube", [apps[0]!, { ...apps[0]!, id: "other" }]),
  ).toEqual({ type: "ambiguous" }));

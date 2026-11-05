import { editorGoal, sessionStyles, toggleSelection } from "./editorProfile";

test("preserves a legacy intention while editing", () => {
  expect(editorGoal("Read messages from family", ["learning"])).toBe(
    "Read messages from family",
  );
  expect(editorGoal(undefined, [])).toBe("Use this app with intention.");
});
test("multi-select toggles independently and session styles have readable labels", () => {
  expect(toggleSelection(["learning"], "relaxation")).toEqual([
    "learning",
    "relaxation",
  ]);
  expect(toggleSelection(["learning", "relaxation"], "learning")).toEqual([
    "relaxation",
  ]);
  expect(
    sessionStyles.find((option) => option.value === "shortVisits")?.label,
  ).toBe("Short visits");
});

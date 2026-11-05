import { composerState } from "./composerState";

it("allows a meaningful draft to be sent without consulting app selection", () => {
  expect(composerState("  Five minutes in Maps  ", false).canSend).toBe(true);
  expect(composerState("  \n ", false).canSend).toBe(false);
  expect(composerState("Maps", true).canSend).toBe(false);
});

it("shows the count near the limit and prevents oversized drafts from sending", () => {
  expect(composerState("", false).showCount).toBe(false);
  expect(composerState("a".repeat(3799), false).showCount).toBe(false);
  expect(composerState("a".repeat(3800), false).showCount).toBe(true);
  expect(composerState("a".repeat(4000), false).canSend).toBe(true);
  expect(composerState("a".repeat(4001), false).canSend).toBe(false);
});

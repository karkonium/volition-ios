import { outcomeLabel } from "./activityPresentation";

test("local outcomes are readable and do not imply unconfirmed access", () => {
  expect(outcomeLabel("approved")).toBe("Access granted");
  expect(outcomeLabel("unconfirmed")).toBe("Access unconfirmed");
  expect(outcomeLabel("failed")).toBe("Access failed");
  expect(outcomeLabel("keptLocked")).toBe("Kept locked");
});

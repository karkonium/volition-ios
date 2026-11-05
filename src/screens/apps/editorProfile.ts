export const sessionStyles = [
  { value: "shortVisits", label: "Short visits" },
  { value: "longerSessions", label: "Longer sessions" },
  { value: "both", label: "A mix of both" },
  { value: "unsure", label: "Not sure yet" },
];
export function toggleSelection(items: string[], value: string): string[] {
  return items.includes(value)
    ? items.filter((item) => item !== value)
    : [...items, value];
}
export function editorGoal(
  existingGoal: string | undefined,
  purposes: string[],
): string {
  return (
    existingGoal ||
    (purposes.length
      ? `Use this app for ${purposes.join(", ")}.`
      : "Use this app with intention.")
  );
}

interface NamedApp {
  id: string;
  name: string;
  isEnabled: boolean;
}
export type Resolution<T> =
  { type: "selected"; app: T } | { type: "ambiguous" } | { type: "none" };
const words = (value: string): string[] =>
  value
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase()
    .match(/[\p{L}\p{N}]+/gu) ?? [];
export function resolveAppName<T extends NamedApp>(
  text: string,
  apps: readonly T[],
): Resolution<T> {
  const tokens = words(text);
  const candidates: { app: T; start: number; end: number }[] = [];
  for (const app of apps.filter((app) => app.isEnabled)) {
    const name = words(app.name).join("");
    if (!name) continue;
    for (let start = 0; start < tokens.length; start++) {
      let phrase = "";
      for (let end = start; end < tokens.length; end++) {
        phrase += tokens[end];
        if (phrase === name) {
          candidates.push({ app, start, end: end + 1 });
          break;
        }
        if (phrase.length >= name.length) break;
      }
    }
  }
  const specific = candidates.filter(
    (item) =>
      !candidates.some(
        (other) =>
          other !== item &&
          other.start <= item.start &&
          other.end >= item.end &&
          (other.start !== item.start || other.end !== item.end),
      ),
  );
  const unique = [
    ...new Map(specific.map((item) => [item.app.id, item.app])).values(),
  ];
  return unique.length > 1
    ? { type: "ambiguous" }
    : unique[0]
      ? { type: "selected", app: unique[0] }
      : { type: "none" };
}

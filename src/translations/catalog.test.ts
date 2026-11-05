import { messages } from "./messages";

const placeholders = (text: string): string[] =>
  [...text.matchAll(/{{\s*(\w+)\s*}}/g)].map((match) => match[1]!).sort();
test.each(["es", "zh"] as const)(
  "%s keeps every translation key and interpolation parameter",
  (language) => {
    const english = messages.en as Record<string, string>;
    const translated = messages[language] as Record<string, string>;
    expect(Object.keys(translated).sort()).toEqual(Object.keys(english).sort());
    for (const key of Object.keys(english)) {
      expect(placeholders(translated[key]!)).toEqual(
        placeholders(english[key]!),
      );
    }
  },
);

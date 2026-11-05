import { isLanguage, resolveLanguage } from "./locale";

describe("language selection", () => {
  it("prefers a supported saved language", () => {
    expect(resolveLanguage("zh", ["es-MX"])).toBe("zh");
  });
  it("uses the first supported device language and handles regional tags", () => {
    expect(resolveLanguage(null, ["fr-CA", "es-MX"])).toBe("es");
    expect(resolveLanguage(null, ["zh-Hant-TW"])).toBe("zh");
  });
  it("falls back to English for unsupported or invalid preferences", () => {
    expect(resolveLanguage("fr", ["de-DE"])).toBe("en");
  });
});

it("accepts only supported selections from the language field", () => {
  expect(isLanguage("es")).toBe(true);
  expect(isLanguage(null)).toBe(false);
  expect(isLanguage("fr")).toBe(false);
});

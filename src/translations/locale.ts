export const languages = ["en", "es", "zh"] as const;
export type Language = (typeof languages)[number];

/** Saved choice takes precedence; otherwise use the first supported device locale. */
export function resolveLanguage(
  saved: string | null,
  deviceLocales: readonly string[],
): Language {
  if (languages.includes(saved as Language)) return saved as Language;
  for (const locale of deviceLocales) {
    const base = locale.toLowerCase().split(/[-_]/)[0];
    if (languages.includes(base as Language)) return base as Language;
  }
  return "en";
}

export function isLanguage(value: string | null): value is Language {
  return value !== null && (languages as readonly string[]).includes(value);
}

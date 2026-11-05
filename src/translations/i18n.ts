import AsyncStorage from "@react-native-async-storage/async-storage";
import { getLocales } from "expo-localization";
import i18n, { type LanguageDetectorAsyncModule } from "i18next";
import { initReactI18next } from "react-i18next";
import { languages, resolveLanguage, type Language } from "./locale";
import { messages } from "./messages";
import { VolitionScreenTime } from "../../modules/volition-screen-time";

const STORAGE_KEY = "volition.language";
const detector: LanguageDetectorAsyncModule = {
  type: "languageDetector",
  async: true,
  init: () => {},
  detect: async () => {
    let saved: string | null = null;
    try {
      saved = await AsyncStorage.getItem(STORAGE_KEY);
    } catch {
      /* Use device language. */
    }
    return resolveLanguage(
      saved,
      getLocales().map((locale) => locale.languageTag),
    );
  },
  cacheUserLanguage: () => {},
};
export const i18nReady = i18n
  .use(initReactI18next)
  .use(detector)
  .init({
    resources: {
      en: { translation: messages.en },
      es: { translation: messages.es },
      zh: { translation: messages.zh },
    },
    fallbackLng: "en",
    supportedLngs: [...languages],
    interpolation: { escapeValue: false },
  });
// Extensions run in separate processes and read this preference from the App Group.
let nativeLanguageUpdate = Promise.resolve();
function syncNativeLanguage(language: string): void {
  nativeLanguageUpdate = nativeLanguageUpdate
    .catch(() => undefined)
    .then(() => VolitionScreenTime.setLanguage(resolveLanguage(language, [])))
    .catch(() => undefined);
}
i18n.on("languageChanged", syncNativeLanguage);
void i18nReady.then(() => syncNativeLanguage(i18n.resolvedLanguage ?? "en"));
export async function changeLanguage(language: Language): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, language);
  await i18n.changeLanguage(language);
}
export default i18n;

import React from "react";
import { View } from "react-native";
import {
  SelectField,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { useTranslation } from "react-i18next";
import { perform } from "../../components/Screen";
import { changeLanguage } from "../../translations/i18n";
import { isLanguage, resolveLanguage } from "../../translations/locale";
import { SettingsPage } from "./SettingsPage";
import { SettingsSection } from "./SettingsSection";

const languageOptions = [
  { value: "en", label: "English" },
  { value: "es", label: "Español" },
  { value: "zh", label: "中文" },
];
export function PreferencesScreen(): React.JSX.Element {
  const { t, i18n } = useTranslation();
  const styles = useThemedStyles(createStyles);
  return (
    <SettingsPage title={t("preferencesTitle")}>
      <SettingsSection title={t("language")} footer={t("languageNotice")}>
        <View style={styles.card}>
          <SelectField
            testID="settingsLanguageSelect"
            placeholderLabel={t("language")}
            data={languageOptions}
            value={resolveLanguage(i18n.resolvedLanguage ?? null, [])}
            onChange={(value) => {
              if (isLanguage(value)) perform(() => changeLanguage(value));
            }}
          />
        </View>
      </SettingsSection>
    </SettingsPage>
  );
}
const createStyles = (theme: Theme) =>
  ({
    card: {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
    },
  }) satisfies Record<string, ResponsiveStyle>;

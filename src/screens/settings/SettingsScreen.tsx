import React from "react";
import { useTranslation } from "react-i18next";
import { Icon, SettingsRow, useTheme } from "@itsRares/ahhzo-elements";
import { useNavigation, type NavigationProp } from "@react-navigation/native";
import { Screen } from "../../components/Screen";
import type { SettingsStack } from "../../navigation/types";
import { SettingsSection } from "./SettingsSection";

export function SettingsScreen(): React.JSX.Element {
  const { t } = useTranslation();
  const navigation = useNavigation<NavigationProp<SettingsStack>>();
  const { theme } = useTheme();
  const icon = (name: string) => (
    <Icon
      accessible={false}
      name={name}
      size={theme.sizes.lg}
      color={theme.colors.textLink}
    />
  );
  return (
    <Screen title={t("settings")} subtitle={t("settingsSubtitle")}>
      <SettingsSection title={t("preferences")}>
        <SettingsRow
          title={t("preferencesTitle")}
          description={t("preferencesDesc")}
          leading={icon("options-outline")}
          onPress={() => navigation.navigate("Preferences")}
        />
        <SettingsRow
          title={t("coach")}
          description={t("coachDesc")}
          leading={icon("chatbubble-ellipses-outline")}
          onPress={() => navigation.navigate("CoachSettings")}
        />
      </SettingsSection>
      <SettingsSection title={t("yourData")}>
        <SettingsRow
          title={t("privacy")}
          description={t("privacyDesc")}
          leading={icon("shield-checkmark-outline")}
          onPress={() => navigation.navigate("PrivacyData")}
        />
        <SettingsRow
          title={t("activity")}
          description={t("activityDesc")}
          leading={icon("time-outline")}
          testID="conversationActivityLogButton"
          onPress={() => navigation.navigate("ActivityLog")}
        />
      </SettingsSection>
      <SettingsSection title={t("support")}>
        <SettingsRow
          title={t("diagnostics")}
          description={t("diagnosticsDesc")}
          leading={icon("pulse-outline")}
          onPress={() => navigation.navigate("Diagnostics")}
        />
      </SettingsSection>
    </Screen>
  );
}

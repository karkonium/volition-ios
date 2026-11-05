import React from "react";
import { Icon, SettingsRow, useTheme } from "@itsRares/ahhzo-elements";
import { useNavigation, type NavigationProp } from "@react-navigation/native";
import { Screen } from "../../components/Screen";
import type { SettingsStack } from "../../navigation/types";
import { SettingsSection } from "./SettingsSection";

export function SettingsScreen(): React.JSX.Element {
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
    <Screen title="Settings" subtitle="Make Volition work for you.">
      <SettingsSection title="PREFERENCES">
        <SettingsRow
          title="Coach settings"
          description="Tone, API key and reminders"
          leading={icon("chatbubble-ellipses-outline")}
          onPress={() => navigation.navigate("CoachSettings")}
        />
      </SettingsSection>
      <SettingsSection title="YOUR DATA">
        <SettingsRow
          title="Privacy & data"
          description="Sharing choices and coaching content"
          leading={icon("shield-checkmark-outline")}
          onPress={() => navigation.navigate("PrivacyData")}
        />
        <SettingsRow
          title="Activity log"
          description="Review and export private activity"
          leading={icon("time-outline")}
          testID="conversationActivityLogButton"
          onPress={() => navigation.navigate("ActivityLog")}
        />
      </SettingsSection>
      <SettingsSection title="SUPPORT">
        <SettingsRow
          title="Diagnostics"
          description="Technical events on this device"
          leading={icon("pulse-outline")}
          onPress={() => navigation.navigate("Diagnostics")}
        />
      </SettingsSection>
    </Screen>
  );
}

import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { Linking, Platform, View } from "react-native";
import {
  Button,
  Icon,
  ListItem,
  SettingsRow,
  Text,
  TextField,
  useTheme,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { perform } from "../../components/Screen";
import { SettingsPage } from "./SettingsPage";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { settingsActions, type CoachTone } from "../../redux/settingsSlice";
import { VolitionScreenTime } from "../../../modules/volition-screen-time";
import { requestNotifications } from "../../services/notificationService";
import { SettingsSection } from "./SettingsSection";

const tones: { value: CoachTone; title: string; description: string }[] = [
  { value: "warm", title: "Warm", description: "Gentle and encouraging" },
  {
    value: "balanced",
    title: "Balanced",
    description: "Supportive and straightforward",
  },
  { value: "direct", title: "Direct", description: "Clear and concise" },
];
export function CoachSettingsScreen(): React.JSX.Element {
  const { t } = useTranslation();
  const android = Platform.OS === "android";
  const state = useAppSelector((state) => state.settings);
  const dispatch = useAppDispatch();
  const [key, setKey] = useState("");
  const styles = useThemedStyles(createStyles);
  const { theme } = useTheme();
  return (
    <SettingsPage title={t("coach")} subtitle={t("coachSubtitle")}>
      <SettingsSection title={t("toneHeading")} footer={t("toneFooter")}>
        {tones.map((tone) => (
          <ListItem
            key={tone.value}
            title={t(tone.value)}
            description={t(`${tone.value}Desc`)}
            accessibilityRole="radio"
            accessibilityState={{ checked: state.tone === tone.value }}
            containerStyle={styles.toneRow}
            leading={
              <Icon
                accessible={false}
                name={
                  state.tone === tone.value
                    ? "checkmark-circle"
                    : "ellipse-outline"
                }
                size={theme.sizes.lg}
                color={
                  state.tone === tone.value
                    ? theme.colors.textLink
                    : theme.colors.textSecondary
                }
              />
            }
            onPress={() => dispatch(settingsActions.toneChanged(tone.value))}
          />
        ))}
      </SettingsSection>
      <SettingsSection
        title={t("apiKeyHeading")}
        footer={t(android ? "androidApiKeyFooter" : "apiKeyFooter")}
      >
        <View style={styles.card}>
          <Text weight="SemiBold">
            {state.keyConfigured ? t("keyConfigured") : t("keyMissing")}
          </Text>
          <Text type="Small">
            {state.keyConfigured ? t("keyReplace") : t("keyAdd")}
          </Text>
          <TextField
            placeholderLabel={t("apiKey")}
            secure
            value={key}
            onChange={setKey}
            autoCapitalize="none"
            autoCorrect={false}
          />
          <Button
            text={t("saveKey")}
            disabled={!key.trim()}
            onPress={() =>
              perform(async () => {
                await VolitionScreenTime.setAPIKey(key.trim());
                dispatch(settingsActions.keyConfigured(true));
                setKey("");
              })
            }
          />
          {state.keyConfigured && (
            <Button
              text={t("removeKey")}
              variant="ghost"
              tone="danger"
              onPress={() =>
                perform(async () => {
                  await VolitionScreenTime.setAPIKey("");
                  dispatch(settingsActions.keyConfigured(false));
                  setKey("");
                })
              }
            />
          )}
        </View>
      </SettingsSection>
      <SettingsSection title={t("reminders")} footer={t("reminderFooter")}>
        <SettingsRow
          title={t("allowNotifications")}
          description={t("notificationPermission")}
          onPress={() =>
            perform(async () => {
              dispatch(
                settingsActions.notificationsChanged(
                  await requestNotifications(),
                ),
              );
            })
          }
        />
        <SettingsRow
          title={t("notificationSettings")}
          description={t(
            android
              ? "androidNotificationSettingsDesc"
              : "notificationSettingsDesc",
          )}
          onPress={() => perform(() => Linking.openSettings())}
        />
      </SettingsSection>
    </SettingsPage>
  );
}
const createStyles = (theme: Theme) =>
  ({
    toneRow: {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radii.base,
      minHeight: 68,
      paddingHorizontal: theme.spacing.md,
      paddingVertical: theme.spacing.sm,
    },
    card: {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      gap: theme.spacing.sm,
    },
  }) satisfies Record<string, ResponsiveStyle>;

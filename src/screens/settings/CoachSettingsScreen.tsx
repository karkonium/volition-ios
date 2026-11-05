import React, { useState } from "react";
import { Linking, View } from "react-native";
import {
  Button,
  Icon,
  SettingsRow,
  Text,
  TextField,
  useTheme,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
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
  const state = useAppSelector((state) => state.settings);
  const dispatch = useAppDispatch();
  const [key, setKey] = useState("");
  const styles = useThemedStyles(createStyles);
  const { theme } = useTheme();
  return (
    <Screen
      title="Coach settings"
      subtitle="Choose how your coach communicates."
    >
      <SettingsSection
        title="COACH TONE"
        footer="Tone changes the coach’s style, not the rules for access."
      >
        {tones.map((tone) => (
          <SettingsRow
            key={tone.value}
            title={tone.title}
            description={tone.description}
            value={state.tone === tone.value ? "Selected" : undefined}
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
        title="OPENAI API KEY"
        footer="Your personal key is stored in Keychain. GPT-5.4 mini is used for coaching."
      >
        <View style={styles.card}>
          <Text weight="SemiBold">
            {state.keyConfigured ? "Key configured" : "No key configured"}
          </Text>
          <Text type="Small">
            {state.keyConfigured
              ? "Enter a new key to replace it."
              : "Add your personal API key to use the coach."}
          </Text>
          <TextField
            placeholderLabel="API key"
            secure
            value={key}
            onChange={setKey}
            autoCapitalize="none"
            autoCorrect={false}
          />
          <Button
            text="Save key securely"
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
              text="Remove key"
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
      <SettingsSection
        title="UNLOCK REMINDERS"
        footer="Alerts at 60, 30 and 10 seconds remaining are best effort; system delivery can be delayed or unavailable."
      >
        <SettingsRow
          title="Allow notifications"
          description="Request notification permission"
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
          title="Notification settings"
          description="Manage permissions in iOS Settings"
          onPress={() => perform(() => Linking.openSettings())}
        />
      </SettingsSection>
    </Screen>
  );
}
const createStyles = (theme: Theme) =>
  ({
    card: {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      gap: theme.spacing.sm,
    },
  }) satisfies Record<string, ResponsiveStyle>;

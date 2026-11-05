import React from "react";
import { Alert, View } from "react-native";
import {
  Button,
  SettingsRow,
  Text,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { grantsActions } from "../../redux/grantsSlice";
import { chatActions } from "../../redux/chatSlice";
import { settingsActions } from "../../redux/settingsSlice";
import { firebaseConfigured } from "../../services/telemetry";
import { setConsent, coordinator } from "../../services/runtime";
import { SettingsSection } from "./SettingsSection";

export function PrivacyDataScreen(): React.JSX.Element {
  const consent = useAppSelector((state) => state.auth.aiConsent);
  const dispatch = useAppDispatch();
  const analytics = useAppSelector(
    (state) => state.settings.analyticsEnabled === true,
  );
  const crashReports = useAppSelector(
    (state) => state.settings.crashReportsEnabled === true,
  );
  const styles = useThemedStyles(createStyles);
  const changeConsent = (enabled: boolean) => {
    if (!enabled) perform(() => setConsent(false));
    else
      Alert.alert(
        "Enable AI sharing?",
        "The information described above will be sent to OpenAI for coaching.",
        [
          { text: "Cancel", style: "cancel" },
          { text: "Enable", onPress: () => perform(() => setConsent(true)) },
        ],
      );
  };
  return (
    <Screen
      title="Privacy & data"
      subtitle="Control what is shared and stored."
    >
      <SettingsSection
        title="AI SHARING"
        footer="Turning sharing off cancels pending coach responses and offers."
      >
        <SettingsRow
          type="toggle"
          title="Share with OpenAI"
          description={
            consent
              ? "On · coaching can use your context"
              : "Off · coaching requests are paused"
          }
          value={consent}
          onValueChange={changeConsent}
        />
        <View style={styles.card}>
          <Text weight="SemiBold">What is shared</Text>
          <Text>
            Messages, saved app names, intentions, notes, recent allocated
            sessions, active unlocks and waits, agreements, recent app-removal
            feedback and optional check-ins are sent only while AI sharing is
            enabled.
          </Text>
        </View>
      </SettingsSection>
      <SettingsSection title="OPTIONAL GOOGLE DIAGNOSTICS">
        <View style={styles.card}>
          <Text>
            Analytics shares device information and which Volition screens you
            visit with Google. Crash reports share crash details, device
            information and stack traces. Reports can contain information
            present in a crash. These choices are independent of AI sharing.
            Disabling crash reports takes full effect after restarting the app.
          </Text>
        </View>
        {firebaseConfigured ? (
          <>
            <SettingsRow
              type="toggle"
              title="Analytics"
              value={analytics}
              onValueChange={(value) =>
                dispatch(settingsActions.analyticsChanged(value))
              }
            />
            <SettingsRow
              type="toggle"
              title="Crash reports"
              value={crashReports}
              onValueChange={(value) =>
                dispatch(settingsActions.crashReportsChanged(value))
              }
            />
          </>
        ) : (
          <Text type="Small" style={styles.note}>
            Google diagnostics are unavailable in this build.
          </Text>
        )}
      </SettingsSection>
      <SettingsSection title="ON THIS DEVICE">
        <View style={styles.card}>
          <Text>
            Chat, private activity history, saved profiles and commitments
            remain local. Keys are kept in Keychain. Ratings never affect
            access.
          </Text>
        </View>
      </SettingsSection>
      <SettingsSection
        title="ERASE CHAT"
        footer="Activity logs, access history and accepted commitments are retained. Pending offers are cancelled."
      >
        <View style={styles.card}>
          <Button
            text="Erase coaching content"
            variant="ghost"
            tone="danger"
            onPress={() =>
              Alert.alert(
                "Erase chat?",
                "Private activity logs, access history and existing agreements remain available. Pending offers are cancelled.",
                [
                  { text: "Cancel", style: "cancel" },
                  {
                    text: "Erase",
                    style: "destructive",
                    onPress: () => {
                      coordinator.cancel();
                      dispatch(chatActions.cleared());
                      dispatch(grantsActions.offersCancelled());
                    },
                  },
                ],
              )
            }
          />
        </View>
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
      gap: theme.spacing.xs,
    },
    note: { marginHorizontal: theme.spacing.xs },
  }) satisfies Record<string, ResponsiveStyle>;

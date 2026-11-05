import React from "react";
import { View } from "react-native";
import {
  Text,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { Screen } from "../../components/Screen";
import { diagnosticEntries } from "../../services/diagnostics";
import { SettingsSection } from "./SettingsSection";
export function DiagnosticsLogsScreen(): React.JSX.Element {
  const entries = [...diagnosticEntries()].reverse();
  const styles = useThemedStyles(createStyles);
  return (
    <Screen
      title="Diagnostics"
      subtitle="Technical event names only. No messages, app selections or credentials."
    >
      <SettingsSection title="EVENTS">
        {entries.length === 0 ? (
          <View style={styles.card}>
            <Text weight="SemiBold">No events recorded</Text>
            <Text type="Small">
              Technical events from this session will appear here.
            </Text>
          </View>
        ) : (
          entries.map((entry, index) => (
            <View style={styles.card} key={`${entry.date}-${index}`}>
              <Text weight="SemiBold">{entry.event}</Text>
              <Text type="Small">{new Date(entry.date).toLocaleString()}</Text>
            </View>
          ))
        )}
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
      gap: theme.spacing.xxs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

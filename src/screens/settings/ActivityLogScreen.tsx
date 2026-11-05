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
import { activityLogActions } from "../../redux/activityLogSlice";
import { shareActivity, removeExports } from "../../services/activityExport";
import { SettingsSection } from "./SettingsSection";
import { ActivityEntryCard } from "./ActivityEntryCard";
export function ActivityLogScreen(): React.JSX.Element {
  const entries = useAppSelector((state) => state.activityLog.entries);
  const dispatch = useAppDispatch();
  const styles = useThemedStyles(createStyles);
  return (
    <Screen
      title="Private activity log"
      subtitle="Model advice and actual local outcomes are recorded separately."
    >
      <SettingsSection title="EXPORT">
        <SettingsRow
          title="Export JSONL"
          description="Structured data, one entry per line"
          testID="exportActivityLogButton"
          onPress={() => perform(() => shareActivity(entries, "jsonl"))}
        />
        <SettingsRow
          title="Export text"
          description="A readable copy of your activity"
          onPress={() => perform(() => shareActivity(entries, "txt"))}
        />
      </SettingsSection>
      <SettingsSection title="ACTIVITY">
        {entries.length === 0 ? (
          <View style={styles.empty}>
            <Text weight="SemiBold">No activity yet</Text>
            <Text type="Small">
              Your requests and their outcomes will appear here.
            </Text>
          </View>
        ) : (
          [...entries]
            .reverse()
            .map((entry) => <ActivityEntryCard key={entry.id} entry={entry} />)
        )}
      </SettingsSection>
      <SettingsSection
        title="CLEAR ACTIVITY"
        footer="This removes activity entries and generated exports. Coaching and enforcement history are retained."
      >
        <View style={styles.empty}>
          <Button
            text="Clear activity log"
            testID="clearActivityLogButton"
            variant="ghost"
            tone="danger"
            onPress={() =>
              Alert.alert(
                "Clear activity log?",
                "Coaching and enforcement history are retained.",
                [
                  { text: "Cancel", style: "cancel" },
                  {
                    text: "Clear",
                    style: "destructive",
                    onPress: () => {
                      removeExports();
                      dispatch(activityLogActions.cleared());
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
    empty: {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      gap: theme.spacing.xs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

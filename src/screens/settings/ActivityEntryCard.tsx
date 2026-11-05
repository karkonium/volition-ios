import React from "react";
import { View } from "react-native";
import {
  Text,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import type { ActivityLogEntry } from "../../redux/activityLogSlice";
import { outcomeLabel } from "./activityPresentation";

export function ActivityEntryCard({
  entry,
}: {
  entry: ActivityLogEntry;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <Text type="H3" style={styles.name}>
          {entry.appName ?? "Volition"}
        </Text>
        <Text weight="SemiBold" type="Small" style={styles.outcome}>
          {outcomeLabel(entry.outcome)}
        </Text>
      </View>
      <Text type="Small">{new Date(entry.date).toLocaleString()}</Text>
      {entry.message ? (
        <View style={styles.block}>
          <Text type="Small" weight="SemiBold">
            YOU
          </Text>
          <Text>{entry.message}</Text>
        </View>
      ) : null}
      {entry.coachResponse ? (
        <View style={styles.block}>
          <Text type="Small" weight="SemiBold">
            COACH
          </Text>
          <Text>{entry.coachResponse}</Text>
        </View>
      ) : null}
      <View style={styles.divider} />
      <Text type="Small">
        Model advice: {entry.decision ?? "None"} · Local outcome:{" "}
        {outcomeLabel(entry.outcome)}
      </Text>
      <Text type="Small">
        Private feedback: {entry.feedback ?? "Not rated"}
      </Text>
    </View>
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
    header: {
      flexDirection: "row",
      flexWrap: "wrap",
      alignItems: "center",
      justifyContent: "space-between",
      gap: theme.spacing.xs,
    },
    name: { flexShrink: 1 },
    outcome: { color: theme.colors.textLink },
    block: { gap: theme.spacing.xxs, marginTop: theme.spacing.xs },
    divider: {
      height: 1,
      backgroundColor: theme.colors.border,
      marginTop: theme.spacing.xs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

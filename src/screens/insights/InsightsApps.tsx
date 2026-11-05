import React from "react";
import { View } from "react-native";
import {
  Flex,
  Text,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { VolitionAppIcon } from "../../components/VolitionAppIcon";
import { VolitionCard } from "../../components/VolitionCard";
import type { VolitionSavedApp } from "../../redux/appsSlice";
import type { buildInsights, InsightsPeriod } from "./insightsData";

export function InsightsApps({
  apps,
  totals,
  period,
}: {
  apps: VolitionSavedApp[];
  totals: ReturnType<typeof buildInsights>["apps"];
  period: InsightsPeriod;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  const active = apps
    .filter((app) => totals[app.id])
    .sort(
      (a, b) => (totals[b.id]?.minutes ?? 0) - (totals[a.id]?.minutes ?? 0),
    );
  return (
    <Flex vertical gap="sm">
      <Text type="H3">By app</Text>
      <Text type="Small">
        Allocated access {period === "today" ? "today" : "over the last 7 days"}
        .
      </Text>
      <VolitionCard>
        {active.length === 0 ? (
          <Text type="Small" style={styles.empty}>
            When a saved app receives a session, its allocated time will appear
            here.
          </Text>
        ) : (
          active.map((app, index) => {
            const total = totals[app.id]!;
            return (
              <View
                key={app.id}
                style={[styles.row, index > 0 && styles.divider]}
              >
                <VolitionAppIcon tokenBase64={app.tokenBase64} />
                <View style={styles.name}>
                  <Text weight="SemiBold">{app.name}</Text>
                  <Text type="Small">
                    {total.sessions}{" "}
                    {total.sessions === 1 ? "session" : "sessions"}
                  </Text>
                </View>
                <View style={styles.amount}>
                  <Text weight="SemiBold">{total.minutes} min</Text>
                  <Text type="ExtraSmall">granted</Text>
                </View>
              </View>
            );
          })
        )}
        {Object.keys(totals).some(
          (id) => !apps.some((app) => app.id === id),
        ) && (
          <Text type="Small">
            Totals above also include sessions for apps no longer saved.
          </Text>
        )}
      </VolitionCard>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    row: {
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.sm,
      paddingVertical: theme.spacing.sm,
    },
    divider: { borderTopWidth: 1, borderTopColor: theme.colors.border },
    name: { flex: 1, minWidth: 0 },
    amount: { alignItems: "flex-end" },
    empty: { paddingVertical: theme.spacing.md },
  }) satisfies Record<string, ResponsiveStyle>;

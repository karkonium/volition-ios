import React, { useState } from "react";
import { Button, Flex, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
import { Screen } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
import { useAppSelector } from "../../redux/store";
export function InsightsScreen(): React.JSX.Element {
  const [days, setDays] = useState(7);
  const state = useAppSelector((state) => state);
  const now = Date.now();
  const since = now - days * 86400000;
  const grants = state.grants.accessHistory.filter(
    (item) => Date.parse(item.date) >= since,
  );
  const entries = state.activityLog.entries.filter(
    (item) => Date.parse(item.date) >= since,
  );
  const stats = [
    ["Grants", grants.length],
    ["Granted minutes", grants.reduce((sum, item) => sum + item.minutes, 0)],
    ["Requests", entries.length],
    [
      "Early endings",
      entries.filter((item) => item.outcome === "earlyEnded").length,
    ],
    ["Denials", entries.filter((item) => item.outcome === "denied").length],
    ["Waits", entries.filter((item) => item.outcome === "wait").length],
  ] as const;
  const buckets = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(now);
    date.setHours(0, 0, 0, 0);
    date.setDate(date.getDate() - 6 + index);
    return {
      date,
      count: state.activityLog.entries.filter(
        (item) =>
          Date.parse(item.date) >= date.getTime() &&
          Date.parse(item.date) < date.getTime() + 86400000,
      ).length,
    };
  });
  const maximum = Math.max(1, ...buckets.map((item) => item.count));
  const styles = useThemedStyles((theme) => ({
    bar: {
      backgroundColor: theme.colors.accent,
      borderRadius: theme.radii.sm,
      minHeight: 2,
      width: 24,
    },
    chart: {
      minHeight: 120,
      alignItems: "flex-end" as const,
      justifyContent: "space-between" as const,
      padding: theme.spacing.md,
    },
  }));
  return (
    <Screen
      title="Insights"
      subtitle="Allocated sessions, not measured foreground use"
    >
      <Flex gap="sm">
        <Button
          text="Today"
          variant={days === 1 ? "filled" : "outline"}
          onPress={() => setDays(1)}
        />
        <Button
          text="Week"
          variant={days === 7 ? "filled" : "outline"}
          onPress={() => setDays(7)}
        />
      </Flex>
      <Flex wrap="wrap" gap="md">
        {stats.map(([label, value]) => (
          <VolitionCard key={label}>
            <Text type="H2">{value}</Text>
            <Text type="Small">{label}</Text>
          </VolitionCard>
        ))}
      </Flex>
      <Text type="H3">Requests over seven days</Text>
      <Flex style={styles.chart}>
        {buckets.map((item) => (
          <Flex
            key={item.date.toISOString()}
            vertical
            alignItems="center"
            gap="xs"
            accessibilityLabel={`${item.date.toLocaleDateString()}: ${item.count} requests`}
          >
            <Text type="Small">{item.count}</Text>
            <Flex
              style={[styles.bar, { height: (100 * item.count) / maximum }]}
            />
            <Text type="Small">
              {item.date.toLocaleDateString(undefined, { weekday: "narrow" })}
            </Text>
          </Flex>
        ))}
      </Flex>
      {state.apps.items.map((app) => (
        <VolitionCard key={app.id}>
          <Text type="H3">{app.name}</Text>
          <Text>
            {grants.filter((item) => item.appId === app.id).length} allocated
            sessions ·{" "}
            {grants
              .filter((item) => item.appId === app.id)
              .reduce((sum, item) => sum + item.minutes, 0)}{" "}
            minutes
          </Text>
        </VolitionCard>
      ))}
    </Screen>
  );
}

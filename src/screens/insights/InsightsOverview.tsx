import React from "react";
import { View } from "react-native";
import {
  Tabs,
  Flex,
  Text,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { VolitionCard } from "../../components/VolitionCard";
import type { buildInsights, InsightsPeriod } from "./insightsData";

type Props = {
  data: ReturnType<typeof buildInsights>;
  period: InsightsPeriod;
  onPeriodChange: (period: InsightsPeriod) => void;
  now: Date;
};
export function InsightsOverview({
  data,
  period,
  onPeriodChange,
  now,
}: Props): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  const max = Math.max(1, ...data.buckets.map((bucket) => bucket.minutes));
  const dateLabel = (date: Date) =>
    date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
  return (
    <Flex vertical gap="md">
      <Tabs
        accessibilityLabel="Insights period"
        tabs={[
          { key: "today", label: "Today" },
          { key: "week", label: "Week" },
        ]}
        activeTab={period}
        onTabPress={(key) => {
          if (key === "today" || key === "week") onPeriodChange(key);
        }}
        variant="filled"
        rootContainerStyle={styles.tabsRoot}
        gestureHostStyle={styles.tabsHost}
        scrollContainerStyle={styles.tabsScroll}
        tabsContainerStyle={styles.segment}
        tabItemStyle={{
          containerStyle: styles.segmentButton,
          contentStyle: styles.segmentContent,
          labelContainerStyle: styles.segmentLabel,
          textStyle: styles.segmentText,
          activeFilledContainerStyle: styles.segmentSelected,
          activeFilledTextStyle: styles.segmentSelectedText,
        }}
      />
      <VolitionCard>
        <Flex vertical gap="md">
          <Text type="Small" weight="SemiBold" style={styles.eyebrow}>
            {period === "today" ? "TODAY" : "LAST 7 DAYS"}
          </Text>
          <Flex wrap="wrap" gap="lg" style={styles.metrics}>
            <View style={styles.metric}>
              <Text type="H1">{data.sessions}</Text>
              <Text type="Small">
                Allocated {data.sessions === 1 ? "session" : "sessions"}
              </Text>
            </View>
            <View style={styles.metric}>
              <Text type="H1">{data.minutes}</Text>
              <Text type="Small">Granted minutes</Text>
            </View>
          </Flex>
          <Text type="Small">
            Time granted for access, not measured time in apps.
          </Text>
        </Flex>
      </VolitionCard>
      <VolitionCard>
        <Flex vertical gap="md">
          <Flex vertical gap="xxs">
            <Text type="H3">Granted minutes</Text>
            <Text type="Small">
              {period === "today"
                ? `${dateLabel(now)} · by time of day`
                : `${dateLabel(data.start)} – ${dateLabel(now)} · by day`}
            </Text>
          </Flex>
          {data.minutes === 0 ? (
            <View style={styles.emptyChart}>
              <Text type="Small" style={styles.emptyText}>
                No granted minutes in this period. Your activity will appear
                here after a session is granted.
              </Text>
            </View>
          ) : (
            <View style={styles.chart}>
              {data.buckets.map((bucket, index) => (
                <View
                  key={`${bucket.label}-${index}`}
                  style={styles.column}
                  accessible
                  accessibilityLabel={`${bucket.label}: ${bucket.minutes} granted minutes`}
                >
                  <Text type="ExtraSmall" style={styles.chartValue}>
                    {bucket.minutes}
                  </Text>
                  <View style={styles.barTrack}>
                    <View
                      style={[
                        styles.bar,
                        { height: `${(bucket.minutes / max) * 100}%` },
                      ]}
                    />
                  </View>
                  <Text type="ExtraSmall" style={styles.chartLabel}>
                    {bucket.label}
                  </Text>
                </View>
              ))}
            </View>
          )}
        </Flex>
      </VolitionCard>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    tabsRoot: { width: "100%" },
    tabsHost: { width: "100%" },
    tabsScroll: { flexGrow: 1 },
    segment: {
      flex: 1,
      backgroundColor: theme.colors.secondary,
      borderRadius: theme.radii.base,
      padding: theme.spacing.xxs,
      paddingRight: theme.spacing.xxs,
    },
    segmentButton: {
      minHeight: 44,
      borderRadius: theme.radii.sm,
      marginRight: 0,
    },
    segmentContent: { justifyContent: "center" },
    segmentLabel: { flex: 0 },
    segmentSelected: {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radii.sm,
    },
    segmentText: { color: theme.colors.textSecondary, textAlign: "center" },
    segmentSelectedText: { color: theme.colors.text },
    eyebrow: { color: theme.colors.textLink, letterSpacing: 0.8 },
    metrics: { justifyContent: "space-between" },
    metric: { flexGrow: 1, minWidth: 110 },
    chart: {
      flexDirection: "row",
      alignItems: "flex-end",
      gap: theme.spacing.xxs,
    },
    column: {
      flex: 1,
      alignItems: "center",
      gap: theme.spacing.xs,
      minWidth: 0,
    },
    chartValue: { textAlign: "center", color: theme.colors.textSecondary },
    barTrack: {
      height: 100,
      width: "100%",
      alignItems: "center",
      justifyContent: "flex-end",
      borderBottomWidth: 1,
      borderBottomColor: theme.colors.border,
    },
    bar: {
      width: "55%",
      maxWidth: 32,
      backgroundColor: theme.colors.accent,
      borderTopLeftRadius: theme.radii.sm,
      borderTopRightRadius: theme.radii.sm,
    },
    chartLabel: { textAlign: "center" },
    emptyChart: {
      minHeight: 100,
      justifyContent: "center",
      paddingVertical: theme.spacing.md,
    },
    emptyText: { textAlign: "center" },
  }) satisfies Record<string, ResponsiveStyle>;

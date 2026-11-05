import React from "react";
import {
  Button,
  Flex,
  Text,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { VolitionCard } from "../../../components/VolitionCard";
import type { FocusPeriod } from "../../../redux/focusSlice";
import { appSummary, formatSchedule } from "../focusPresentation";
export function PeriodCard({
  period,
  apps,
  onEdit,
  onToggle,
  onDelete,
}: {
  period: FocusPeriod;
  apps: { id: string; name: string }[];
  onEdit: () => void;
  onToggle: () => void;
  onDelete: () => void;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <VolitionCard>
      <Flex vertical gap="sm">
        <Flex
          wrap="wrap"
          alignItems="center"
          justifyContent="space-between"
          gap="xs"
        >
          <Text type="H3" style={styles.title}>
            {period.name}
          </Text>
          <Text
            type="Small"
            weight="SemiBold"
            style={period.isEnabled ? styles.enabled : styles.paused}
          >
            {period.isEnabled ? "Enabled" : "Paused"}
          </Text>
        </Flex>
        <Text>{formatSchedule(period)}</Text>
        <Text type="Small">Protects: {appSummary(period.appIDs, apps)}</Text>
        <Flex wrap="wrap" gap="xs">
          <Button
            layout="inline"
            text="Edit"
            variant="outline"
            onPress={onEdit}
          />
          <Button
            layout="inline"
            text={period.isEnabled ? "Pause" : "Enable"}
            variant="ghost"
            onPress={onToggle}
          />
          <Button
            layout="inline"
            text="Delete"
            variant="ghost"
            tone="danger"
            onPress={onDelete}
          />
        </Flex>
      </Flex>
    </VolitionCard>
  );
}
const createStyles = (theme: Theme) =>
  ({
    title: { flexShrink: 1 },
    enabled: { color: theme.colors.textLink },
    paused: { color: theme.colors.textSecondary },
  }) satisfies Record<string, ResponsiveStyle>;

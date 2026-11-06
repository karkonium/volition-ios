import React from "react";
import { useTranslation } from "react-i18next";
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
import { days, formatClock } from "../focusPresentation";
export function PeriodCard({
  period,
  apps,
  onEdit,
  onToggle,
  onDelete,
  busy,
}: {
  period: FocusPeriod;
  apps: { id: string; name: string }[];
  onEdit: () => void;
  onToggle: () => void;
  onDelete: () => void;
  busy: boolean;
}): React.JSX.Element {
  const { t, i18n } = useTranslation();
  const locale = i18n.resolvedLanguage;
  const selected = apps.filter(({ id }) => period.appIDs.includes(id));
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
            {period.isEnabled ? t("enabled") : t("paused")}
          </Text>
        </Flex>
        <Text>
          {days
            .filter((_, index) => period.weekdays.includes(index + 1))
            .map((day) => t(day))
            .join(", ")}
        </Text>
        <Text type="Small">
          {t("focusHours", {
            start: formatClock(period.startMinutes, locale),
            end: formatClock(period.endMinutes, locale),
          })}
          {period.endMinutes < period.startMinutes
            ? ` · ${t("focusNextDay")}`
            : ""}
        </Text>
        <Text type="Small">
          {period.allApps
            ? t("protects", { apps: t("focusAllSavedApps") })
            : selected.length
              ? t("protects", {
                  apps: selected.map(({ name }) => name).join(", "),
                })
              : t("focusChooseApps")}
        </Text>
        <Flex wrap="wrap" gap="xs">
          <Button
            layout="inline"
            disabled={busy}
            text={t("edit")}
            variant="outline"
            onPress={onEdit}
          />
          <Button
            layout="inline"
            disabled={busy}
            text={period.isEnabled ? t("pause") : t("enable")}
            variant="ghost"
            onPress={onToggle}
          />
          <Button
            layout="inline"
            disabled={busy}
            text={t("delete")}
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

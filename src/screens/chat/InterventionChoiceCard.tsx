import React from "react";
import { useTranslation } from "react-i18next";
import {
  Button,
  Flex,
  Icon,
  Text,
  Touchable,
  useThemedStyles,
  useTheme,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { perform } from "../../components/Screen";
import { layout } from "../../layout/layout";
import type { Intervention } from "../../redux/grantsSlice";
import { coordinator } from "../../services/runtime";
import { FocusTimingNote } from "./FocusTimingNote";
import { InterventionCard } from "./components/InterventionCard";

export function InterventionChoiceCard({
  offer,
  appName,
}: {
  offer: Intervention;
  appName: string;
}): React.JSX.Element {
  const { t } = useTranslation();
  const { theme } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { decision, appId, status } = offer;

  if (status === "interrupted" || status === "activating") {
    return (
      <InterventionCard
        label={appName}
        title={t(status === "activating" ? "checkingAccess" : "interrupted")}
      />
    );
  }

  const access = decision.unlock_minutes ?? 1;
  const rest = decision.block_minutes ?? 0;
  const seconds = decision.pause_seconds ?? (decision.wait_minutes ?? 1) * 60;
  const start = () => perform(() => coordinator.startDelay(appId));
  const deal = () => perform(() => coordinator.activate(appId, "deal"));
  const decline = () => perform(() => coordinator.keepLocked(appId));

  const timing = offer.focusLimitedUntil ? (
    <FocusTimingNote until={offer.focusLimitedUntil} />
  ) : null;
  if (["approve", "urgent", "frustration"].includes(decision.decision)) {
    return (
      <InterventionCard label={appName} title={t("focusShorterAccess")}>
        {timing}
        <Flex wrap="wrap" gap="xs">
          <Button
            layout="inline"
            text={t("unlockMinutes", { count: access })}
            onPress={() => perform(() => coordinator.activate(appId, "open"))}
          />
          <Button
            layout="inline"
            variant="outline"
            text={t("keepLocked")}
            onPress={decline}
          />
        </Flex>
      </InterventionCard>
    );
  }
  if (decision.decision === "choice") {
    const options = [
      {
        label: t("delayFor", { count: seconds }),
        icon: "timer-outline",
        action: start,
        testID: "startReflectionButton",
      },
      {
        label: t("chatDeal"),
        detail: t("chatBreakMinutes", { count: rest }),
        icon: "calendar-outline",
        action: deal,
      },
      {
        label: t("chatOpen"),
        detail: t("chatNoNewBreak"),
        icon: "lock-open-outline",
        action: () => perform(() => coordinator.activate(appId, "open")),
        quiet: true,
      },
    ];
    return (
      <InterventionCard label={appName} title={t("chooseWhatHelps")}>
        {timing}
        <Text type="Small">{t("chatChoiceAccess", { count: access })}</Text>
        <Flex vertical gap="xxs">
          {options.map((option) => (
            <Touchable
              key={option.icon}
              type="opacity"
              accessibilityRole="button"
              testID={option.testID}
              style={[styles.option, option.quiet && styles.quiet]}
              onPress={option.action}
            >
              <Icon
                name={option.icon}
                size={theme.typography.sizes.lg}
                color={theme.colors.textLink}
              />
              <Flex vertical flex={1}>
                <Text weight="SemiBold">{option.label}</Text>
                {option.detail && <Text type="Small">{option.detail}</Text>}
              </Flex>
              <Icon
                name="chevron-forward"
                size={theme.typography.sizes.sm}
                color={theme.colors.textSecondary}
              />
            </Touchable>
          ))}
        </Flex>
      </InterventionCard>
    );
  }

  const dealOffered =
    decision.decision === "deal" || decision.decision === "override";
  return (
    <InterventionCard
      label={appName}
      title={t(dealOffered ? "chatDeal" : "pauseBefore")}
    >
      {timing}
      {dealOffered && (
        <Flex vertical style={styles.terms}>
          <Text weight="SemiBold">
            {t("chatAccessMinutes", { count: access })}
          </Text>
          <Text type="Small">{t("chatBreakMinutes", { count: rest })}</Text>
        </Flex>
      )}
      <Flex wrap="wrap" gap="xs">
        <Button
          text={
            dealOffered
              ? t("chatAcceptDeal")
              : t("delayFor", { count: seconds })
          }
          layout="inline"
          buttonStyle={styles.action}
          testID={dealOffered ? undefined : "startReflectionButton"}
          onPress={dealOffered ? deal : start}
        />
        <Button
          text={t(dealOffered ? "chatDeclineDeal" : "keepLocked")}
          layout="inline"
          variant="ghost"
          buttonStyle={styles.action}
          onPress={decline}
        />
      </Flex>
    </InterventionCard>
  );
}

const createStyles = (theme: Theme) =>
  ({
    option: {
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.xs,
      minHeight: layout.minimumTouchSize,
      paddingHorizontal: theme.spacing.sm,
      paddingVertical: theme.spacing.xs,
      borderRadius: theme.radii.base,
      backgroundColor: theme.colors.secondary,
    },
    quiet: { backgroundColor: "transparent" },
    terms: {
      padding: theme.spacing.sm,
      backgroundColor: theme.colors.secondary,
      borderRadius: theme.radii.base,
      gap: theme.spacing.xxs,
    },
    action: {
      minHeight: layout.minimumTouchSize,
      paddingVertical: theme.spacing.xs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

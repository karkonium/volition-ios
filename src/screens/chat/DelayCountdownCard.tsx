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
import { useNow } from "../../components/ActiveGrantBanner";
import { perform } from "../../components/Screen";
import { layout } from "../../layout/layout";
import type { Intervention } from "../../redux/grantsSlice";
import { coordinator } from "../../services/runtime";
import { FocusTimingNote } from "./FocusTimingNote";
import { InterventionCard } from "./components/InterventionCard";

export function DelayCountdownCard({
  offer,
  appName,
}: {
  offer: Intervention;
  appName: string;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const now = useNow();
  const remaining =
    offer.status === "ready"
      ? 0
      : Math.max(0, Math.ceil((Date.parse(offer.deadline ?? "") - now) / 1000));
  const running = remaining > 0;

  return (
    <InterventionCard
      label={appName}
      title={running ? t("chatPause") : t("pauseEnded")}
    >
      {running ? (
        <Flex
          alignItems="center"
          justifyContent="space-between"
          wrap="wrap"
          gap="xs"
        >
          <Text
            weight="SemiBold"
            testID="reflectionCountdown"
            style={styles.seconds}
          >
            {t("pauseSeconds", { count: remaining })}
          </Text>
          <Button
            text={t("endDelay")}
            variant="ghost"
            layout="inline"
            buttonStyle={styles.action}
            testID="cancelReflectionButton"
            onPress={() => perform(() => coordinator.endDelay(offer.appId))}
          />
        </Flex>
      ) : (
        <>
          {offer.focusLimitedUntil && (
            <FocusTimingNote until={offer.focusLimitedUntil} />
          )}
          <Text type="Small" testID="reflectionCountdown">
            {t("chatPauseStillLocked", { app: appName })}
          </Text>
          <Flex wrap="wrap" gap="xs">
            <Button
              text={t("unlockMinutes", {
                count: offer.decision.unlock_minutes ?? 1,
              })}
              variant="soft"
              layout="inline"
              buttonStyle={styles.action}
              onPress={() =>
                perform(() => coordinator.activate(offer.appId, "delay"))
              }
            />
            <Button
              text={t("keepLocked")}
              layout="inline"
              buttonStyle={styles.action}
              onPress={() => perform(() => coordinator.keepLocked(offer.appId))}
            />
          </Flex>
        </>
      )}
    </InterventionCard>
  );
}

const createStyles = (theme: Theme) =>
  ({
    seconds: { fontVariant: ["tabular-nums"], flexShrink: 1 },
    action: {
      minHeight: layout.minimumTouchSize,
      paddingVertical: theme.spacing.xs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

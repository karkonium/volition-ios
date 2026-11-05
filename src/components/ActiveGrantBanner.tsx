import React, { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  Button,
  Flex,
  Icon,
  Text,
  colorWithOpacity,
  useTheme,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { layout } from "../layout/layout";
import type { ActiveGrant } from "../../modules/volition-screen-time";
export function useNow(): number {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);
  return now;
}
export function ActiveGrantBanner({
  grant,
  name,
  onEnd,
}: {
  grant: ActiveGrant;
  name: string;
  onEnd: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const { theme } = useTheme();
  const styles = useThemedStyles(createStyles);
  const seconds = Math.max(
    0,
    Math.ceil((Date.parse(grant.expiresAt) - useNow()) / 1000),
  );
  return (
    <Flex gap="xs" alignItems="center" wrap="wrap" style={styles.banner}>
      <Flex gap="xs" alignItems="center" style={styles.status}>
        <Icon
          name="lock-open-outline"
          size={theme.typography.sizes.lg}
          color={theme.colors.textLink}
        />
        <Text
          type="Small"
          weight="SemiBold"
          style={styles.name}
          numberOfLines={1}
        >
          {name}
        </Text>
        <Text type="Small" weight="SemiBold" style={styles.countdown}>
          {Math.floor(seconds / 60)}:{String(seconds % 60).padStart(2, "0")}
        </Text>
      </Flex>
      <Button
        text={t("endUnlock")}
        accessibilityLabel={t("chatEndAppUnlock", { app: name })}
        layout="inline"
        variant="ghost"
        buttonStyle={styles.action}
        textStyle={styles.actionLabel}
        testID="endConversationUnlockButton"
        onPress={onEnd}
      />
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    banner: {
      backgroundColor: colorWithOpacity(theme.colors.accent, 0.1),
      borderRadius: theme.radii.base,
      paddingHorizontal: theme.spacing.sm,
    },
    status: {
      flexGrow: 1,
      flexShrink: 1,
      minWidth: 120,
      paddingVertical: theme.spacing.xxs,
    },
    name: { flexShrink: 1, color: theme.colors.text },
    countdown: { fontVariant: ["tabular-nums"], color: theme.colors.textLink },
    action: { minHeight: layout.minimumTouchSize, padding: theme.spacing.xs },
    actionLabel: { fontSize: theme.typography.sizes.sm },
  }) satisfies Record<string, ResponsiveStyle>;

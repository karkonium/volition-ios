import React from "react";
import { useTranslation } from "react-i18next";
import {
  Flex,
  Text,
  colorWithOpacity,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import type { ChatMessage } from "../../../redux/chatSlice";

export function ConversationMessage({
  role,
  text,
}: Pick<ChatMessage, "role" | "text">): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const user = role === "user";

  return (
    <Flex vertical style={[styles.message, user && styles.userMessage]}>
      <Text
        type="ExtraSmall"
        weight="SemiBold"
        style={[styles.byline, user && styles.userByline]}
      >
        {user ? t("chatYou") : "Volition"}
      </Text>
      <Text selectable style={styles.body}>
        {text}
      </Text>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    message: {
      maxWidth: "94%",
      paddingHorizontal: theme.spacing.md,
      paddingVertical: theme.spacing.sm,
      borderRadius: theme.radii.md,
      borderTopLeftRadius: theme.radii.sm / 2,
      backgroundColor: theme.colors.card,
      gap: theme.spacing.xxs,
      alignSelf: "flex-start",
    },
    userMessage: {
      maxWidth: "86%",
      alignSelf: "flex-end",
      backgroundColor: colorWithOpacity(theme.colors.accent, 0.13),
      borderTopLeftRadius: theme.radii.md,
      borderTopRightRadius: theme.radii.sm / 2,
    },
    byline: { color: theme.colors.textSecondary },
    userByline: { color: theme.colors.textLink },
    body: {
      fontSize: theme.typography.sizes.md,
      lineHeight: theme.typography.sizes.md * theme.typography.lineHeights.loose,
    },
  }) satisfies Record<string, ResponsiveStyle>;

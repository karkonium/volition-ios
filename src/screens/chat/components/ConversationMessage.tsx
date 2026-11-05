import {
  colorWithOpacity,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import React from "react";
import { Flex, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
export function ConversationMessage({
  role,
  text,
}: {
  role: string;
  text: string;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <Flex
      vertical
      style={[styles.message, role === "user" && styles.userMessage]}
    >
      <Text type="ExtraSmall" weight="SemiBold">
        {role === "user" ? "YOU" : "VOLITION"}
      </Text>
      <Text selectable>{text}</Text>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    message: {
      maxWidth: "92%",
      padding: theme.spacing.md,
      borderRadius: theme.radii.md,
      borderWidth: 1,
      borderColor: theme.colors.border,
      backgroundColor: theme.colors.card,
      gap: theme.spacing.xxs,
      alignSelf: "flex-start",
      borderTopLeftRadius: theme.radii.sm / 2,
    },
    userMessage: {
      alignSelf: "flex-end",
      backgroundColor: colorWithOpacity(theme.colors.accent, 0.09),
      borderColor: "transparent",
      borderTopLeftRadius: theme.radii.md,
      borderBottomRightRadius: theme.radii.sm / 2,
    },
  }) satisfies Record<string, ResponsiveStyle>;

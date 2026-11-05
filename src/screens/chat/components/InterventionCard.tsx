import React, { type PropsWithChildren } from "react";
import {
  Flex,
  Text,
  colorWithOpacity,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { StyleSheet } from "react-native";

export function InterventionCard({
  label,
  title,
  children,
}: PropsWithChildren<{ label?: string; title: string }>): React.JSX.Element {
  const styles = useThemedStyles(createStyles);

  return (
    <Flex vertical style={styles.card}>
      <Flex vertical gap="xxs">
        {label && (
          <Text type="ExtraSmall" weight="SemiBold" style={styles.label}>
            {label}
          </Text>
        )}
        <Text type="H5" weight="SemiBold" accessibilityRole="header">
          {title}
        </Text>
      </Flex>
      {children}
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    card: {
      alignSelf: "flex-start",
      width: "100%",
      maxWidth: 520,
      padding: theme.spacing.sm,
      borderRadius: theme.radii.md,
      borderTopLeftRadius: theme.radii.sm / 2,
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: colorWithOpacity(theme.colors.accent, 0.35),
      backgroundColor: theme.colors.card,
      gap: theme.spacing.sm,
    },
    label: { color: theme.colors.textLink },
  }) satisfies Record<string, ResponsiveStyle>;

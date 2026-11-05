import React, { type PropsWithChildren } from "react";
import { View } from "react-native";
import {
  Text,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";

export function SettingsSection({
  title,
  footer,
  children,
}: PropsWithChildren<{ title: string; footer?: string }>): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.section}>
      <Text type="Small" weight="SemiBold" style={styles.heading}>
        {title}
      </Text>
      <View style={styles.content}>{children}</View>
      {footer && (
        <Text type="Small" style={styles.footer}>
          {footer}
        </Text>
      )}
    </View>
  );
}
const createStyles = (theme: Theme) =>
  ({
    section: { gap: theme.spacing.xs },
    heading: {
      marginHorizontal: theme.spacing.xs,
      color: theme.colors.textSecondary,
    },
    content: { gap: theme.spacing.xxs },
    footer: {
      marginHorizontal: theme.spacing.xs,
      color: theme.colors.textSecondary,
    },
  }) satisfies Record<string, ResponsiveStyle>;

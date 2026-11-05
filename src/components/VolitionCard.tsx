import React, { type PropsWithChildren } from "react";
import type { StyleProp, ViewStyle } from "react-native";
import {
  Card,
  colorWithOpacity,
  useThemedStyles,
} from "@itsRares/ahhzo-elements";
export function VolitionCard({
  children,
  accent = false,
  style,
}: PropsWithChildren<{
  accent?: boolean;
  style?: StyleProp<ViewStyle>;
}>): React.JSX.Element {
  const styles = useThemedStyles((theme) => ({
    card: {
      borderColor: accent
        ? colorWithOpacity(theme.colors.accent, 0.25)
        : theme.colors.border,
      backgroundColor: accent
        ? colorWithOpacity(theme.colors.accent, 0.07)
        : theme.colors.card,
    },
  }));
  return <Card style={[styles.card, style]}>{children}</Card>;
}

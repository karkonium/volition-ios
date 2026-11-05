import {
  colorWithOpacity,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import React from "react";
import { Button, useThemedStyles } from "@itsRares/ahhzo-elements";
interface ChoicePillProps {
  label: string;
  selected: boolean;
  onPress: () => void;
  testID?: string;
  multiple?: boolean;
}
export function ChoicePill({
  label,
  selected,
  onPress,
  testID,
  multiple = false,
}: ChoicePillProps): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <Button
      text={label}
      layout="inline"
      variant="ghost"
      buttonStyle={[styles.button, selected && styles.selected]}
      textStyle={[styles.text, selected && styles.selectedText]}
      accessibilityRole={multiple ? "checkbox" : "radio"}
      accessibilityState={{ checked: selected }}
      testID={testID}
      onPress={onPress}
    />
  );
}

const createStyles = (theme: Theme) =>
  ({
    button: {
      borderRadius: theme.radii.pill,
      paddingHorizontal: theme.spacing.md,
      backgroundColor: theme.colors.card,
      borderWidth: 1,
      borderColor: theme.colors.border,
    },
    selected: {
      backgroundColor: colorWithOpacity(theme.colors.accent, 0.1),
      borderColor: colorWithOpacity(theme.colors.accent, 0.4),
    },
    text: {
      fontSize: theme.typography.sizes.sm,
      color: theme.colors.textSecondary,
    },
    selectedText: { color: theme.colors.textLink },
  }) satisfies Record<string, ResponsiveStyle>;

import React from "react";
import { Pressable, View } from "react-native";
import {
  Text,
  colorWithOpacity,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";

export function FocusChoice({
  label,
  selected,
  onPress,
  multiple = false,
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
  multiple?: boolean;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <Pressable
      accessibilityRole={multiple ? "checkbox" : "radio"}
      accessibilityState={{ checked: selected }}
      onPress={onPress}
      style={styles.target}
    >
      <View style={[styles.pill, selected && styles.selected]}>
        <Text
          type="Small"
          weight="SemiBold"
          style={[styles.label, selected && styles.selectedLabel]}
        >
          {label}
        </Text>
      </View>
    </Pressable>
  );
}

const createStyles = (theme: Theme) =>
  ({
    target: {
      minHeight: 44,
      minWidth: 44,
      justifyContent: "center",
      maxWidth: "100%",
    },
    pill: {
      borderRadius: theme.radii.pill,
      borderWidth: 1,
      borderColor: theme.colors.border,
      backgroundColor: theme.colors.card,
      paddingHorizontal: theme.spacing.sm,
      paddingVertical: theme.spacing.xxs,
    },
    selected: {
      backgroundColor: colorWithOpacity(theme.colors.accent, 0.1),
      borderColor: colorWithOpacity(theme.colors.accent, 0.4),
    },
    label: { color: theme.colors.textSecondary },
    selectedLabel: { color: theme.colors.textLink },
  }) satisfies Record<string, ResponsiveStyle>;

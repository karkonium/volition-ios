import React, { useState } from "react";
import { Pressable, View } from "react-native";
import {
  Flex,
  Text,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { toggleSelection } from "../editorProfile";

export function ProfileQuestion({
  title,
  options,
  values,
  onChange,
  testID,
}: {
  title: string;
  options: { value: string; label: string }[];
  values: string[];
  onChange: (values: string[]) => void;
  testID?: string;
}) {
  const [expanded, setExpanded] = useState(false);
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.question}>
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ expanded }}
        onPress={() => setExpanded(!expanded)}
        testID={testID}
        style={styles.header}
      >
        <Text weight="SemiBold" style={styles.label}>
          {title}
        </Text>
        <Text style={styles.chevron}>{expanded ? "−" : "+"}</Text>
      </Pressable>
      {expanded && (
        <Flex vertical gap="xs">
          <Text type="Small">Select multiple</Text>
          {options.map((option) => {
            const selected = values.includes(option.value);
            return (
              <Pressable
                key={option.value}
                accessibilityRole="checkbox"
                accessibilityState={{ checked: selected }}
                testID={
                  testID === "profilePurposes"
                    ? `profilePurpose-${option.value}`
                    : undefined
                }
                onPress={() => onChange(toggleSelection(values, option.value))}
                style={styles.option}
              >
                <View style={[styles.box, selected && styles.checked]}>
                  <Text style={selected ? styles.checkmark : styles.emptyCheck}>
                    {selected ? "✓" : ""}
                  </Text>
                </View>
                <Text style={styles.label}>{option.label}</Text>
              </Pressable>
            );
          })}
        </Flex>
      )}
    </View>
  );
}
const createStyles = (theme: Theme) =>
  ({
    question: {
      borderTopWidth: 1,
      borderColor: theme.colors.border,
      paddingTop: theme.spacing.xs,
    },
    header: {
      minHeight: 44,
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "space-between",
      gap: theme.spacing.sm,
    },
    label: { flex: 1 },
    chevron: {
      color: theme.colors.textSecondary,
      fontSize: theme.typography.sizes.xl,
    },
    option: {
      minHeight: 44,
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.sm,
    },
    box: {
      width: 22,
      height: 22,
      borderWidth: 1,
      borderColor: theme.colors.textSecondary,
      borderRadius: theme.spacing.xxs,
      alignItems: "center",
      justifyContent: "center",
    },
    checked: {
      backgroundColor: theme.colors.accent,
      borderColor: theme.colors.accent,
    },
    checkmark: {
      color: theme.colors.buttonText,
      fontSize: theme.typography.sizes.sm,
    },
    emptyCheck: { color: theme.colors.text },
  }) satisfies Record<string, ResponsiveStyle>;

import React from "react";
import { Pressable, View } from "react-native";
import {
  Flex,
  Icon,
  Text,
  useTheme,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { VolitionAppIcon } from "../../../components/VolitionAppIcon";
import type { VolitionSavedApp } from "../../../redux/appsSlice";

export function AppRow({
  app,
  status,
  focusLinks,
  onEdit,
  onRemove,
}: {
  app: VolitionSavedApp;
  status: string;
  focusLinks: { id: string; label: string; open: () => void }[];
  onEdit: () => void;
  onRemove: () => void;
}) {
  const styles = useThemedStyles(createStyles);
  const { theme } = useTheme();
  return (
    <View style={styles.card}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Edit ${app.name}`}
        accessibilityHint="Opens app settings"
        onPress={onEdit}
        style={styles.main}
      >
        <Flex gap="sm" alignItems="center">
          <VolitionAppIcon
            key={app.tokenBase64}
            tokenBase64={app.tokenBase64}
          />
          <Flex vertical gap="xxs" style={styles.content}>
            <Text type="H3">{app.name}</Text>
            <Text type="Small" style={styles.status}>
              {status}
            </Text>
          </Flex>
          <Icon
            name="chevron-forward"
            family="Ionicons"
            size={theme.sizes.md}
            color={theme.colors.textSecondary}
            accessible={false}
          />
        </Flex>
        <Text type="Small">{app.goal}</Text>
      </Pressable>
      <View style={styles.footer}>
        {focusLinks.map(({ id, label, open }) => (
          <Pressable
            key={id}
            accessibilityRole="button"
            accessibilityLabel={label}
            onPress={open}
            style={styles.remove}
          >
            <Text type="Small" style={styles.status}>
              {label}
            </Text>
          </Pressable>
        ))}
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Remove ${app.name}`}
          onPress={onRemove}
          style={styles.remove}
        >
          <Text type="Small">Remove app</Text>
        </Pressable>
      </View>
    </View>
  );
}
const createStyles = (theme: Theme) =>
  ({
    card: {
      backgroundColor: theme.colors.card,
      borderColor: theme.colors.border,
      borderWidth: 1,
      borderRadius: theme.radii.md,
      overflow: "hidden",
    },
    main: {
      paddingHorizontal: theme.spacing.md,
      paddingTop: theme.spacing.md,
      paddingBottom: theme.spacing.sm,
      gap: theme.spacing.sm,
    },
    content: { flex: 1, minWidth: 0 },
    status: { color: theme.colors.textLink },
    footer: {
      borderTopWidth: 1,
      borderColor: theme.colors.border,
      paddingHorizontal: theme.spacing.md,
      alignItems: "flex-start",
    },
    remove: { minHeight: 44, justifyContent: "center" },
  }) satisfies Record<string, ResponsiveStyle>;

import React from "react";
import { useTranslation } from "react-i18next";
import { StyleSheet } from "react-native";
import {
  Flex,
  Icon,
  Text,
  Touchable,
  useThemedStyles,
  useTheme,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { AttentionRegion } from "../../../components/AttentionRegion";
import { VolitionAppIcon } from "../../../components/VolitionAppIcon";
import { layout } from "../../../layout/layout";
import type { VolitionSavedApp } from "../../../redux/appsSlice";

export function ChatHeader({
  app,
  attention,
  onChooseApp,
}: {
  app?: VolitionSavedApp;
  attention: number;
  onChooseApp: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const { theme } = useTheme();
  const styles = useThemedStyles(createStyles);

  return (
    <Flex vertical style={styles.header}>
      <Flex alignItems="center" justifyContent="space-between" gap="sm">
        <Text type="H3" accessibilityRole="header">
          {t("chat")}
        </Text>
        <Flex style={styles.selection}>
          <AttentionRegion trigger={attention}>
            <Touchable
              type="opacity"
              style={styles.chooser}
              testID="conversationChooseAppButton"
              accessibilityRole="button"
              accessibilityLabel={
                app
                  ? t("requestAccessLabel", { app: app.name })
                  : t("chooseApp")
              }
              onPress={onChooseApp}
            >
              {app ? (
                <Flex style={styles.iconSlot}>
                  <Flex style={styles.compactIcon}>
                    <VolitionAppIcon
                      key={app.tokenBase64}
                      tokenBase64={app.tokenBase64}
                    />
                  </Flex>
                </Flex>
              ) : (
                <Icon
                  name="apps-outline"
                  size={theme.typography.sizes.lg}
                  color={theme.colors.textLink}
                />
              )}
              <Text
                type="Small"
                weight="SemiBold"
                numberOfLines={1}
                style={app ? styles.appName : styles.chooseLabel}
              >
                {app?.name ?? t("chooseApp")}
              </Text>
              <Icon
                name="chevron-down"
                size={theme.typography.sizes.sm}
                color={theme.colors.textSecondary}
              />
            </Touchable>
          </AttentionRegion>
        </Flex>
      </Flex>
      {attention > 0 && (
        <Text
          type="Small"
          accessibilityLiveRegion="polite"
          testID="conversationAppSelectionHint"
          style={styles.hint}
        >
          {t("chooseAppHint")}
        </Text>
      )}
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    header: {
      width: "100%",
      maxWidth: layout.pageMaxWidth,
      alignSelf: "center",
      paddingHorizontal: theme.spacing.md,
      paddingVertical: theme.spacing.xxs,
      borderBottomWidth: StyleSheet.hairlineWidth,
      borderColor: theme.colors.border,
      gap: theme.spacing.xxs,
    },
    selection: { maxWidth: "76%", flexShrink: 1 },
    chooser: {
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.xs,
      backgroundColor: theme.colors.card,
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: theme.colors.border,
      borderRadius: theme.radii.base,
      paddingHorizontal: theme.spacing.sm,
      paddingVertical: theme.spacing.xxs,
      minHeight: layout.minimumTouchSize,
    },
    iconSlot: {
      width: theme.spacing.lg,
      height: theme.spacing.lg,
      alignItems: "center",
      justifyContent: "center",
    },
    compactIcon: { transform: [{ scale: 0.5 }] },
    appName: { flexShrink: 1, color: theme.colors.text },
    chooseLabel: { flexShrink: 1, color: theme.colors.textLink },
    hint: { color: theme.colors.textLink, alignSelf: "flex-end" },
  }) satisfies Record<string, ResponsiveStyle>;

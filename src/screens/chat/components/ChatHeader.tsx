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
      <Text type="H2" accessibilityRole="header">
        {t("chat")}
      </Text>
      <AttentionRegion trigger={attention}>
        <Touchable
          type="opacity"
          style={styles.chooser}
          testID="conversationChooseAppButton"
          accessibilityRole="button"
          accessibilityLabel={
            app ? t("requestAccessLabel", { app: app.name }) : t("chooseApp")
          }
          onPress={onChooseApp}
        >
          <VolitionAppIcon
            key={app?.tokenBase64}
            tokenBase64={app?.tokenBase64 ?? ""}
          />
          <Flex vertical flex={1} style={styles.appLabel}>
            <Text type="ExtraSmall">{t("requestAccessFor")}</Text>
            <Text
              weight="SemiBold"
              numberOfLines={1}
              style={!app && styles.chooseLabel}
            >
              {app?.name ?? t("chooseApp")}
            </Text>
          </Flex>
          <Icon
            name="chevron-down"
            size={theme.typography.sizes.sm}
            color={theme.colors.textSecondary}
          />
        </Touchable>
      </AttentionRegion>
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
      paddingVertical: theme.spacing.xs,
      borderBottomWidth: StyleSheet.hairlineWidth,
      borderColor: theme.colors.border,
      gap: theme.spacing.xs,
    },
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
    appLabel: { minWidth: 0 },
    chooseLabel: { color: theme.colors.textLink },
    hint: { color: theme.colors.textLink },
  }) satisfies Record<string, ResponsiveStyle>;

import { layout } from "../../../layout/layout";
import type { ResponsiveStyle, Theme } from "@itsRares/ahhzo-elements";
import React from "react";
import { useTranslation } from "react-i18next";
import { Keyboard } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import {
  Flex,
  Text,
  Icon,
  Touchable,
  useThemedStyles,
  useTheme,
} from "@itsRares/ahhzo-elements";
import { AttentionRegion } from "../../../components/AttentionRegion";
import { VolitionAppIcon } from "../../../components/VolitionAppIcon";
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
  const insets = useSafeAreaInsets();
  const styles = useThemedStyles(createStyles);
  return (
    <Flex
      vertical
      style={[styles.header, { paddingTop: insets.top + theme.spacing.sm }]}
    >
      <Flex
        alignItems="center"
        justifyContent="space-between"
        wrap="wrap"
        gap="xs"
      >
        <Text type="H2" accessibilityRole="header">
          {t("chat")}
        </Text>
        <Flex gap="xs" alignItems="center">
          <Icon
            name="sparkles-outline"
            family="Ionicons"
            size={theme.sizes.sm}
            color={theme.colors.textSecondary}
          />
          <Text type="Small">{t("chatMoment")}</Text>
        </Flex>
      </Flex>
      <AttentionRegion trigger={attention}>
        <Touchable
          type="opacity"
          style={styles.chooser}
          testID="conversationChooseAppButton"
          accessibilityRole="button"
          accessibilityLabel={
            app ? t("requestAccessLabel", { app: app.name }) : t("chooseApp")
          }
          onPress={() => {
            Keyboard.dismiss();
            onChooseApp();
          }}
        >
          <VolitionAppIcon tokenBase64={app?.tokenBase64 ?? ""} />
          <Flex vertical flex={1} gap="xxs">
            <Text type="ExtraSmall">{t("requestAccessFor")}</Text>
            <Text weight="SemiBold">{app?.name ?? t("chooseApp")}</Text>
          </Flex>
          <Icon
            name="chevron-down"
            family="Ionicons"
            size={theme.sizes.sm}
            color={theme.colors.textSecondary}
          />
        </Touchable>
      </AttentionRegion>
      {attention > 0 && (
        <Text type="Small" testID="conversationAppSelectionHint">
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
      paddingHorizontal: theme.spacing.lg,
      paddingBottom: theme.spacing.md,
      gap: theme.spacing.md,
    },
    chooser: {
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.sm,
      backgroundColor: theme.colors.card,
      borderWidth: 1,
      borderColor: theme.colors.border,
      borderRadius: theme.radii.md,
      padding: theme.spacing.sm,
      minHeight: 76,
    },
  }) satisfies Record<string, ResponsiveStyle>;

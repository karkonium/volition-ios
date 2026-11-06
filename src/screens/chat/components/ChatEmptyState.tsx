import React from "react";
import { useTranslation } from "react-i18next";
import { Image } from "react-native";
import {
  Flex,
  Text,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";

export function ChatEmptyState({
  appName,
}: {
  appName?: string;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  return (
    <Flex vertical style={styles.empty}>
      <Image
        source={require("../../../../assets/icon.png")}
        style={styles.logo}
        accessible={false}
      />
      <Text type="H2" style={styles.title}>
        {t("chatEmptyTitle")}
      </Text>
      <Text style={styles.prompt}>
        {appName
          ? t("chatEmptyBody", { app: appName })
          : t("chatPromptWithoutApp")}
      </Text>
      <Text type="Small" style={styles.caption}>
        {t("chatEmptyCaption")}
      </Text>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    empty: {
      flexGrow: 1,
      justifyContent: "center",
      alignItems: "center",
      alignSelf: "center",
      width: "100%",
      maxWidth: 360,
      paddingVertical: theme.spacing.lg,
      gap: theme.spacing.md,
    },
    logo: {
      width: theme.spacing.xxxl,
      height: theme.spacing.xxxl,
      borderRadius: theme.radii.md,
      marginBottom: theme.spacing.xxs,
    },
    title: { textAlign: "center" },
    prompt: {
      maxWidth: 300,
      textAlign: "center",
      color: theme.colors.textSecondary,
    },
    caption: { textAlign: "center", marginTop: theme.spacing.xxs },
  }) satisfies Record<string, ResponsiveStyle>;

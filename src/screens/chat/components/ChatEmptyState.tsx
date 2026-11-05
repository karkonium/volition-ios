import React from "react";
import { useTranslation } from "react-i18next";
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
      <Text type="H5" weight="Bold" style={styles.title}>
        {t("chatEmptyTitle")}
      </Text>
      <Text style={styles.prompt}>
        {appName
          ? t("chatPromptWithApp", { app: appName })
          : t("chatPromptWithoutApp")}
      </Text>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    empty: {
      flexGrow: 1,
      justifyContent: "center",
      alignSelf: "center",
      maxWidth: 320,
      paddingVertical: theme.spacing.lg,
      gap: theme.spacing.xs,
    },
    title: { textAlign: "center" },
    prompt: { textAlign: "center", color: theme.colors.textSecondary },
  }) satisfies Record<string, ResponsiveStyle>;

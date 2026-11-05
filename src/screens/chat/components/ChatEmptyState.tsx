import type { ResponsiveStyle, Theme } from "@itsRares/ahhzo-elements";
import React from "react";
import { Image } from "react-native";
import { Flex, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
export function ChatEmptyState({
  appName,
}: {
  appName?: string;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <Flex vertical style={styles.content}>
      <Image
        source={require("../../../../assets/icon.png")}
        style={styles.logo}
        accessibilityLabel="Volition"
      />
      <Text type="H2" style={styles.title}>
        A little intention.{"\n"}A better next step.
      </Text>
      <Text style={styles.body}>
        What brings you to {appName ?? "your app"}? Tell your coach what you
        have in mind.
      </Text>
      <Text type="Small" style={styles.caption}>
        A quick task. A little downtime. It all counts.
      </Text>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    content: {
      flex: 1,
      justifyContent: "center",
      alignItems: "center",
      paddingVertical: theme.spacing.xl,
      gap: theme.spacing.md,
    },
    logo: {
      width: 64,
      height: 64,
      borderRadius: theme.radii.md,
      marginBottom: theme.spacing.xxs,
    },
    title: { textAlign: "center" },
    body: {
      color: theme.colors.textSecondary,
      textAlign: "center",
      maxWidth: 290,
    },
    caption: { textAlign: "center", marginTop: theme.spacing.xs },
  }) satisfies Record<string, ResponsiveStyle>;

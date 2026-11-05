import React from "react";
import { Flex, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
export function VolitionSectionHeading({
  title,
  detail,
}: {
  title: string;
  detail?: string;
}): React.JSX.Element {
  const styles = useThemedStyles((theme) => ({
    row: { marginTop: theme.spacing.sm, gap: 8, flexWrap: "wrap" as const },
    title: {
      flexGrow: 1,
      color: theme.colors.text,
      fontSize: 18,
      fontWeight: "600" as const,
      letterSpacing: -0.3,
    },
  }));
  return (
    <Flex alignItems="center" style={styles.row}>
      <Text accessibilityRole="header" style={styles.title}>
        {title}
      </Text>
      {detail && <Text type="Small">{detail}</Text>}
    </Flex>
  );
}

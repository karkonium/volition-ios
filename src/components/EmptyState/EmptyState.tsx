import type { ResponsiveStyle, Theme } from "@itsRares/ahhzo-elements";
import React from "react";
import { Flex, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
import { VolitionCard } from "../VolitionCard";
import { SymbolTile } from "../SymbolTile/SymbolTile";
export function EmptyState({
  icon,
  title,
  description,
}: {
  icon: string;
  title: string;
  description: string;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <VolitionCard>
      <Flex vertical alignItems="center" gap="sm" style={styles.content}>
        <SymbolTile name={icon} large />
        <Text type="H3" style={styles.title}>
          {title}
        </Text>
        <Text type="Small" style={styles.description}>
          {description}
        </Text>
      </Flex>
    </VolitionCard>
  );
}

const createStyles = (theme: Theme) =>
  ({
    content: { paddingVertical: theme.spacing.lg },
    title: { textAlign: "center" },
    description: { textAlign: "center", maxWidth: 290 },
  }) satisfies Record<string, ResponsiveStyle>;

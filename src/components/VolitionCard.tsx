import React, { type PropsWithChildren } from "react";
import { Card, useThemedStyles } from "@itsRares/ahhzo-elements";
export function VolitionCard({
  children,
  accent = false,
}: PropsWithChildren<{ accent?: boolean }>): React.JSX.Element {
  const styles = useThemedStyles((theme) => ({
    card: {
      marginBottom: theme.spacing.md,
      borderColor: accent ? theme.colors.accent : theme.colors.border,
      backgroundColor: theme.colors.card,
    },
  }));
  return <Card style={styles.card}>{children}</Card>;
}

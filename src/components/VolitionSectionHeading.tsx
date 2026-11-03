import React from "react";
import { Text, useThemedStyles } from "@itsRares/ahhzo-elements";
export function VolitionSectionHeading({
  title,
}: {
  title: string;
}): React.JSX.Element {
  const styles = useThemedStyles((theme) => ({
    heading: { marginVertical: theme.spacing.md, color: theme.colors.text },
  }));
  return (
    <Text type="H3" style={styles.heading}>
      {title}
    </Text>
  );
}

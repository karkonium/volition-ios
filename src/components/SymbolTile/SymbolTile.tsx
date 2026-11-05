import {
  colorWithOpacity,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import React from "react";
import {
  Flex,
  Icon,
  useTheme,
  useThemedStyles,
} from "@itsRares/ahhzo-elements";

export function SymbolTile({
  name,
  large = false,
}: {
  name: string;
  large?: boolean;
}): React.JSX.Element {
  const { theme } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <Flex
      alignItems="center"
      justifyContent="center"
      style={[styles.tile, large && styles.large]}
    >
      <Icon
        name={name}
        family="Ionicons"
        size={large ? theme.sizes.xxl : theme.sizes.md}
        color={theme.colors.textLink}
        accessible={false}
      />
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    tile: {
      width: 40,
      height: 40,
      borderRadius: theme.radii.base,
      backgroundColor: colorWithOpacity(theme.colors.accent, 0.09),
    },
    large: { width: 64, height: 64, borderRadius: theme.radii.md },
  }) satisfies Record<string, ResponsiveStyle>;

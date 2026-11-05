import { volitionTheme } from "./designSystem";
import Ionicons from "@expo/vector-icons/Ionicons";
import {
  createTheme,
  IconProvider,
  ThemeProvider,
  type Theme,
} from "@itsRares/ahhzo-elements";
import React, { useMemo, type PropsWithChildren } from "react";
import { useColorScheme } from "react-native";
import {
  useSafeAreaInsets,
  type EdgeInsets,
} from "react-native-safe-area-context";

const libraries = {
  Ionicons: (props: React.ComponentProps<typeof Ionicons>) => (
    <Ionicons {...props} />
  ),
};

export function createVolitionTheme(
  scheme: "light" | "dark",
  insets: EdgeInsets,
): Theme {
  return createTheme(volitionTheme(scheme, insets), scheme);
}

export function VolitionThemeProvider({ children }: PropsWithChildren) {
  const scheme = useColorScheme() === "dark" ? "dark" : "light";
  const insets = useSafeAreaInsets();
  const theme = useMemo(
    () => createVolitionTheme(scheme, insets),
    [scheme, insets],
  );

  return (
    <ThemeProvider
      initialMode="system"
      colorSchemeOverride={scheme}
      overrides={theme}
    >
      <IconProvider libraries={libraries}>{children}</IconProvider>
    </ThemeProvider>
  );
}

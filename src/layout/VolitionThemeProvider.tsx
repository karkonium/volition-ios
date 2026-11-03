import { volitionColors } from "./colors";
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
  const theme = createTheme(
    {
      colors: volitionColors(scheme),
      radii: {
        sm: 8,
        base: 12,
        md: 16,
        lg: 20,
        pill: 999,
      },
    },
    scheme,
  );

  const { spacing, radii, typography } = theme;

  return {
    ...theme,
    components: {
      Page: {
        containerStyle: {
          width: "100%",
          maxWidth: 720,
          alignSelf: "center",
          flexGrow: 1,
          paddingHorizontal: spacing.md,
        },
        scrollContentStyle: {
          paddingBottom: spacing.xl,
        },
      },
      Card: {
        containerStyle: {
          borderRadius: radii.md,
          padding: spacing.md,
          borderWidth: 1,
          borderColor:
            scheme === "dark" ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)",
        },
      },
      Button: {
        buttonStyle: {
          minHeight: 48,
          borderRadius: radii.base,
          paddingVertical: spacing.sm,
          paddingHorizontal: spacing.md,
        },
        textStyle: {
          fontSize: typography.sizes.md,
          fontWeight: "600",
          textAlign: "center",
        },
      },
      IconButton: {
        touchableStyle: {
          minWidth: 44,
          minHeight: 44,
          alignItems: "center",
          justifyContent: "center",
        },
      },
      TextField: {
        inputStyle: {
          minHeight: 48,
          borderRadius: radii.base,
          paddingHorizontal: spacing.md,
          fontSize: typography.sizes.md,
        },
      },
      Modal: {
        defaults: {
          presentation: "bottom",
          keyboardBehavior: "padding",
          avoidKeyboard: false,
        },
        contentContainerStyle: {
          width: "100%",
          maxWidth: 640,
          alignSelf: "center",
          borderRadius: radii.lg,
          padding: spacing.md,
        },
      },
    },
  };
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

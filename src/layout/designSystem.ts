import type { ThemeOverrides } from "@itsRares/ahhzo-elements";
import { volitionColors } from "./colors";
import { layout } from "./layout";

/** Owns the shared visual language; screen styles supply layout, not new themes. */
export function volitionTheme(
  scheme: "light" | "dark",
  insets: { top: number; bottom: number; left: number; right: number },
): ThemeOverrides {
  const colors = volitionColors(scheme);
  return {
    colors,
    typography: {
      fontFamily: "System",
      fontFamilies: {
        Regular: "System",
        Medium: "System",
        SemiBold: "System",
        Bold: "System",
        ExtraBold: "System",
      },
      sizes: {
        xs: 11,
        sm: 13,
        md: 16,
        lg: 17,
        xl: 18,
        xxl: 19,
        xxxl: 21,
        xxxxl: 28,
        xxxxxl: 34,
        title: 34,
      },
      lineHeights: { tight: 1.35, normal: 1.45, loose: 1.6 },
    },
    spacing: {
      xxs: 4,
      xs: 8,
      sm: 12,
      md: 16,
      lg: 24,
      xl: 32,
      xxl: 48,
      xxxl: 64,
      xxxxl: 96,
      basePadding: 20,
    },
    radii: { sm: 12, base: 14, md: 20, lg: 28, pill: 999 },
    components: {
      Page: {
        containerStyle: {
          width: "100%",
          maxWidth: layout.pageMaxWidth,
          alignSelf: "center",
          flexGrow: 1,
          justifyContent: "flex-start",
          paddingHorizontal: 20,
        },
        scrollContentStyle: { paddingBottom: 32 },
      },
      Text: {
        types: {
          H1: { fontWeight: "700", letterSpacing: -1.1 },
          H2: { fontWeight: "700", letterSpacing: -0.7 },
          H3: { fontWeight: "600", letterSpacing: -0.35 },
          H4: { fontWeight: "600" },
          Small: { color: colors.textSecondary },
          ExtraSmall: { color: colors.textSecondary },
        },
      },
      Header: {
        containerStyle: {
          marginTop: 0,
          marginBottom: 0,
          padding: 0,
          paddingTop: 16,
          paddingBottom: 24,
        },
        leftIconContainerStyle: { flex: 1, minWidth: 0 },
        titleTextStyle: {
          width: "100%",
          marginLeft: 0,
          fontSize: 34,
          lineHeight: 41,
          fontWeight: "700",
          letterSpacing: -1.1,
        },
        subtitleTextStyle: {
          width: "100%",
          marginLeft: 0,
          color: colors.textSecondary,
          fontSize: 15,
          lineHeight: 22,
          marginTop: 4,
        },
      },
      Card: {
        containerStyle: {
          borderRadius: 20,
          padding: 20,
          marginVertical: 0,
          borderWidth: 1,
          borderColor: colors.border,
        },
        sectionStyle: { padding: 0 },
        contentStyle: { gap: 12 },
      },
      Button: {
        defaults: { layout: "block" },
        containerStyle: { marginVertical: 0 },
        buttonStyle: {
          minHeight: 48,
          borderRadius: 14,
          paddingVertical: 12,
          paddingHorizontal: 16,
        },
        textStyle: {
          fontFamily: "System",
          fontSize: 16,
          fontWeight: "600",
          lineHeight: 22,
          textAlign: "center",
          flexShrink: 1,
          paddingHorizontal: 0,
        },
      },
      IconButton: {
        containerStyle: { alignSelf: "center" },
        touchableStyle: {
          minWidth: 44,
          minHeight: 44,
          borderRadius: 14,
          alignItems: "center",
          justifyContent: "center",
        },
      },
      TextField: {
        iconSize: 20,
        containerStyle: { marginVertical: 0 },
        inputStyle: {
          minHeight: 50,
          borderRadius: 14,
          borderWidth: 1,
          borderColor: colors.border,
          paddingHorizontal: 14,
          paddingVertical: 12,
          marginVertical: 0,
          fontFamily: "System",
          fontSize: 16,
          lineHeight: 22,
        },
      },
      SettingsRow: {
        containerStyle: {
          backgroundColor: colors.card,
          minHeight: 68,
          paddingHorizontal: 16,
          paddingVertical: 12,
          marginVertical: 0,
          borderRadius: 16,
        },
        titleStyle: { fontSize: 16, fontWeight: "600", color: colors.text },
        descriptionStyle: { fontSize: 13, color: colors.textSecondary },
      },
      Modal: {
        defaults: {
          presentation: "centered",
          keyboardBehavior: "padding",
          avoidKeyboard: false,
        },
        modalStyle: {
          marginTop: insets.top + 8,
          marginBottom: insets.bottom + 8,
          marginLeft: insets.left + 12,
          marginRight: insets.right + 12,
        },
        contentContainerStyle: {
          width: "100%",
          maxWidth: layout.modalMaxWidth,
          maxHeight: "100%",
          alignSelf: "center",
          borderRadius: 28,
          padding: 24,
        },
        titleTextStyle: {
          flex: 1,
          minWidth: 0,
          fontSize: 24,
          fontWeight: "700",
          letterSpacing: -0.5,
        },
        iconContainerStyle: {
          minWidth: 44,
          minHeight: 44,
          alignItems: "center",
          justifyContent: "center",
        },
      },
    },
  };
}

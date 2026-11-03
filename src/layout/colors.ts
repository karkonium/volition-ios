export const volitionColors = (scheme: "light" | "dark") =>
  scheme === "dark"
    ? {
        background: "#000000",
        card: "#161B26",
        modalBackground: "#161B26",
        overlay: "rgba(0, 0, 0, 0.65)",
        accent: "#3B82F6",
        textLink: "#60A5FA",
        success: "#34D399",
        warning: "#FBBF24",
        danger: "#EF4444",
        error: "#EF4444",
        tabBarBackground: "#0B0F17",
        tabBarActiveTintColor: "#3B82F6",
      }
    : {
        background: "#F8FAFC",
        card: "#FFFFFF",
        modalBackground: "#FFFFFF",
        overlay: "rgba(0, 0, 0, 0.4)",
        accent: "#2563EB",
        textLink: "#2563EB",
        success: "#059669",
        warning: "#D97706",
        danger: "#DC2626",
        error: "#DC2626",
        tabBarBackground: "#FFFFFF",
        tabBarActiveTintColor: "#2563EB",
      };

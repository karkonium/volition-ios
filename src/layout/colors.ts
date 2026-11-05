/** Complete semantic palette: Elements controls must share the same blue and ink. */
export function volitionColors(scheme: "light" | "dark") {
  const dark = scheme === "dark";
  const background = dark ? "#101114" : "#F4F5F8";
  const card = dark ? "#1C1D22" : "#FFFFFF";
  const text = dark ? "#F5F6FA" : "#171C28";
  const secondary = dark ? "#A5ABB8" : "#646C7D";
  const border = dark ? "#30323B" : "#E5E8EF";
  const subtle = dark ? "#252730" : "#EEF1F6";
  const accent = dark ? "#286BDB" : "#2361D9";
  return {
    background,
    card,
    text,
    textSecondary: secondary,
    textMuted: secondary,
    textTertiary: secondary,
    tertiary: text,
    border,
    primary: card,
    secondary: subtle,
    accent,
    textLink: dark ? "#8DB7FF" : accent,
    button: accent,
    buttonText: "#FFFFFF",
    buttonPrimary: accent,
    buttonPrimaryText: "#FFFFFF",
    buttonSecondary: subtle,
    buttonSecondaryText: text,
    inputBackground: card,
    inputBorder: border,
    inputText: text,
    inputplaceholderLabel: secondary,
    modalBackground: card,
    overlay: "#000000",
    success: dark ? "#71D5B1" : "#23765E",
    warning: dark ? "#EFC57A" : "#946017",
    danger: dark ? "#FF9197" : "#BA3544",
    error: dark ? "#FF9197" : "#BA3544",
    tabBarBackground: card,
    tabBarActiveTintColor: dark ? "#8DB7FF" : accent,
    notification: accent,
  };
}

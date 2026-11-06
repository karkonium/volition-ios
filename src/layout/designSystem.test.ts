import { volitionTheme } from "./designSystem";

function luminance(hex: string): number {
  const channels = hex
    .slice(1)
    .match(/../g)!
    .map((part) => {
      const value = parseInt(part, 16) / 255;
      return value <= 0.04045
        ? value / 12.92
        : ((value + 0.055) / 1.055) ** 2.4;
    });
  return channels[0]! * 0.2126 + channels[1]! * 0.7152 + channels[2]! * 0.0722;
}

describe.each(["light", "dark"] as const)("%s presentation", (scheme) => {
  const theme = volitionTheme(scheme, {
    top: 59,
    bottom: 34,
    left: 0,
    right: 0,
  });
  it("keeps body, secondary labels and primary actions readable", () => {
    const colors = theme.colors!;
    for (const [foreground, background] of [
      [colors.text!, colors.background!],
      [colors.textSecondary!, colors.card!],
      [colors.buttonPrimaryText!, colors.buttonPrimary!],
      [colors.inputText!, colors.inputBackground!],
    ] as const) {
      const values = [luminance(foreground), luminance(background)].sort(
        (a, b) => b - a,
      );
      expect((values[0]! + 0.05) / (values[1]! + 0.05)).toBeGreaterThanOrEqual(
        4.5,
      );
    }
    expect(colors.buttonPrimary).toBe(colors.accent);
  });
  it("keeps actions touchable and sheets inside safe areas", () => {
    expect(theme.components!.Button!.buttonStyle).toMatchObject({
      minHeight: 48,
    });
    expect(theme.components!.IconButton!.touchableStyle).toMatchObject({
      minWidth: 44,
      minHeight: 44,
    });
    expect(theme.components!.Modal!.modalStyle).toMatchObject({
      marginTop: 67,
      marginBottom: 42,
    });
  });
});

it("keeps page headers compact below the safe area", () => {
  const theme = volitionTheme("light", {
    top: 59,
    bottom: 34,
    left: 0,
    right: 0,
  });
  expect(theme.components!.Header!.containerStyle).toMatchObject({
    paddingTop: 4,
  });
  expect(theme.components!.Header!.iconRowStyle).toMatchObject({
    marginBottom: 4,
  });
});

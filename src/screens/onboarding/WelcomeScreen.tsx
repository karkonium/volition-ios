import React from "react";
import { Image, Platform, View } from "react-native";
import { useTranslation } from "react-i18next";
import {
  Button,
  Text,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { OnboardingFrame } from "./OnboardingFrame";

export function WelcomeScreen({
  onContinue,
}: {
  onContinue: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  return (
    <OnboardingFrame step={1}>
      <View style={styles.content}>
        <View style={styles.hero}>
          <Image
            source={require("../../../assets/icon.png")}
            style={styles.logo}
            accessibilityLabel="Volition"
          />
          <Text type="Small" weight="Bold" style={styles.eyebrow}>
            VOLITION
          </Text>
          <Text type="H1" style={styles.title}>
            {t("welcomeTitle")}
          </Text>
          <Text style={styles.description}>{t("welcomeBody")}</Text>
        </View>
        <View style={styles.preview}>
          <Text type="Small" weight="Bold" style={styles.previewLabel}>
            {t("onboardingSetupPreview")}
          </Text>
          {[
            t("welcomeStep1"),
            t(
              Platform.OS === "android"
                ? "androidWelcomeBlocking"
                : "welcomeStep2",
            ),
            t("welcomeStep3"),
          ].map((item) => (
            <Text key={item} style={styles.step}>
              {item}
            </Text>
          ))}
        </View>
        <Button text={t("getStarted")} onPress={onContinue} />
      </View>
    </OnboardingFrame>
  );
}
const createStyles = (theme: Theme) =>
  ({
    content: {
      flexGrow: 1,
      justifyContent: "center",
      gap: theme.spacing.lg,
      paddingVertical: theme.spacing.md,
    },
    hero: { alignItems: "center", gap: theme.spacing.sm },
    logo: {
      width: 104,
      height: 104,
      borderRadius: theme.radii.lg,
      marginBottom: theme.spacing.xs,
    },
    eyebrow: { color: theme.colors.textSecondary, letterSpacing: 2 },
    title: { textAlign: "center" },
    description: {
      color: theme.colors.textSecondary,
      textAlign: "center",
      maxWidth: 480,
    },
    preview: {
      backgroundColor: theme.colors.card,
      borderColor: theme.colors.border,
      borderWidth: 1,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      gap: theme.spacing.xs,
    },
    previewLabel: { color: theme.colors.textSecondary, letterSpacing: 0.5 },
    step: { color: theme.colors.text },
  }) satisfies Record<string, ResponsiveStyle>;

import React from "react";
import { View } from "react-native";
import { useTranslation } from "react-i18next";
import {
  Text,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { AppEditorForm } from "../apps/AppEditorForm";
import { OnboardingFrame } from "./OnboardingFrame";
export function SetupFirstAppScreen({
  onSaved,
  onBack,
}: {
  onSaved: () => void;
  onBack?: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  return (
    <OnboardingFrame step={4} onBack={onBack}>
      <View style={styles.content}>
        <View style={styles.heading}>
          <Text type="H1">{t("firstApp")}</Text>
          <Text type="Small">{t("onboardingFirstAppIntro")}</Text>
        </View>
        <AppEditorForm onSaved={onSaved} />
      </View>
    </OnboardingFrame>
  );
}
const createStyles = (theme: Theme) =>
  ({
    content: { gap: theme.spacing.lg, paddingVertical: theme.spacing.md },
    heading: { gap: theme.spacing.xs },
  }) satisfies Record<string, ResponsiveStyle>;

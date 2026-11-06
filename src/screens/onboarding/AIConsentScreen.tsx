import React, { useState } from "react";
import { Switch, View } from "react-native";
import { useTranslation } from "react-i18next";
import {
  Button,
  Text,
  useTheme,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { useAppSelector } from "../../redux/store";
import { setConsent } from "../../services/runtime";
import { OnboardingFrame } from "./OnboardingFrame";

export function AIConsentScreen({
  onContinue,
  onBack,
}: {
  onContinue: () => void;
  onBack: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const { theme } = useTheme();
  const consent = useAppSelector((state) => state.auth.aiConsent);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const change = async (value: boolean): Promise<void> => {
    setBusy(true);
    setFailed(false);
    try {
      await setConsent(value);
    } catch {
      setFailed(true);
    } finally {
      setBusy(false);
    }
  };
  return (
    <OnboardingFrame step={2} onBack={onBack}>
      <View style={styles.content}>
        <View style={styles.heading}>
          <Text type="H1">{t("consentTitle")}</Text>
          <Text style={styles.secondary}>{t("onboardingConsentIntro")}</Text>
        </View>
        <View style={styles.choice}>
          <View style={styles.choiceCopy}>
            <Text weight="SemiBold">{t("onboardingSharingLabel")}</Text>
            <Text type="Small">
              {consent ? t("sharingOnDescription") : t("sharingOffDescription")}
            </Text>
          </View>
          <Switch
            accessibilityLabel={t("onboardingSharingLabel")}
            value={consent}
            disabled={busy}
            onValueChange={(value) => void change(value)}
            trackColor={{ true: theme.colors.accent }}
          />
        </View>
        <View style={styles.disclosure}>
          <View style={styles.group}>
            <Text weight="SemiBold">{t("onboardingSentTitle")}</Text>
            <Text type="Small">{t("consentBody")}</Text>
          </View>
          <View style={styles.group}>
            <Text weight="SemiBold">{t("onboardingDeviceTitle")}</Text>
            <Text type="Small">{t("onboardingDeviceBody")}</Text>
          </View>
          <View style={styles.group}>
            <Text weight="SemiBold">{t("onboardingControlTitle")}</Text>
            <Text type="Small">{t("onboardingControlBody")}</Text>
          </View>
        </View>
        {failed && (
          <Text accessibilityRole="alert" style={styles.error}>
            {t("onboardingConsentError")}
          </Text>
        )}
        <Button
          text={consent ? t("continue") : t("onboardingContinueOff")}
          disabled={busy || failed}
          onPress={onContinue}
        />
        {failed && (
          <Button
            text={t("onboardingRetry")}
            variant="ghost"
            onPress={() => void change(consent)}
          />
        )}
      </View>
    </OnboardingFrame>
  );
}
const createStyles = (theme: Theme) =>
  ({
    content: {
      flexGrow: 1,
      justifyContent: "center",
      gap: theme.spacing.md,
      paddingVertical: theme.spacing.md,
    },
    heading: { gap: theme.spacing.xs },
    secondary: { color: theme.colors.textSecondary },
    choice: {
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.md,
      backgroundColor: theme.colors.card,
      borderWidth: 1,
      borderColor: theme.colors.border,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      minHeight: 72,
    },
    choiceCopy: { flex: 1, gap: theme.spacing.xxs },
    disclosure: { gap: theme.spacing.md, paddingVertical: theme.spacing.xs },
    group: { gap: theme.spacing.xxs },
    error: { color: theme.colors.error },
  }) satisfies Record<string, ResponsiveStyle>;

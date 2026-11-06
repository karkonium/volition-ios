import React, { useEffect, useState } from "react";
import { AppState, Linking, Platform, View } from "react-native";
import { useTranslation } from "react-i18next";
import {
  Button,
  Icon,
  Text,
  useTheme,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { VolitionScreenTime } from "../../../modules/volition-screen-time";
import { useAppDispatch, useAppSelector } from "../../redux/store";
import { authActions } from "../../redux/authSlice";
import { diagnostic } from "../../services/diagnostics";
import { requestScreenTimeAuthorization } from "./authorization";
import { OnboardingFrame } from "./OnboardingFrame";

export function ScreenTimeGateScreen({
  onApproved,
  onBack,
}: {
  onApproved: () => void;
  onBack?: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const android = Platform.OS === "android";
  const styles = useThemedStyles(createStyles);
  const { theme } = useTheme();
  const dispatch = useAppDispatch();
  const status = useAppSelector((state) => state.auth.authorization);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<"dismissed" | "failed" | null>(null);
  const [returning, setReturning] = useState(false);
  useEffect(() => {
    const listener = AppState.addEventListener("change", (next) => {
      if (next !== "active" || !returning) return;
      setReturning(false);
      try {
        const current = VolitionScreenTime.getAuthorizationStatus();
        dispatch(authActions.authorizationChanged(current));
        if (current === "approved") onApproved();
      } catch {
        diagnostic("authorization.settings_failed");
        setNotice("failed");
      }
    });
    return () => listener.remove();
  }, [returning, dispatch, onApproved]);
  const request = async (): Promise<void> => {
    setBusy(true);
    setNotice(null);
    try {
      const result = await requestScreenTimeAuthorization(VolitionScreenTime);
      dispatch(authActions.authorizationChanged(result.status));
      if (result.failed) diagnostic("authorization.request_failed");
      if (result.status === "approved") onApproved();
      else setNotice(result.failed ? "failed" : "dismissed");
    } catch {
      diagnostic("authorization.request_failed");
      setNotice("failed");
    } finally {
      setBusy(false);
    }
  };
  const openSettings = async (): Promise<void> => {
    try {
      setReturning(true);
      await Linking.openSettings();
    } catch {
      setReturning(false);
      diagnostic("authorization.settings_failed");
      setNotice("failed");
    }
  };
  return (
    <OnboardingFrame step={3} onBack={onBack}>
      <View style={styles.content}>
        <View style={styles.intro}>
          <View style={styles.icon}>
            <Icon
              name="hourglass-outline"
              family="Ionicons"
              size={32}
              color={theme.colors.textLink}
              accessible={false}
            />
          </View>
          <Text type="H1">
            {t(android ? "androidBlockingTitle" : "screenTimeTitle")}
          </Text>
          <Text style={styles.secondary}>
            {t(android ? "androidBlockingIntro" : "onboardingScreenTimeIntro")}
          </Text>
        </View>
        <View style={styles.card}>
          <Text weight="SemiBold">{t("onboardingSelectedTitle")}</Text>
          <Text type="Small">
            {t(android ? "androidBlockingDisclosure" : "screenTimeBody")}
          </Text>
        </View>
        {(status === "denied" || notice) && (
          <Text accessibilityRole="alert" style={styles.notice}>
            {android
              ? t("androidBlockingUnavailable")
              : status === "denied"
                ? t("onboardingPermissionDenied")
                : notice === "failed"
                  ? t("onboardingPermissionFailed")
                  : t("onboardingPermissionDismissed")}
          </Text>
        )}
        <View style={styles.actions}>
          <Button
            text={
              status === "approved"
                ? t("continue")
                : t(
                    android
                      ? "androidBlockingAllow"
                      : "onboardingAllowScreenTime",
                  )
            }
            loading={busy}
            disabled={busy}
            onPress={() =>
              status === "approved" ? onApproved() : void request()
            }
          />
          {!android && (
            <Button
              text={t("openSettings")}
              variant="ghost"
              disabled={busy}
              onPress={() => void openSettings()}
            />
          )}
        </View>
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
    intro: { gap: theme.spacing.sm },
    icon: {
      width: 64,
      height: 64,
      alignItems: "center",
      justifyContent: "center",
      borderRadius: theme.radii.md,
      backgroundColor: theme.colors.secondary,
      marginBottom: theme.spacing.xs,
    },
    secondary: { color: theme.colors.textSecondary },
    card: {
      backgroundColor: theme.colors.card,
      borderWidth: 1,
      borderColor: theme.colors.border,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      gap: theme.spacing.xs,
    },
    notice: { color: theme.colors.textSecondary },
    actions: { gap: theme.spacing.xs },
  }) satisfies Record<string, ResponsiveStyle>;

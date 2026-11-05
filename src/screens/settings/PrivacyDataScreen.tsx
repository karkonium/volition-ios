import React from "react";
import { useTranslation } from "react-i18next";
import { Alert, View } from "react-native";
import {
  Button,
  SettingsRow,
  Text,
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { grantsActions } from "../../redux/grantsSlice";
import { chatActions } from "../../redux/chatSlice";
import { settingsActions } from "../../redux/settingsSlice";
import { firebaseConfigured } from "../../services/telemetry";
import { setConsent, coordinator } from "../../services/runtime";
import { SettingsSection } from "./SettingsSection";

export function PrivacyDataScreen(): React.JSX.Element {
  const { t } = useTranslation();
  const consent = useAppSelector((state) => state.auth.aiConsent);
  const dispatch = useAppDispatch();
  const analytics = useAppSelector(
    (state) => state.settings.analyticsEnabled === true,
  );
  const crashReports = useAppSelector(
    (state) => state.settings.crashReportsEnabled === true,
  );
  const styles = useThemedStyles(createStyles);
  const changeConsent = (enabled: boolean) => {
    if (!enabled) perform(() => setConsent(false));
    else
      Alert.alert(
        t("enableSharingQuestion"),
        t("enableSharingBody"),
        [
          { text: t("cancel"), style: "cancel" },
          { text: t("enable"), onPress: () => perform(() => setConsent(true)) },
        ],
      );
  };
  return (
    <Screen
      title={t("privacy")}
      subtitle={t("privacySubtitle")}
    >
      <SettingsSection
        title={t("sharingHeading")}
        footer={t("sharingFooter")}
      >
        <SettingsRow
          type="toggle"
          title={t("shareOpenAI")}
          description={
            consent
              ? t("sharingOnDescription")
              : t("sharingOffDescription")
          }
          value={consent}
          onValueChange={changeConsent}
        />
        <View style={styles.card}>
          <Text weight="SemiBold">{t("whatShared")}</Text>
          <Text>
            {t("whatSharedBody")}
          </Text>
        </View>
      </SettingsSection>
      <SettingsSection title={t("googleDiagnostics")}>
        <View style={styles.card}>
          <Text>
            {t("googleDiagnosticsBody")}
          </Text>
        </View>
        {firebaseConfigured ? (
          <>
            <SettingsRow
              type="toggle"
              title={t("analytics")}
              value={analytics}
              onValueChange={(value) =>
                dispatch(settingsActions.analyticsChanged(value))
              }
            />
            <SettingsRow
              type="toggle"
              title={t("crashReports")}
              value={crashReports}
              onValueChange={(value) =>
                dispatch(settingsActions.crashReportsChanged(value))
              }
            />
          </>
        ) : (
          <Text type="Small" style={styles.note}>
            {t("googleUnavailable")}
          </Text>
        )}
      </SettingsSection>
      <SettingsSection title={t("onDevice")}>
        <View style={styles.card}>
          <Text>
            {t("onDeviceBody")}
          </Text>
        </View>
      </SettingsSection>
      <SettingsSection
        title={t("eraseChatHeading")}
        footer={t("eraseChatFooter")}
      >
        <View style={styles.card}>
          <Button
            text={t("eraseCoaching")}
            variant="ghost"
            tone="danger"
            onPress={() =>
              Alert.alert(
                t("eraseQuestion"),
                t("eraseConfirm"),
                [
                  { text: t("cancel"), style: "cancel" },
                  {
                    text: t("erase"),
                    style: "destructive",
                    onPress: () => {
                      coordinator.cancel();
                      dispatch(chatActions.cleared());
                      dispatch(grantsActions.offersCancelled());
                    },
                  },
                ],
              )
            }
          />
        </View>
      </SettingsSection>
    </Screen>
  );
}
const createStyles = (theme: Theme) =>
  ({
    card: {
      backgroundColor: theme.colors.card,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      gap: theme.spacing.xs,
    },
    note: { marginHorizontal: theme.spacing.xs },
  }) satisfies Record<string, ResponsiveStyle>;

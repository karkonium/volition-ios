import { Image } from "react-native";
import React from "react";
import { useTranslation } from "react-i18next";
import { Button, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
import { Screen } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
export function WelcomeScreen({
  onContinue,
}: {
  onContinue: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles((theme) => ({
    logo: {
      width: 96,
      height: 96,
      borderRadius: theme.radii.lg,
      alignSelf: "center" as const,
      marginVertical: theme.spacing.md,
    },
  }));
  return (
    <Screen title="Volition" subtitle={t("welcomeSubtitle")}>
      <Image
        source={require("../../../assets/icon.png")}
        style={styles.logo}
        accessibilityLabel="Volition"
      />
      <VolitionCard>
        <Text type="H3">{t("welcomeTitle")}</Text>
        <Text>{t("welcomeBody")}</Text>
      </VolitionCard>
      <Text>{t("welcomeStep1")}</Text>
      <Text>{t("welcomeStep2")}</Text>
      <Text>{t("welcomeStep3")}</Text>
      <Button text={t("getStarted")} onPress={onContinue} />
    </Screen>
  );
}

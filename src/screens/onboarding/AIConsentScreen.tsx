import React from "react";
import { useTranslation } from "react-i18next";
import { Button, Text } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { useAppSelector } from "../../redux/store";
import { setConsent } from "../../services/runtime";
export function AIConsentScreen({
  onContinue,
}: {
  onContinue: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const consent = useAppSelector((state) => state.auth.aiConsent);
  return (
    <Screen title={t("consentTitle")}>
      <Text>{t("consentBody")}</Text>
      <Text>{t("consentPrivacy")}</Text>
      <Button
        text={consent ? t("sharingOn") : t("sharingOff")}
        variant="outline"
        onPress={() => perform(() => setConsent(!consent))}
      />
      <Button text={t("continue")} onPress={onContinue} />
    </Screen>
  );
}

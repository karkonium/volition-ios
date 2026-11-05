import React from "react";
import { useTranslation } from "react-i18next";
import { Linking } from "react-native";
import { Button, Text } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { VolitionScreenTime } from "../../../modules/volition-screen-time";
import { useAppDispatch } from "../../redux/store";
import { authActions } from "../../redux/authSlice";
export function ScreenTimeGateScreen({
  onApproved,
}: {
  onApproved: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const dispatch = useAppDispatch();
  return (
    <Screen title={t("screenTimeTitle")}>
      <Text>{t("screenTimeBody")}</Text>
      <Button
        text={t("screenTimeTitle")}
        onPress={() =>
          perform(async () => {
            const status = await VolitionScreenTime.requestAuthorization();
            dispatch(authActions.authorizationChanged(status));
            if (status === "approved") onApproved();
          })
        }
      />
      <Button
        text={t("openSettings")}
        variant="ghost"
        onPress={() => perform(() => Linking.openSettings())}
      />
    </Screen>
  );
}

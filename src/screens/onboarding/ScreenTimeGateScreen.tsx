import React from "react";
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
  const dispatch = useAppDispatch();
  return (
    <Screen title="Allow Screen Time">
      <Text>
        Volition uses Apple’s Screen Time permission to shield only apps you
        choose. Your app selection stays on your device.
      </Text>
      <Button
        text="Allow Screen Time"
        onPress={() =>
          perform(async () => {
            const status = await VolitionScreenTime.requestAuthorization();
            dispatch(authActions.authorizationChanged(status));
            if (status === "approved") onApproved();
          })
        }
      />
      <Button
        text="Open Settings"
        variant="ghost"
        onPress={() => perform(() => Linking.openSettings())}
      />
    </Screen>
  );
}

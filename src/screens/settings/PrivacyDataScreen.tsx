import React from "react";
import { Alert } from "react-native";
import { Button, Text } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { grantsActions } from "../../redux/grantsSlice";
import { chatActions } from "../../redux/chatSlice";
import { setConsent, coordinator } from "../../services/runtime";
export function PrivacyDataScreen(): React.JSX.Element {
  const consent = useAppSelector((state) => state.auth.aiConsent);
  const dispatch = useAppDispatch();
  return (
    <Screen title="Privacy & data">
      <Text type="H3">Shared with OpenAI</Text>
      <Text>
        Messages, saved app names, intentions, notes, recent allocated sessions,
        active unlocks and waits, agreements and optional check-ins are sent
        only while AI sharing is enabled.
      </Text>
      <Button
        text={
          consent ? "AI sharing: On — turn off" : "AI sharing: Off — turn on"
        }
        onPress={() => {
          if (consent) perform(() => setConsent(false));
          else
            Alert.alert(
              "Enable AI sharing?",
              "The information described above will be sent to OpenAI for coaching.",
              [
                { text: "Cancel", style: "cancel" },
                {
                  text: "Enable",
                  onPress: () => perform(() => setConsent(true)),
                },
              ],
            );
        }}
      />
      <Text type="H3">Stored on this device</Text>
      <Text>
        Chat, private activity history, saved profiles and commitments remain
        local. Keys are kept in Keychain. Ratings never affect access.
      </Text>
      <Button
        text="Erase coaching content"
        variant="outline"
        tone="danger"
        onPress={() =>
          Alert.alert(
            "Erase chat?",
            "Private activity logs, access history and existing agreements remain available. Pending offers are cancelled.",
            [
              { text: "Cancel", style: "cancel" },
              {
                text: "Erase",
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
    </Screen>
  );
}

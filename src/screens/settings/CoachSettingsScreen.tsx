import React, { useState } from "react";
import { Linking } from "react-native";
import { Button, Text, TextField, Flex } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { settingsActions, type CoachTone } from "../../redux/settingsSlice";
import { VolitionScreenTime } from "../../../modules/volition-screen-time";
import { requestNotifications } from "../../services/notificationService";
export function CoachSettingsScreen(): React.JSX.Element {
  const state = useAppSelector((state) => state.settings);
  const dispatch = useAppDispatch();
  const [key, setKey] = useState("");
  return (
    <Screen title="Coach settings">
      <Text type="H3">Tone</Text>
      <Flex wrap="wrap" gap="sm">
        {(["warm", "balanced", "direct"] as CoachTone[]).map((tone) => (
          <Button
            key={tone}
            text={`${state.tone === tone ? "✓ " : ""}${tone}`}
            variant="outline"
            onPress={() => dispatch(settingsActions.toneChanged(tone))}
          />
        ))}
      </Flex>
      <Text type="H3">OpenAI</Text>
      <Text>
        {state.keyConfigured ? "Key configured" : "Add your personal API key"} ·
        GPT-5.4 mini
      </Text>
      <TextField
        placeholderLabel="API key"
        secure
        value={key}
        onChange={setKey}
        autoCapitalize="none"
        autoCorrect={false}
      />
      <Button
        text="Save key securely"
        disabled={!key.trim()}
        onPress={() =>
          perform(async () => {
            await VolitionScreenTime.setAPIKey(key.trim());
            dispatch(settingsActions.keyConfigured(true));
            setKey("");
          })
        }
      />
      <Button
        text="Remove key"
        variant="ghost"
        onPress={() =>
          perform(async () => {
            await VolitionScreenTime.setAPIKey("");
            dispatch(settingsActions.keyConfigured(false));
            setKey("");
          })
        }
      />
      <Text type="H3">Unlock reminders</Text>
      <Text>
        Best-effort alerts at 60, 30 and 10 seconds remaining. System delivery
        can be delayed.
      </Text>
      <Button
        text="Allow notifications"
        variant="outline"
        onPress={() =>
          perform(async () => {
            dispatch(
              settingsActions.notificationsChanged(
                await requestNotifications(),
              ),
            );
          })
        }
      />
      <Button
        text="Notification settings"
        variant="ghost"
        onPress={() => perform(() => Linking.openSettings())}
      />
    </Screen>
  );
}

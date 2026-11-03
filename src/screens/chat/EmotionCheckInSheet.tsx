import React, { useState } from "react";
import { Button, Text, TextField, Flex } from "@itsRares/ahhzo-elements";
import { VolitionCard } from "../../components/VolitionCard";
import { perform } from "../../components/Screen";
import { coordinator } from "../../services/runtime";
export function EmotionCheckInSheet({
  appId,
}: {
  appId: string;
}): React.JSX.Element {
  const [custom, setCustom] = useState("");
  return (
    <VolitionCard>
      <Flex vertical gap="sm">
        <Text type="H3">How are you feeling?</Text>
        <Text type="Small">Optional. Skip whenever you like.</Text>
        <Flex wrap="wrap" gap="sm">
          {["Bored", "Tired", "Stressed", "Restless", "Good"].map((emotion) => (
            <Button
              key={emotion}
              text={emotion}
              variant="outline"
              testID={`reflectionEmotion-${emotion.toLowerCase()}`}
              onPress={() =>
                perform(() => coordinator.answerCheckIn(appId, emotion))
              }
            />
          ))}
        </Flex>
        <TextField
          placeholderLabel="Your own words"
          value={custom}
          onChange={setCustom}
          maxLength={160}
        />
        <Button
          text="Use my words"
          disabled={!custom.trim()}
          onPress={() =>
            perform(() => coordinator.answerCheckIn(appId, custom))
          }
        />
        <Button
          text="Not sure / Skip"
          variant="ghost"
          testID="skipReflectionButton"
          onPress={() => perform(() => coordinator.answerCheckIn(appId, null))}
        />
      </Flex>
    </VolitionCard>
  );
}

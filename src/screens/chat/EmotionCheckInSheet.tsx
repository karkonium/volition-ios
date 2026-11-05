import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { Button, Text, TextField, Flex } from "@itsRares/ahhzo-elements";
import { VolitionCard } from "../../components/VolitionCard";
import { perform } from "../../components/Screen";
import { coordinator } from "../../services/runtime";
export function EmotionCheckInSheet({
  appId,
}: {
  appId: string;
}): React.JSX.Element {
  const { t } = useTranslation();
  const [custom, setCustom] = useState("");
  return (
    <VolitionCard>
      <Flex vertical gap="sm">
        <Text type="H3">{t("feelQuestion")}</Text>
        <Text type="Small">{t("feelOptional")}</Text>
        <Flex wrap="wrap" gap="sm">
          {["Bored", "Tired", "Stressed", "Restless", "Good"].map((emotion) => (
            <Button
              key={emotion}
              text={t(emotion.toLowerCase())}
              variant="outline"
              testID={`reflectionEmotion-${emotion.toLowerCase()}`}
              onPress={() =>
                perform(() => coordinator.answerCheckIn(appId, emotion))
              }
            />
          ))}
        </Flex>
        <TextField
          placeholderLabel={t("ownWords")}
          value={custom}
          onChange={setCustom}
          maxLength={160}
        />
        <Button
          text={t("useWords")}
          disabled={!custom.trim()}
          onPress={() =>
            perform(() => coordinator.answerCheckIn(appId, custom))
          }
        />
        <Button
          text={t("skip")}
          variant="ghost"
          testID="skipReflectionButton"
          onPress={() => perform(() => coordinator.answerCheckIn(appId, null))}
        />
      </Flex>
    </VolitionCard>
  );
}

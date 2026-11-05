import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { Keyboard } from "react-native";
import {
  Button,
  TextField,
  Flex,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { perform } from "../../components/Screen";
import { layout } from "../../layout/layout";
import { coordinator } from "../../services/runtime";
import { InterventionCard } from "./components/InterventionCard";

const emotions = ["Bored", "Tired", "Stressed", "Restless", "Good"];
const emotionLimit = 160;

export function EmotionCheckInSheet({
  appId,
}: {
  appId: string;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const [custom, setCustom] = useState("");
  const answer = (emotion: string | null) => {
    Keyboard.dismiss();
    perform(() => coordinator.answerCheckIn(appId, emotion));
  };

  return (
    <InterventionCard label={t("chatCheckIn")} title={t("feelQuestion")}>
      <Flex wrap="wrap" gap="xxs">
        {emotions.map((emotion) => (
          <Button
            key={emotion}
            text={t(emotion.toLowerCase())}
            variant="soft"
            layout="inline"
            buttonStyle={styles.chip}
            testID={`reflectionEmotion-${emotion.toLowerCase()}`}
            onPress={() => answer(emotion)}
          />
        ))}
      </Flex>
      <TextField
        placeholderLabel={t("ownWords")}
        accessibilityLabel={t("ownWords")}
        value={custom}
        onChange={setCustom}
        maxLength={emotionLimit}
        showCharacterCount={custom.length >= emotionLimit - 20}
      />
      <Flex wrap="wrap" gap="xs">
        <Button
          text={t("useWords")}
          variant="soft"
          layout="inline"
          buttonStyle={styles.action}
          disabled={!custom.trim()}
          onPress={() => answer(custom)}
        />
        <Button
          text={t("skip")}
          variant="ghost"
          layout="inline"
          buttonStyle={styles.action}
          testID="skipReflectionButton"
          onPress={() => answer(null)}
        />
      </Flex>
    </InterventionCard>
  );
}

const createStyles = (theme: Theme) =>
  ({
    action: {
      minHeight: layout.minimumTouchSize,
      paddingVertical: theme.spacing.xs,
    },
    chip: {
      minHeight: layout.minimumTouchSize,
      borderRadius: theme.radii.pill,
      padding: theme.spacing.xs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

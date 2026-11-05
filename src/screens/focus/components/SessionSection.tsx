import React from "react";
import { useTranslation } from "react-i18next";
import {
  Button,
  Flex,
  Text,
  TextField,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { FocusChoice } from "./FocusChoice";
import { VolitionCard } from "../../../components/VolitionCard";
import { AppSelection } from "./AppSelection";

export function SessionSection({
  activeMinutes,
  duration,
  setDuration,
  apps,
  selected,
  setSelected,
  onStart,
  onEnd,
}: {
  activeMinutes: number | null;
  duration: string;
  setDuration: (value: string) => void;
  apps: { id: string; name: string }[];
  selected: string[];
  setSelected: (ids: string[]) => void;
  onStart: () => void;
  onEnd: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  if (activeMinutes !== null)
    return (
      <VolitionCard accent>
        <Flex vertical gap="md">
          <Text type="Small" weight="SemiBold" style={styles.accent}>
            {t("focusInProgress")}
          </Text>
          <Text type="H1">{t("minutesLeft", { count: activeMinutes })}</Text>
          <Text type="Small">{t("focusActiveHelp")}</Text>
          <Button text={t("endFocus")} variant="outline" onPress={onEnd} />
        </Flex>
      </VolitionCard>
    );
  return (
    <VolitionCard>
      <Flex vertical gap="md">
        <Flex vertical gap="xs">
          <Flex vertical gap="xxs">
            <Text type="H2">{t("startSession")}</Text>
            <Text type="Small">{t("startSessionHelp")}</Text>
          </Flex>
          <Flex wrap="wrap" gap="xs">
            {[15, 25, 50].map((minutes) => (
              <FocusChoice
                key={minutes}
                label={t("shortMinutes", { count: minutes })}
                selected={duration === String(minutes)}
                onPress={() => setDuration(String(minutes))}
              />
            ))}
          </Flex>
          <TextField
            placeholderLabel={t("customDuration")}
            accessibilityLabel={t("customDurationLabel")}
            value={duration}
            onChange={setDuration}
            keyboardType="number-pad"
          />
        </Flex>
        <AppSelection apps={apps} selected={selected} onChange={setSelected} />
        <Button text={t("startFocus")} onPress={onStart} />
      </Flex>
    </VolitionCard>
  );
}
const createStyles = (theme: Theme) =>
  ({ accent: { color: theme.colors.textLink } }) satisfies Record<
    string,
    ResponsiveStyle
  >;

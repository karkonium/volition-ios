import React from "react";
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
  const styles = useThemedStyles(createStyles);
  if (activeMinutes !== null)
    return (
      <VolitionCard accent>
        <Flex vertical gap="md">
          <Text type="Small" weight="SemiBold" style={styles.accent}>
            FOCUS IN PROGRESS
          </Text>
          <Text type="H1">
            {activeMinutes} {activeMinutes === 1 ? "minute" : "minutes"} left
          </Text>
          <Text type="Small">
            Your focus session is active. You can end it whenever you need to.
          </Text>
          <Button text="End Focus" variant="outline" onPress={onEnd} />
        </Flex>
      </VolitionCard>
    );
  return (
    <VolitionCard>
      <Flex vertical gap="md">
        <Flex vertical gap="xs">
          <Flex vertical gap="xxs">
            <Text type="H2">Start a session</Text>
            <Text type="Small">
              Choose how long you’d like some space to focus.
            </Text>
          </Flex>
          <Flex wrap="wrap" gap="xs">
            {[15, 25, 50].map((minutes) => (
              <FocusChoice
                key={minutes}
                label={`${minutes} min`}
                selected={duration === String(minutes)}
                onPress={() => setDuration(String(minutes))}
              />
            ))}
          </Flex>
          <TextField
            placeholderLabel="Custom duration (15–180 minutes)"
            accessibilityLabel="Custom duration in minutes"
            value={duration}
            onChange={setDuration}
            keyboardType="number-pad"
          />
        </Flex>
        <AppSelection apps={apps} selected={selected} onChange={setSelected} />
        <Button text="Start Focus" onPress={onStart} />
      </Flex>
    </VolitionCard>
  );
}
const createStyles = (theme: Theme) =>
  ({ accent: { color: theme.colors.textLink } }) satisfies Record<
    string,
    ResponsiveStyle
  >;

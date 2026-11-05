import React, { useEffect, useState } from "react";
import Ionicons from "@expo/vector-icons/Ionicons";
import {
  Button,
  Flex,
  Text,
  colorWithOpacity,
  useTheme,
} from "@itsRares/ahhzo-elements";
import type { ActiveGrant } from "../../modules/volition-screen-time";
export function useNow(): number {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);
  return now;
}
export function ActiveGrantBanner({
  grant,
  name,
  onEnd,
}: {
  grant: ActiveGrant;
  name: string;
  onEnd: () => void;
}): React.JSX.Element {
  const { theme } = useTheme();
  const seconds = Math.max(
    0,
    Math.ceil((Date.parse(grant.expiresAt) - useNow()) / 1000),
  );
  return (
    <Flex
      gap="xs"
      alignItems="center"
      wrap="wrap"
      style={{
        backgroundColor: colorWithOpacity(theme.colors.accent, 0.08),
        borderRadius: 14,
        paddingHorizontal: 12,
        paddingVertical: 2,
        marginBottom: 8,
      }}
    >
      <Ionicons
        name="lock-open-outline"
        size={17}
        color={theme.colors.textLink}
      />
      <Text weight="SemiBold" style={{ flex: 1, minWidth: 60 }}>
        {name}
      </Text>
      <Text weight="SemiBold" style={{ fontVariant: ["tabular-nums"] }}>
        {Math.floor(seconds / 60)}:{String(seconds % 60).padStart(2, "0")}
      </Text>
      <Button
        text="End unlock"
        layout="inline"
        variant="ghost"
        textStyle={{ fontSize: 13 }}
        testID="endConversationUnlockButton"
        onPress={onEnd}
      />
    </Flex>
  );
}

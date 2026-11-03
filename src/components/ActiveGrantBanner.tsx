import React, { useEffect, useState } from "react";
import { Button, Flex, Text } from "@itsRares/ahhzo-elements";
import { VolitionCard } from "./VolitionCard";
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
  const seconds = Math.max(
    0,
    Math.ceil((Date.parse(grant.expiresAt) - useNow()) / 1000),
  );
  return (
    <VolitionCard accent>
      <Flex vertical gap="sm">
        <Text type="H3">
          {name} · {Math.floor(seconds / 60)}:
          {String(seconds % 60).padStart(2, "0")}
        </Text>
        <Button
          text="End unlock"
          variant="outline"
          testID="endConversationUnlockButton"
          onPress={onEnd}
        />
      </Flex>
    </VolitionCard>
  );
}

import React from "react";
import { Button, Text, Flex } from "@itsRares/ahhzo-elements";
import type { Intervention } from "../../redux/grantsSlice";
import { useNow } from "../../components/ActiveGrantBanner";
import { VolitionCard } from "../../components/VolitionCard";
import { perform } from "../../components/Screen";
import { coordinator } from "../../services/runtime";
export function DelayCountdownCard({
  offer,
}: {
  offer: Intervention;
}): React.JSX.Element {
  const now = useNow();
  const remaining =
    offer.status === "ready"
      ? 0
      : Math.max(0, Math.ceil((Date.parse(offer.deadline ?? "") - now) / 1000));
  return (
    <VolitionCard>
      <Flex vertical gap="sm">
        <Text type="H3" testID="reflectionCountdown">
          {remaining > 0
            ? `${remaining} seconds to pause`
            : "Your pause has ended"}
        </Text>
        {remaining > 0 ? (
          <Button
            text="End delay"
            size="small"
            variant="ghost"
            testID="cancelReflectionButton"
            onPress={() => perform(() => coordinator.endDelay(offer.appId))}
          />
        ) : (
          <Button
            text={`Unlock for ${offer.decision.unlock_minutes ?? 1} minutes`}
            variant="outline"
            onPress={() =>
              perform(() => coordinator.activate(offer.appId, "delay"))
            }
          />
        )}
        <Button
          text="Keep locked"
          onPress={() => perform(() => coordinator.keepLocked(offer.appId))}
        />
      </Flex>
    </VolitionCard>
  );
}

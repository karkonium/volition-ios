import React from "react";
import { Button, Flex, Text } from "@itsRares/ahhzo-elements";
import type { Intervention } from "../../redux/grantsSlice";
import { VolitionCard } from "../../components/VolitionCard";
import { perform } from "../../components/Screen";
import { coordinator } from "../../services/runtime";
export function InterventionChoiceCard({
  offer,
}: {
  offer: Intervention;
}): React.JSX.Element {
  const { decision } = offer;
  const choice = decision.decision === "choice";
  const deal = ["deal", "override"].includes(decision.decision);
  if (offer.status === "interrupted")
    return (
      <VolitionCard>
        <Text>This request was interrupted. Send a new request.</Text>
      </VolitionCard>
    );
  return (
    <VolitionCard accent>
      <Flex vertical gap="sm">
        <Text type="H3">
          {offer.status === "activating"
            ? "Checking access…"
            : choice
              ? "Choose what helps"
              : deal
                ? "An agreement"
                : "A pause before access"}
        </Text>
        {offer.status !== "activating" && (
          <>
            {(choice || !deal) && (
              <Button
                text={`Delay ${decision.pause_seconds ?? (decision.wait_minutes ?? 1) * 60} seconds`}
                testID="startReflectionButton"
                onPress={() =>
                  perform(() => coordinator.startDelay(offer.appId))
                }
              />
            )}{" "}
            {(choice || deal) && (
              <Button
                text={`${choice ? "Deal" : "Accept"}: ${decision.unlock_minutes} minutes now, then ${decision.block_minutes} minutes away`}
                onPress={() =>
                  perform(() => coordinator.activate(offer.appId, "deal"))
                }
              />
            )}{" "}
            {choice && (
              <Button
                text={`Open now for ${decision.unlock_minutes} minutes`}
                variant="ghost"
                onPress={() =>
                  perform(() => coordinator.activate(offer.appId, "open"))
                }
              />
            )}
            <Button
              text={deal ? "Decline / Keep locked" : "Keep locked"}
              variant="outline"
              onPress={() => perform(() => coordinator.keepLocked(offer.appId))}
            />
          </>
        )}
      </Flex>
    </VolitionCard>
  );
}

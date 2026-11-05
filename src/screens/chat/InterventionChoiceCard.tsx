import React from "react";
import { useTranslation } from "react-i18next";
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
  const { t } = useTranslation();
  const { decision } = offer;
  const choice = decision.decision === "choice";
  const deal = ["deal", "override"].includes(decision.decision);
  if (offer.status === "interrupted")
    return (
      <VolitionCard>
        <Text>{t("interrupted")}</Text>
      </VolitionCard>
    );
  return (
    <VolitionCard accent>
      <Flex vertical gap="sm">
        <Text type="H3">
          {offer.status === "activating"
            ? t("checkingAccess")
            : choice
              ? t("chooseWhatHelps")
              : deal
                ? t("agreement")
                : t("pauseBefore")}
        </Text>
        {offer.status !== "activating" && (
          <>
            {(choice || !deal) && (
              <Button
                text={t("delayFor", {
                  count:
                    decision.pause_seconds ?? (decision.wait_minutes ?? 1) * 60,
                })}
                testID="startReflectionButton"
                onPress={() =>
                  perform(() => coordinator.startDelay(offer.appId))
                }
              />
            )}{" "}
            {(choice || deal) && (
              <Button
                text={t(choice ? "dealTerms" : "acceptTerms", {
                  access: decision.unlock_minutes,
                  rest: decision.block_minutes,
                })}
                onPress={() =>
                  perform(() => coordinator.activate(offer.appId, "deal"))
                }
              />
            )}{" "}
            {choice && (
              <Button
                text={t("openNow", { count: decision.unlock_minutes })}
                variant="ghost"
                onPress={() =>
                  perform(() => coordinator.activate(offer.appId, "open"))
                }
              />
            )}
            <Button
              text={deal ? t("declineKeep") : t("keepLocked")}
              variant="outline"
              onPress={() => perform(() => coordinator.keepLocked(offer.appId))}
            />
          </>
        )}
      </Flex>
    </VolitionCard>
  );
}

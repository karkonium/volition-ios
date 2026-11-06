import React, { useState } from "react";
import { Alert } from "react-native";
import { useTranslation } from "react-i18next";
import { Button, Flex, Modal, Text } from "@itsRares/ahhzo-elements";
import { VolitionCard } from "../../components/VolitionCard";
import { perform } from "../../components/Screen";
import { applyFocusCommand } from "../../services/runtime";
import type { FocusOccurrence } from "../../redux/focusSlice";
import { focusDateTime, focusName } from "../focus/focusPresentation";

export function FocusReviewCard({
  app,
  reasons,
}: {
  app: { id: string; name: string };
  reasons: FocusOccurrence[];
}) {
  const { t, i18n } = useTranslation();
  const [reviewing, setReviewing] = useState(false);
  const [busy, setBusy] = useState(false);
  const describe = (reason: FocusOccurrence) =>
    t("focusReason", {
      name: focusName(reason, t("quickFocus")),
      time: focusDateTime(reason.endsAt, i18n.resolvedLanguage),
    });
  const first = reasons[0];
  if (!first) return null;
  return (
    <VolitionCard accent>
      <Flex vertical gap="xs">
        <Text type="Small">{describe(first)}</Text>
        {reasons.length > 1 && <Text type="Small">{t("focusOverlaps")}</Text>}
        <Button
          layout="inline"
          variant="outline"
          text={t("focusReview")}
          testID="conversationReviewFocus"
          onPress={() => setReviewing(true)}
        />
      </Flex>
      <Modal
        title={t("focusReview")}
        isVisible={reviewing}
        onClose={() => setReviewing(false)}
        scrollable
      >
        <Flex vertical gap="md">
          <Text>{t("focusExceptionHelp")}</Text>
          {reasons.map((reason) => (
            <Flex key={reason.id} vertical gap="xs">
              <Text>{describe(reason)}</Text>
              <Button
                variant="outline"
                disabled={busy}
                text={t("focusSkipApp", { app: app.name })}
                onPress={() =>
                  Alert.alert(
                    t("focusSkipApp", { app: app.name }),
                    describe(reason),
                    [
                      { text: t("cancel"), style: "cancel" },
                      {
                        text: t("focusSkipConfirm"),
                        onPress: () =>
                          perform(async () => {
                            setBusy(true);
                            try {
                              await applyFocusCommand({
                                kind: "exceptApp",
                                appID: app.id,
                                occurrenceID: reason.id,
                              });
                            } finally {
                              setBusy(false);
                            }
                          }),
                      },
                    ],
                  )
                }
              />
            </Flex>
          ))}
        </Flex>
      </Modal>
    </VolitionCard>
  );
}

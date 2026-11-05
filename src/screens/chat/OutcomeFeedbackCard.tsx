import React from "react";
import { useTranslation } from "react-i18next";
import { Text, Button, Flex } from "@itsRares/ahhzo-elements";
import { VolitionCard } from "../../components/VolitionCard";
import { useAppDispatch } from "../../redux/store";
import {
  activityLogActions,
  type ActivityLogEntry,
  type OutcomeFeedback,
} from "../../redux/activityLogSlice";
export function OutcomeFeedbackCard({
  entry,
}: {
  entry: ActivityLogEntry;
}): React.JSX.Element {
  const { t } = useTranslation();
  const dispatch = useAppDispatch();
  return (
    <VolitionCard>
      <Text type="Small">{t("feedbackQuestion")}</Text>
      <Flex wrap="wrap" gap="sm">
        {(["helpful", "neutral", "annoying"] as OutcomeFeedback[]).map(
          (feedback) => (
            <Button
              key={feedback}
              text={t(feedback)}
              variant="ghost"
              onPress={() =>
                dispatch(activityLogActions.rated({ id: entry.id, feedback }))
              }
            />
          ),
        )}
      </Flex>
    </VolitionCard>
  );
}

import React from "react";
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
  const dispatch = useAppDispatch();
  return (
    <VolitionCard>
      <Text type="Small">How did that feel? Private and optional.</Text>
      <Flex wrap="wrap" gap="sm">
        {(["helpful", "neutral", "annoying"] as OutcomeFeedback[]).map(
          (feedback) => (
            <Button
              key={feedback}
              text={feedback[0]!.toUpperCase() + feedback.slice(1)}
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

import React from "react";
import { Alert } from "react-native";
import { Button, Text, Flex } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { activityLogActions } from "../../redux/activityLogSlice";
import { shareActivity, removeExports } from "../../services/activityExport";
export function ActivityLogScreen(): React.JSX.Element {
  const entries = useAppSelector((state) => state.activityLog.entries);
  const dispatch = useAppDispatch();
  return (
    <Screen title="Private activity log">
      <Text>
        Model advice and actual local outcomes are recorded separately.
      </Text>
      <Flex gap="sm" wrap="wrap">
        <Button
          text="Export JSONL"
          testID="exportActivityLogButton"
          variant="outline"
          onPress={() => perform(() => shareActivity(entries, "jsonl"))}
        />
        <Button
          text="Export text"
          variant="outline"
          onPress={() => perform(() => shareActivity(entries, "txt"))}
        />
      </Flex>
      <Button
        text="Clear activity log"
        testID="clearActivityLogButton"
        variant="ghost"
        tone="danger"
        onPress={() =>
          Alert.alert(
            "Clear activity log?",
            "Coaching and enforcement history are retained.",
            [
              { text: "Cancel", style: "cancel" },
              {
                text: "Clear",
                style: "destructive",
                onPress: () => {
                  removeExports();
                  dispatch(activityLogActions.cleared());
                },
              },
            ],
          )
        }
      />
      {[...entries].reverse().map((entry) => (
        <VolitionCard key={entry.id}>
          <Text type="H3">
            {entry.appName ?? "Volition"} · {entry.outcome}
          </Text>
          <Text type="Small">{new Date(entry.date).toLocaleString()}</Text>
          <Text>{entry.message}</Text>
          {entry.coachResponse && <Text>{entry.coachResponse}</Text>}
          <Text type="Small">
            Model: {entry.decision} · Feedback: {entry.feedback ?? "Not rated"}
          </Text>
        </VolitionCard>
      ))}
    </Screen>
  );
}

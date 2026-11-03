import { useSafeAreaInsets } from "react-native-safe-area-context";
import React, { useRef, useState, useEffect } from "react";
import { ScrollView } from "react-native";
import {
  Page,
  Header,
  Button,
  Flex,
  Text,
  TextField,
  useThemedStyles,
} from "@itsRares/ahhzo-elements";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { chatActions } from "../../redux/chatSlice";
import { coordinator, endGrant } from "../../services/runtime";
import { perform } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
import { ActiveGrantBanner } from "../../components/ActiveGrantBanner";
import { AppPickerModal } from "./AppPickerModal";
import { EmotionCheckInSheet } from "./EmotionCheckInSheet";
import { DelayCountdownCard } from "./DelayCountdownCard";
import { InterventionChoiceCard } from "./InterventionChoiceCard";
import { OutcomeFeedbackCard } from "./OutcomeFeedbackCard";
export function ChatScreen(): React.JSX.Element {
  const insets = useSafeAreaInsets();
  const state = useAppSelector((state) => state);
  const dispatch = useAppDispatch();
  const [picker, setPicker] = useState(false);
  const transcript = useRef<ScrollView>(null);
  const [nearBottom, setNearBottom] = useState(true);
  const app = state.apps.items.find(
    (item) => item.id === state.chat.selectedAppId,
  );
  const offer = app ? state.grants.offers[app.id] : undefined;
  const feedback = [...state.activityLog.entries]
    .reverse()
    .find(
      (entry) =>
        !entry.feedback &&
        ["approved", "keptLocked", "earlyEnded", "expired"].includes(
          entry.outcome,
        ),
    );
  const styles = useThemedStyles((theme) => ({
    root: { flex: 1, backgroundColor: theme.colors.background },
    pinned: {
      maxHeight: 220,
      flexGrow: 0,
      paddingTop: insets.top,
      paddingHorizontal: theme.spacing.md,
    },
    composer: {
      padding: theme.spacing.md,
      paddingBottom: insets.bottom + theme.spacing.sm,
      backgroundColor: theme.colors.background,
    },
    user: { color: theme.colors.textSecondary },
  }));
  useEffect(() => {
    if (nearBottom) transcript.current?.scrollToEnd({ animated: true });
  }, [state.chat.messages.length, offer?.status, feedback?.id, nearBottom]);
  return (
    <Flex vertical style={styles.root}>
      {state.grants.activeGrants.length > 0 && (
        <ScrollView style={styles.pinned}>
          {state.grants.activeGrants.map((grant) => (
            <ActiveGrantBanner
              key={grant.grantId}
              grant={grant}
              name={
                state.apps.items.find((item) => item.id === grant.appId)
                  ?.name ?? "App"
              }
              onEnd={() => perform(() => endGrant(grant.grantId))}
            />
          ))}
        </ScrollView>
      )}
      <Page
        scrollRef={transcript}
        safeAreaEdges={
          state.grants.activeGrants.length
            ? ["left", "right"]
            : ["top", "left", "right"]
        }
      >
        <Header title="Chat" subtitle="A moment of intention" />
        <Button
          text={app?.name ?? "Choose an app"}
          variant="outline"
          testID="conversationChooseAppButton"
          onPress={() => setPicker(true)}
        />
        {state.chat.messages.length > state.chat.visibleCount && (
          <Button
            text="Earlier messages"
            variant="ghost"
            onPress={() => dispatch(chatActions.loadEarlier())}
          />
        )}
        <Flex
          vertical
          gap="sm"
          testID="conversationTranscript"
          onTouchStart={() => setNearBottom(false)}
        >
          {state.chat.messages
            .slice(-state.chat.visibleCount)
            .map((message) => (
              <VolitionCard key={message.id}>
                <Text type="Small" style={styles.user}>
                  {message.role === "user" ? "You" : "Volition"}
                </Text>
                <Text>{message.text}</Text>
              </VolitionCard>
            ))}
          {offer &&
            (offer.status === "checkIn" ? (
              <EmotionCheckInSheet appId={offer.appId} />
            ) : offer.status === "delaying" || offer.status === "ready" ? (
              <DelayCountdownCard offer={offer} />
            ) : (
              <InterventionChoiceCard offer={offer} />
            ))}
          {feedback && <OutcomeFeedbackCard entry={feedback} />}
        </Flex>
        {state.chat.error && <Text>{state.chat.error}</Text>}
        {!nearBottom && (
          <Button
            text="Jump to latest"
            variant="ghost"
            testID="conversationJumpLatest"
            onPress={() => {
              setNearBottom(true);
              transcript.current?.scrollToEnd({ animated: true });
            }}
          />
        )}
      </Page>
      <Flex vertical gap="sm" style={styles.composer}>
        <TextField
          placeholderLabel="What would you like to do?"
          value={state.chat.draft}
          onChange={(text) => dispatch(chatActions.draftChanged(text))}
          multiline
          testID="conversationMessageField"
        />
        {state.chat.pendingRequestId ? (
          <Button
            text="Cancel request"
            variant="ghost"
            onPress={() => coordinator.cancel()}
          />
        ) : (
          <Button
            text="Send"
            testID="conversationSendButton"
            disabled={!state.chat.draft.trim()}
            onPress={() =>
              perform(async () => {
                await coordinator.send();
                setNearBottom(true);
              })
            }
          />
        )}
      </Flex>
      <AppPickerModal visible={picker} onClose={() => setPicker(false)} />
    </Flex>
  );
}

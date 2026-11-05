import { layout } from "../../layout/layout";
import type { ResponsiveStyle, Theme } from "@itsRares/ahhzo-elements";
import React, { useRef, useState, useEffect } from "react";
import {
  Keyboard,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from "react-native";
import { Button, Flex, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
import { ChatHeader } from "./components/ChatHeader";
import { ChatEmptyState } from "./components/ChatEmptyState";
import { ChatComposer } from "./components/ChatComposer";
import { ConversationMessage } from "./components/ConversationMessage";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { chatActions } from "../../redux/chatSlice";
import { coordinator, endGrant } from "../../services/runtime";
import { perform } from "../../components/Screen";
import { ActiveGrantBanner } from "../../components/ActiveGrantBanner";
import { AppPickerModal } from "./AppPickerModal";
import { EmotionCheckInSheet } from "./EmotionCheckInSheet";
import { DelayCountdownCard } from "./DelayCountdownCard";
import { InterventionChoiceCard } from "./InterventionChoiceCard";
import { OutcomeFeedbackCard } from "./OutcomeFeedbackCard";

/** App selection and independent grant banners stay outside the scrolling conversation. */
export function ChatScreen(): React.JSX.Element {
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
  const styles = useThemedStyles(createStyles);
  useEffect(() => {
    if (nearBottom) transcript.current?.scrollToEnd({ animated: true });
  }, [state.chat.messages.length, offer?.status, feedback?.id, nearBottom]);
  useEffect(() => {
    if (feedback) {
      setNearBottom(true);
      transcript.current?.scrollToEnd({ animated: true });
    }
  }, [feedback?.id]);
  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ChatHeader
        app={app}
        attention={state.chat.selectionAttention}
        onChooseApp={() => setPicker(true)}
      />
      {state.grants.activeGrants.length > 0 && (
        <ScrollView style={[styles.width, styles.pinned]}>
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
      <ScrollView
        ref={transcript}
        style={styles.width}
        contentContainerStyle={styles.transcript}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode="interactive"
        testID="conversationTranscript"
        scrollEventThrottle={100}
        onScroll={({
          nativeEvent: { contentOffset, contentSize, layoutMeasurement },
        }) =>
          setNearBottom(
            contentSize.height - contentOffset.y - layoutMeasurement.height <
              100,
          )
        }
        onContentSizeChange={() => {
          if (nearBottom) transcript.current?.scrollToEnd({ animated: true });
        }}
      >
        {state.chat.messages.length === 0 && (
          <ChatEmptyState appName={app?.name} />
        )}
        {state.chat.messages.length > state.chat.visibleCount && (
          <Button
            text="Earlier messages"
            variant="ghost"
            onPress={() => dispatch(chatActions.loadEarlier())}
          />
        )}
        <Flex vertical gap="md">
          {state.chat.messages
            .slice(-state.chat.visibleCount)
            .map((message) => (
              <ConversationMessage
                key={message.id}
                role={message.role}
                text={message.text}
              />
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
          {state.chat.error && (
            <Text accessibilityRole="alert" style={styles.error}>
              {state.chat.error}
            </Text>
          )}
        </Flex>
      </ScrollView>
      {!nearBottom && state.chat.messages.length > 0 && (
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
      <ChatComposer
        draft={state.chat.draft}
        pending={Boolean(state.chat.pendingRequestId)}
        hasApp={Boolean(app)}
        onChange={(text) => dispatch(chatActions.draftChanged(text))}
        onCancel={() => coordinator.cancel()}
        onSend={() => {
          Keyboard.dismiss();
          setNearBottom(true);
          perform(() => coordinator.send());
        }}
      />
      <AppPickerModal visible={picker} onClose={() => setPicker(false)} />
    </KeyboardAvoidingView>
  );
}

const createStyles = (theme: Theme) =>
  ({
    root: { flex: 1, backgroundColor: theme.colors.background },
    width: {
      width: "100%",
      maxWidth: layout.pageMaxWidth,
      alignSelf: "center",
    },
    pinned: {
      maxHeight: 160,
      flexGrow: 0,
      paddingHorizontal: theme.spacing.lg,
    },
    transcript: {
      paddingHorizontal: theme.spacing.lg,
      paddingTop: theme.spacing.xs,
      paddingBottom: theme.spacing.lg,
      flexGrow: 1,
    },
    error: { color: theme.colors.error },
  }) satisfies Record<string, ResponsiveStyle>;

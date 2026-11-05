import React, { useRef, useState } from "react";
import {
  Keyboard,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  View,
  useWindowDimensions,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useTranslation } from "react-i18next";
import {
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { ActiveGrantBanner } from "../../components/ActiveGrantBanner";
import { perform } from "../../components/Screen";
import { layout } from "../../layout/layout";
import { chatActions } from "../../redux/chatSlice";
import { store, useAppDispatch, useAppSelector } from "../../redux/store";
import { coordinator, endGrant } from "../../services/runtime";
import { AppPickerModal } from "./AppPickerModal";
import { DelayCountdownCard } from "./DelayCountdownCard";
import { EmotionCheckInSheet } from "./EmotionCheckInSheet";
import { InterventionChoiceCard } from "./InterventionChoiceCard";
import { OutcomeFeedbackCard } from "./OutcomeFeedbackCard";
import { ChatComposer } from "./components/ChatComposer";
import { ChatHeader } from "./components/ChatHeader";
import { ChatTranscript } from "./components/ChatTranscript";
import { composerState } from "./components/composerState";

const rateableOutcomes = new Set([
  "approved",
  "keptLocked",
  "earlyEnded",
  "expired",
]);

/** App selection and independent grant banners stay outside the scrolling conversation. */
export function ChatScreen(): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const { width } = useWindowDimensions();
  const dispatch = useAppDispatch();
  const chat = useAppSelector((state) => state.chat);
  const apps = useAppSelector((state) => state.apps.items);
  const activeGrants = useAppSelector((state) => state.grants.activeGrants);
  const offer = useAppSelector((state) =>
    chat.selectedAppId ? state.grants.offers[chat.selectedAppId] : undefined,
  );
  const feedback = useAppSelector((state) =>
    state.activityLog.entries.findLast(
      (entry) => !entry.feedback && rateableOutcomes.has(entry.outcome),
    ),
  );
  const consent = useAppSelector((state) => state.auth.aiConsent);
  const app = apps.find(
    (item) => item.id === chat.selectedAppId && item.isEnabled,
  );
  const pending = Boolean(chat.pendingRequestId);
  const [picker, setPicker] = useState(false);
  const [cancelled, setCancelled] = useState(false);
  const container = useRef<View>(null);
  const [keyboardOffset, setKeyboardOffset] = useState(0);

  const send = () => {
    Keyboard.dismiss();
    setCancelled(false);
    const attention = store.getState().chat.selectionAttention;
    perform(async () => {
      try {
        await coordinator.send();
      } catch (error) {
        if (store.getState().chat.selectionAttention === attention) throw error;
      }
    });
  };

  return (
    <View
      ref={container}
      style={styles.root}
      onLayout={() =>
        container.current?.measureInWindow((_x, y) => setKeyboardOffset(y))
      }
    >
      <KeyboardAvoidingView
        style={styles.root}
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        keyboardVerticalOffset={keyboardOffset}
      >
        <SafeAreaView
          style={styles.root}
          edges={
            width >= 768
              ? ["top", "left", "right", "bottom"]
              : ["top", "left", "right"]
          }
        >
          <ChatHeader
            app={app}
            attention={chat.selectionAttention}
            onChooseApp={() => {
              Keyboard.dismiss();
              setPicker(true);
            }}
          />
          {activeGrants.length > 0 && (
            <ScrollView
              style={styles.pinned}
              contentContainerStyle={styles.grants}
            >
              {activeGrants.map((grant) => (
                <ActiveGrantBanner
                  key={grant.grantId}
                  grant={grant}
                  name={
                    apps.find((item) => item.id === grant.appId)?.name ??
                    t("chatApp")
                  }
                  onEnd={() => perform(() => endGrant(grant.grantId))}
                />
              ))}
            </ScrollView>
          )}
          <ChatTranscript
            appName={app?.name}
            messages={chat.messages}
            visibleCount={chat.visibleCount}
            onLoadEarlier={() => dispatch(chatActions.loadEarlier())}
            error={chat.error}
            cancelled={cancelled}
            onRetry={
              consent && composerState(chat.draft, pending).canSend
                ? send
                : undefined
            }
          >
            {app &&
              offer &&
              (offer.status === "checkIn" ? (
                <EmotionCheckInSheet key={offer.id} appId={offer.appId} />
              ) : offer.status === "delaying" || offer.status === "ready" ? (
                <DelayCountdownCard offer={offer} appName={app.name} />
              ) : (
                <InterventionChoiceCard offer={offer} appName={app.name} />
              ))}
            {feedback && <OutcomeFeedbackCard entry={feedback} />}
          </ChatTranscript>
          <ChatComposer
            draft={chat.draft}
            pending={pending}
            hasApp={Boolean(app)}
            onChange={(text) => dispatch(chatActions.draftChanged(text))}
            onCancel={() => {
              coordinator.cancel();
              setCancelled(true);
            }}
            onSend={send}
          />
        </SafeAreaView>
        <AppPickerModal visible={picker} onClose={() => setPicker(false)} />
      </KeyboardAvoidingView>
    </View>
  );
}

const createStyles = (theme: Theme) =>
  ({
    root: { flex: 1, backgroundColor: theme.colors.background },
    pinned: {
      width: "100%",
      maxWidth: layout.pageMaxWidth,
      alignSelf: "center",
      maxHeight: 120,
      flexGrow: 0,
      flexShrink: 1,
    },
    grants: {
      gap: theme.spacing.xxs,
      paddingHorizontal: theme.spacing.md,
      paddingTop: theme.spacing.xs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

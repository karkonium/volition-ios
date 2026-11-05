import React, { useRef, useState, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import {
  ScrollView,
  StyleSheet,
  View,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
} from "react-native";
import {
  Button,
  Flex,
  Text,
  colorWithOpacity,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { layout } from "../../../layout/layout";
import type { ChatMessage } from "../../../redux/chatSlice";
import { ChatEmptyState } from "./ChatEmptyState";
import { ConversationMessage } from "./ConversationMessage";

interface ChatTranscriptProps {
  appName?: string;
  messages: ChatMessage[];
  visibleCount: number;
  onLoadEarlier: () => void;
  error: string | null;
  cancelled: boolean;
  onRetry?: () => void;
  children: ReactNode;
}

const visibleAnchor = { minIndexForVisible: 1 };
const latestThreshold = 80;

export function ChatTranscript({
  appName,
  messages,
  visibleCount,
  onLoadEarlier,
  error,
  cancelled,
  onRetry,
  children,
}: ChatTranscriptProps): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const scroll = useRef<ScrollView>(null);
  const followingLatest = useRef(true);
  const loadingEarlier = useRef(false);
  const [showJump, setShowJump] = useState(false);

  const updatePosition = ({
    nativeEvent: { contentOffset, contentSize, layoutMeasurement },
  }: NativeSyntheticEvent<NativeScrollEvent>) => {
    const distance =
      contentSize.height - contentOffset.y - layoutMeasurement.height;
    followingLatest.current = distance <= latestThreshold;
    setShowJump(!followingLatest.current);
  };

  const followLatest = () => {
    if (followingLatest.current)
      scroll.current?.scrollToEnd({ animated: false });
  };

  return (
    <Flex vertical flex={1} style={styles.width}>
      <ScrollView
        ref={scroll}
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode="interactive"
        maintainVisibleContentPosition={visibleAnchor}
        testID="conversationTranscript"
        scrollEventThrottle={32}
        onScroll={updatePosition}
        onLayout={followLatest}
        onContentSizeChange={() => {
          if (loadingEarlier.current) {
            loadingEarlier.current = false;
            return;
          }
          followLatest();
        }}
      >
        <View collapsable={false}>
          {messages.length > visibleCount && (
            <Button
              text={t("earlierMessages")}
              variant="ghost"
              layout="inline"
              buttonStyle={styles.utilityButton}
              onPress={() => {
                loadingEarlier.current = true;
                onLoadEarlier();
              }}
            />
          )}
        </View>
        {messages.length === 0 && <ChatEmptyState appName={appName} />}
        {messages.slice(-visibleCount).map((message) => (
          <ConversationMessage
            key={message.id}
            role={message.role}
            text={message.text}
          />
        ))}
        {children}
        {error && (
          <Flex vertical style={styles.error}>
            <Text
              weight="SemiBold"
              style={styles.errorTitle}
              accessibilityRole="alert"
            >
              {t("chatRequestFailed")}
            </Text>
            <Text type="Small" selectable testID="conversationErrorLabel">
              {error}
            </Text>
            {onRetry && (
              <Button
                text={t("chatRetry")}
                variant="ghost"
                layout="inline"
                buttonStyle={styles.utilityButton}
                testID="conversationRetryButton"
                onPress={onRetry}
              />
            )}
          </Flex>
        )}
        {cancelled && messages.length > 0 && (
          <Text
            type="Small"
            accessibilityLiveRegion="polite"
            testID="conversationCancelledNotice"
          >
            {t("chatCancelled")}
          </Text>
        )}
      </ScrollView>
      {showJump && messages.length > 0 && (
        <Button
          text={t("jumpLatest")}
          leftIcon="arrow-down"
          variant="ghost"
          layout="inline"
          buttonContainerStyle={styles.jump}
          buttonStyle={styles.utilityButton}
          testID="conversationJumpLatest"
          onPress={() => {
            followingLatest.current = true;
            setShowJump(false);
            scroll.current?.scrollToEnd({ animated: false });
          }}
        />
      )}
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    width: {
      width: "100%",
      maxWidth: layout.pageMaxWidth,
      alignSelf: "center",
      minHeight: 0,
    },
    scroll: { flex: 1 },
    content: {
      flexGrow: 1,
      padding: theme.spacing.md,
      gap: theme.spacing.sm,
    },
    error: {
      alignSelf: "flex-start",
      padding: theme.spacing.sm,
      gap: theme.spacing.xxs,
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: colorWithOpacity(theme.colors.error, 0.4),
      borderRadius: theme.radii.base,
      backgroundColor: theme.colors.card,
    },
    errorTitle: { color: theme.colors.error },
    jump: { alignSelf: "center" },
    utilityButton: {
      minHeight: layout.minimumTouchSize,
      paddingVertical: theme.spacing.xs,
    },
  }) satisfies Record<string, ResponsiveStyle>;

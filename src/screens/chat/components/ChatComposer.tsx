import React from "react";
import { useTranslation } from "react-i18next";
import { ActivityIndicator, StyleSheet } from "react-native";
import {
  Button,
  Flex,
  IconButton,
  Text,
  TextField,
  useTheme,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { layout } from "../../../layout/layout";
import { composerState, messageLimit } from "./composerState";

interface ChatComposerProps {
  draft: string;
  pending: boolean;
  hasApp: boolean;
  onChange: (text: string) => void;
  onSend: () => void;
  onCancel: () => void;
}

export function ChatComposer({
  draft,
  pending,
  hasApp,
  onChange,
  onSend,
  onCancel,
}: ChatComposerProps): React.JSX.Element {
  const { t } = useTranslation();
  const { theme } = useTheme();
  const styles = useThemedStyles(createStyles);
  const { canSend, showCount } = composerState(draft, pending);
  const highlighted = canSend && hasApp;

  return (
    <Flex vertical style={styles.composer}>
      {pending && (
        <Flex alignItems="center" justifyContent="space-between" gap="xs">
          <Flex flex={1} alignItems="center" gap="xs">
            <ActivityIndicator color={theme.colors.textLink} />
            <Text
              type="Small"
              style={styles.pending}
              accessibilityLiveRegion="polite"
              testID="conversationThinking"
            >
              {t("coachThinking")}
            </Text>
          </Flex>
          <Button
            text={t("cancelRequest")}
            variant="ghost"
            layout="inline"
            testID="conversationCancelButton"
            buttonStyle={styles.cancel}
            onPress={onCancel}
          />
        </Flex>
      )}
      <Flex gap="xs" alignItems="flex-end">
        <TextField
          placeholderLabel={t("messageCoach")}
          accessibilityLabel={t("messageCoach")}
          value={draft}
          onChange={onChange}
          autoCapitalize="sentences"
          multiline
          maxLength={messageLimit}
          showCharacterCount={false}
          containerStyle={styles.field}
          inputStyle={styles.input}
          testID="conversationMessageField"
        />
        <IconButton
          icon="arrow-up"
          family="Ionicons"
          size={theme.typography.sizes.xxxl}
          buttonColor={
            highlighted ? theme.colors.buttonPrimary : theme.colors.secondary
          }
          iconColor={
            highlighted ? theme.colors.buttonPrimaryText : theme.colors.text
          }
          borderRadius={theme.radii.base}
          accessibilityLabel={t("send")}
          testID="conversationSendButton"
          disabled={!canSend}
          onPress={onSend}
        />
      </Flex>
      {showCount && (
        <Text type="ExtraSmall" style={styles.count} testID="characterCount">
          {t("chatCharacterCount", {
            count: draft.length,
            limit: messageLimit,
          })}
        </Text>
      )}
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    composer: {
      width: "100%",
      maxWidth: layout.pageMaxWidth,
      alignSelf: "center",
      paddingHorizontal: theme.spacing.md,
      paddingVertical: theme.spacing.xs,
      gap: theme.spacing.xxs,
      borderTopWidth: StyleSheet.hairlineWidth,
      borderColor: theme.colors.border,
    },
    field: { flex: 1, minWidth: 0 },
    input: {
      minHeight: layout.minimumTouchSize,
      maxHeight: 128,
      paddingVertical: theme.spacing.xs,
    },
    count: { textAlign: "right", fontVariant: ["tabular-nums"] },
    pending: { flexShrink: 1 },
    cancel: { minHeight: layout.minimumTouchSize, padding: theme.spacing.xs },
  }) satisfies Record<string, ResponsiveStyle>;

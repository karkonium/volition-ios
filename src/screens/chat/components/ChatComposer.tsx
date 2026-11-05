import { layout } from "../../../layout/layout";
import type { ResponsiveStyle, Theme } from "@itsRares/ahhzo-elements";
import React from "react";
import {
  Button,
  Flex,
  IconButton,
  Text,
  TextField,
  useTheme,
  useThemedStyles,
} from "@itsRares/ahhzo-elements";
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
  const { theme } = useTheme();
  const styles = useThemedStyles(createStyles);
  return (
    <Flex vertical style={styles.composer}>
      {pending && (
        <Flex alignItems="center" justifyContent="space-between">
          <Text type="Small" accessibilityLiveRegion="polite">
            Your coach is thinking…
          </Text>
          <Button
            text="Cancel request"
            variant="ghost"
            layout="inline"
            onPress={onCancel}
          />
        </Flex>
      )}
      <Flex gap="xs" alignItems="flex-end">
        <TextField
          placeholderLabel="What would you like to do?"
          accessibilityLabel="Message your coach"
          value={draft}
          onChange={onChange}
          multiline
          maxLength={4000}
          containerStyle={styles.field}
          inputStyle={styles.input}
          testID="conversationMessageField"
        />
        <IconButton
          icon="arrow-up"
          family="Ionicons"
          variant="filled"
          size={theme.sizes.lg}
          buttonColor={
            hasApp ? theme.colors.accent : theme.colors.textSecondary
          }
          iconColor={theme.colors.buttonPrimaryText}
          accessibilityLabel="Send"
          testID="conversationSendButton"
          disabled={!draft.trim() || pending}
          onPress={onSend}
        />
      </Flex>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    composer: {
      width: "100%",
      maxWidth: layout.pageMaxWidth,
      alignSelf: "center",
      paddingHorizontal: theme.spacing.lg,
      paddingVertical: theme.spacing.sm,
      gap: theme.spacing.xs,
      borderTopWidth: 1,
      borderColor: theme.colors.border,
    },
    field: { flex: 1, minWidth: 0 },
    input: { maxHeight: 132 },
  }) satisfies Record<string, ResponsiveStyle>;

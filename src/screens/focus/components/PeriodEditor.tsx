import React from "react";
import { ScrollView } from "react-native";
import {
  Button,
  Flex,
  Modal,
  Text,
  TextField,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { FocusChoice } from "./FocusChoice";
import { days, type PeriodDraft } from "../focusPresentation";
import { AppSelection } from "./AppSelection";
export function PeriodEditor({
  draft,
  setDraft,
  apps,
  onClose,
  onSave,
}: {
  draft: PeriodDraft | null;
  setDraft: (draft: PeriodDraft) => void;
  apps: { id: string; name: string }[];
  onClose: () => void;
  onSave: () => void;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  return (
    <Modal
      title={draft?.id ? "Edit period" : "New period"}
      isVisible={draft !== null}
      onClose={onClose}
    >
      {draft && (
        <ScrollView
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={styles.content}
        >
          <Flex vertical gap="md">
            <Text type="Small">
              Create a recurring boundary for the time you want to protect.
            </Text>
            <TextField
              placeholderLabel="Period name"
              accessibilityLabel="Period name"
              value={draft.name}
              onChange={(name) => setDraft({ ...draft, name })}
              maxLength={100}
            />
            <Flex vertical gap="xs">
              <Text type="H4">Time</Text>
              <Text type="Small">
                Use 24-hour time. An end time before the start continues into
                the next day.
              </Text>
              <Flex wrap="wrap" gap="sm">
                <Flex style={styles.timeField}>
                  <TextField
                    placeholderLabel="Start (HH:mm)"
                    accessibilityLabel="Start time, 24-hour hours and minutes"
                    value={draft.start}
                    onChange={(start) => setDraft({ ...draft, start })}
                  />
                </Flex>
                <Flex style={styles.timeField}>
                  <TextField
                    placeholderLabel="End (HH:mm)"
                    accessibilityLabel="End time, 24-hour hours and minutes"
                    value={draft.end}
                    onChange={(end) => setDraft({ ...draft, end })}
                  />
                </Flex>
              </Flex>
            </Flex>
            <Flex vertical gap="xs">
              <Text type="H4">Repeat on</Text>
              <Text type="Small">
                Overnight periods begin on the selected day.
              </Text>
              <Flex wrap="wrap" gap="xs">
                {days.map((day, index) => (
                  <FocusChoice
                    key={day}
                    label={day}
                    multiple
                    selected={draft.weekdays.includes(index + 1)}
                    onPress={() =>
                      setDraft({
                        ...draft,
                        weekdays: draft.weekdays.includes(index + 1)
                          ? draft.weekdays.filter(
                              (value) => value !== index + 1,
                            )
                          : [...draft.weekdays, index + 1],
                      })
                    }
                  />
                ))}
              </Flex>
            </Flex>
            <AppSelection
              apps={apps}
              selected={draft.appIDs}
              onChange={(appIDs) => setDraft({ ...draft, appIDs })}
            />
            <Button text="Save period" onPress={onSave} />
          </Flex>
        </ScrollView>
      )}
    </Modal>
  );
}
const createStyles = (theme: Theme) =>
  ({
    content: { paddingBottom: theme.spacing.sm },
    timeField: { flexGrow: 1, flexBasis: 130 },
  }) satisfies Record<string, ResponsiveStyle>;

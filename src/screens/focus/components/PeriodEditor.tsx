import React from "react";
import { useTranslation } from "react-i18next";
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
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  return (
    <Modal
      title={draft?.id ? t("editPeriod") : t("newPeriod")}
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
              {t("periodIntro")}
            </Text>
            <TextField
              placeholderLabel={t("periodName")}
              accessibilityLabel={t("periodName")}
              value={draft.name}
              onChange={(name) => setDraft({ ...draft, name })}
              maxLength={100}
            />
            <Flex vertical gap="xs">
              <Text type="H4">{t("time")}</Text>
              <Text type="Small">
                {t("timeHelp")}
              </Text>
              <Flex wrap="wrap" gap="sm">
                <Flex style={styles.timeField}>
                  <TextField
                    placeholderLabel={t("startTime")}
                    accessibilityLabel={t("startTimeLabel")}
                    value={draft.start}
                    onChange={(start) => setDraft({ ...draft, start })}
                  />
                </Flex>
                <Flex style={styles.timeField}>
                  <TextField
                    placeholderLabel={t("endTime")}
                    accessibilityLabel={t("endTimeLabel")}
                    value={draft.end}
                    onChange={(end) => setDraft({ ...draft, end })}
                  />
                </Flex>
              </Flex>
            </Flex>
            <Flex vertical gap="xs">
              <Text type="H4">{t("repeatOn")}</Text>
              <Text type="Small">
                {t("overnightHelp")}
              </Text>
              <Flex wrap="wrap" gap="xs">
                {days.map((day, index) => (
                  <FocusChoice
                    key={day}
                    label={t(day.toLowerCase())}
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
            <Button text={t("savePeriod")} onPress={onSave} />
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

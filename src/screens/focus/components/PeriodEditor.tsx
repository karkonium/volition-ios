import React, { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { enCA, es, zhCN } from "date-fns/locale";
import {
  Button,
  Flex,
  Modal,
  DateField,
  Text,
  TextField,
  useThemedStyles,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { FocusChoice } from "./FocusChoice";
import {
  days,
  everyDay,
  weekdays,
  type PeriodDraft,
} from "../focusPresentation";
import { AppSelection } from "./AppSelection";
import { resolveLanguage } from "../../../translations/locale";

const timeKeys = ["startMinutes", "endMinutes"] as const;
const locales = { en: enCA, es, zh: zhCN };

function dateForTime(minutes: number): Date {
  // Use a fixed local date so a routine can pick any minute on DST transition days.
  return new Date(2000, 0, 15, Math.floor(minutes / 60), minutes % 60);
}

export function PeriodEditor({
  draft,
  setDraft,
  apps,
  onClose,
  onSave,
  busy,
}: {
  draft: PeriodDraft | null;
  setDraft: (draft: PeriodDraft) => void;
  apps: { id: string; name: string }[];
  onClose: () => void;
  onSave: () => void;
  busy: boolean;
}): React.JSX.Element {
  const { t, i18n } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const locale = locales[resolveLanguage(i18n.resolvedLanguage ?? null, [])];
  const startMinutes = draft?.startMinutes ?? 0;
  const endMinutes = draft?.endMinutes ?? 0;
  const timeValues = useMemo(
    () => ({
      startMinutes: dateForTime(startMinutes),
      endMinutes: dateForTime(endMinutes),
    }),
    [startMinutes, endMinutes],
  );
  return (
    <Modal
      title={draft?.id ? t("editPeriod") : t("newPeriod")}
      isVisible={draft !== null}
      onClose={onClose}
      closeLabel={t("cancel")}
      scrollable
    >
      {draft && (
        <Flex vertical gap="md">
          <TextField
            placeholderLabel={t("periodName")}
            accessibilityLabel={t("periodName")}
            value={draft.name}
            onChange={(name) => setDraft({ ...draft, name })}
            maxLength={100}
          />
          <Flex wrap="wrap" gap="sm">
            {timeKeys.map((key) => {
              const label = t(
                key === "startMinutes" ? "focusStartTime" : "focusEndTime",
              );
              return (
                <Flex key={key} style={{ flexGrow: 1, flexBasis: 130 }}>
                  <DateField
                    mode="time"
                    title={label}
                    placeholderLabel={label}
                    rightIcon="time-outline"
                    locale={locale}
                    displayFormat="p"
                    calendarContentContainerStyle={styles.pickerPanel}
                    calendarTimePickerStyle={styles.pickerControls}
                    value={timeValues[key]}
                    onChange={(date) =>
                      setDraft({
                        ...draft,
                        [key]: date.getHours() * 60 + date.getMinutes(),
                      })
                    }
                    disabled={busy}
                  />
                </Flex>
              );
            })}
          </Flex>
          {draft.endMinutes < draft.startMinutes && (
            <Text type="Small">{t("overnightHelp")}</Text>
          )}
          <Flex vertical gap="xs">
            <Text type="H4">{t("repeatOn")}</Text>
            <Flex wrap="wrap" gap="xs">
              {(
                [
                  [t("focusWeekdays"), weekdays],
                  [t("focusEveryDay"), everyDay],
                ] as const
              ).map(([label, values]) => (
                <FocusChoice
                  key={label}
                  label={label}
                  selected={
                    values.length === draft.weekdays.length &&
                    values.every((day) => draft.weekdays.includes(day))
                  }
                  onPress={() => setDraft({ ...draft, weekdays: [...values] })}
                />
              ))}
            </Flex>
            <Flex wrap="wrap" gap="xs">
              {days.map((day, index) => {
                const number = index + 1;
                const selected = draft.weekdays.includes(number);
                return (
                  <FocusChoice
                    key={day}
                    label={t(day)}
                    multiple
                    selected={selected}
                    onPress={() =>
                      setDraft({
                        ...draft,
                        weekdays: selected
                          ? draft.weekdays.filter((value) => value !== number)
                          : [...draft.weekdays, number],
                      })
                    }
                  />
                );
              })}
            </Flex>
          </Flex>
          <AppSelection
            apps={apps}
            scope={draft}
            onChange={(scope) => setDraft({ ...draft, ...scope })}
          />
          <Button text={t("savePeriod")} onPress={onSave} disabled={busy} />
        </Flex>
      )}
    </Modal>
  );
}

const createStyles = (theme: Theme) => ({
  pickerPanel: { borderRadius: theme.radii.lg },
  // DateField already pads its body. Drop the extra divider spacing used below a calendar.
  pickerControls: { marginTop: 0, paddingTop: 0, borderTopWidth: 0 },
});

import React from "react";
import { useTranslation } from "react-i18next";
import { requireNativeViewManager } from "expo-modules-core";
import { Button, Flex, Modal, Text, TextField } from "@itsRares/ahhzo-elements";
import { FocusChoice } from "./FocusChoice";
import {
  days,
  everyDay,
  weekdays,
  type PeriodDraft,
} from "../focusPresentation";
import { AppSelection } from "./AppSelection";

const NativeTimePicker = requireNativeViewManager<{
  minutes: number;
  locale: string;
  label: string;
  onTimeChange: (event: { nativeEvent: { minutes: number } }) => void;
  style: { height: number; width: number };
}>("VolitionScreenTime", "FocusTimePickerView");

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
  return (
    <Modal
      title={draft?.id ? t("editPeriod") : t("newPeriod")}
      isVisible={draft !== null}
      onClose={onClose}
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
          <Flex wrap="wrap" gap="md">
            {(["startMinutes", "endMinutes"] as const).map((key) => {
              const label = t(
                key === "startMinutes" ? "startTimeLabel" : "endTimeLabel",
              );
              return (
                <Flex key={key} vertical gap="xs">
                  <Text type="Small">{label}</Text>
                  <NativeTimePicker
                    minutes={draft[key]}
                    label={label}
                    locale={i18n.resolvedLanguage ?? "en"}
                    style={{ height: 44, width: 145 }}
                    onTimeChange={({ nativeEvent }) =>
                      setDraft({ ...draft, [key]: nativeEvent.minutes })
                    }
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

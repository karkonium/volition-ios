import React, { useState } from "react";
import { Platform } from "react-native";
import { useTranslation } from "react-i18next";
import { Button, Flex, Modal, Text, TextField } from "@itsRares/ahhzo-elements";
import { FocusChoice } from "./FocusChoice";
import { AppSelection, type DraftScope } from "./AppSelection";
import { hasApps } from "../focusPresentation";
import type { QuickFocusPreferences } from "../../../redux/focusSlice";
import { perform } from "../../../components/Screen";

export function SessionSection({
  preferences,
  isRunning,
  apps,
  busy,
  onSave,
  onStart,
  onEnd,
}: {
  preferences: QuickFocusPreferences | null;
  isRunning: boolean;
  apps: { id: string; name: string }[];
  busy: boolean;
  onSave: (preferences: QuickFocusPreferences) => Promise<void>;
  onStart: () => void;
  onEnd: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const [editing, setEditing] = useState(false);
  const [duration, setDuration] = useState("25");
  const [scope, setScope] = useState<DraftScope>({ allApps: null, appIDs: [] });
  const valid = preferences && hasApps(preferences, apps);
  const open = () => {
    setDuration(String(preferences?.minutes ?? 25));
    setScope(preferences ?? { allApps: null, appIDs: [] });
    setEditing(true);
  };
  return (
    <>
      <Flex vertical gap="xs">
        {valid && !isRunning && (
          <Text type="Small">
            {t("quickFocusSummary", {
              count: preferences.minutes,
              apps: preferences.allApps
                ? t("focusAllSavedApps")
                : apps
                    .filter(({ id }) => preferences.appIDs.includes(id))
                    .map(({ name }) => name)
                    .join(", "),
            })}
          </Text>
        )}
        <Flex wrap="wrap" gap="xs">
          <Button
            layout="inline"
            text={t(
              isRunning ? "endFocus" : valid ? "startFocus" : "focusSetUpQuick",
            )}
            variant={isRunning ? "outline" : "filled"}
            disabled={busy}
            onPress={isRunning ? onEnd : valid ? onStart : open}
          />
          {(valid || isRunning) && (
            <Button
              layout="inline"
              text={t("focusQuickSettings")}
              variant="ghost"
              disabled={busy}
              onPress={open}
            />
          )}
        </Flex>
      </Flex>
      <Modal
        title={t("focusQuickSettings")}
        isVisible={editing}
        onClose={() => setEditing(false)}
        scrollable
      >
        <Flex vertical gap="md">
          <Text type="Small">
            {t(
              Platform.OS === "android"
                ? "androidQuickFocusHelp"
                : "quickFocusHelp",
            )}
          </Text>
          <Flex wrap="wrap" gap="xs">
            {[15, 25, 50].map((minutes) => (
              <FocusChoice
                key={minutes}
                label={t("shortMinutes", { count: minutes })}
                selected={duration === String(minutes)}
                onPress={() => setDuration(String(minutes))}
              />
            ))}
          </Flex>
          <TextField
            placeholderLabel={t("customDuration")}
            accessibilityLabel={t("customDurationLabel")}
            value={duration}
            onChange={setDuration}
            keyboardType="number-pad"
          />
          <AppSelection apps={apps} scope={scope} onChange={setScope} />
          <Button
            text={t("focusSaveSettings")}
            disabled={busy}
            onPress={() =>
              perform(async () => {
                const minutes = Number(duration);
                if (!Number.isInteger(minutes) || minutes < 15 || minutes > 180)
                  throw new Error(t("focusDurationError"));
                if (!hasApps(scope, apps))
                  throw new Error(t("focusChooseApps"));
                await onSave({ ...scope, minutes });
                setEditing(false);
              })
            }
          />
        </Flex>
      </Modal>
    </>
  );
}

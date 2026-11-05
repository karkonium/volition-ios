import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import * as Crypto from "expo-crypto";
import { Button, Flex, Text } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { EmptyState } from "../../components/EmptyState/EmptyState";
import { useNow } from "../../components/ActiveGrantBanner";
import { useAppSelector } from "../../redux/store";
import { updateFocus } from "../../services/runtime";
import {
  createPeriodDraft,
  validatePeriodDraft,
  type PeriodDraft,
} from "./focusPresentation";
import { SessionSection } from "./components/SessionSection";
import { PeriodCard } from "./components/PeriodCard";
import { PeriodEditor } from "./components/PeriodEditor";

export function FocusScreen(): React.JSX.Element {
  const { t } = useTranslation();
  const state = useAppSelector((state) => state);
  const now = useNow();
  const [duration, setDuration] = useState("25");
  const [selected, setSelected] = useState<string[]>([]);
  const [draft, setDraft] = useState<PeriodDraft | null>(null);
  const session = state.focus.session;
  const remaining = session
    ? Date.parse(session.start) + session.minutes * 60000 - now
    : 0;
  const activeMinutes = remaining > 0 ? Math.ceil(remaining / 60000) : null;
  return (
    <Screen title={t("focus")} subtitle={t("focusSubtitle")}>
      <SessionSection
        activeMinutes={activeMinutes}
        duration={duration}
        setDuration={setDuration}
        apps={state.apps.items}
        selected={selected}
        setSelected={setSelected}
        onEnd={() =>
          perform(() => updateFocus({ ...state.focus, session: null }))
        }
        onStart={() =>
          perform(async () => {
            const minutes = Number(duration);
            if (!Number.isInteger(minutes) || minutes < 15 || minutes > 180)
              throw new Error(t("focusDurationError"));
            await updateFocus({
              ...state.focus,
              session: {
                id: Crypto.randomUUID(),
                appIDs: selected,
                start: new Date().toISOString(),
                minutes,
              },
            });
          })
        }
      />
      <Flex vertical gap="xs">
        <Text type="H2">{t("recurringPeriods")}</Text>
        <Text type="Small">{t("recurringHelp")}</Text>
      </Flex>
      {state.focus.periods.length === 0 ? (
        <EmptyState
          icon="calendar-outline"
          title={t("focusEmptyTitle")}
          description={t("focusEmptyBody")}
        />
      ) : (
        state.focus.periods.map((period) => (
          <PeriodCard
            key={period.id}
            period={period}
            apps={state.apps.items}
            onEdit={() => setDraft(createPeriodDraft(period))}
            onToggle={() =>
              perform(() =>
                updateFocus({
                  ...state.focus,
                  periods: state.focus.periods.map((item) =>
                    item.id === period.id
                      ? { ...item, isEnabled: !item.isEnabled }
                      : item,
                  ),
                }),
              )
            }
            onDelete={() =>
              perform(() =>
                updateFocus({
                  ...state.focus,
                  periods: state.focus.periods.filter(
                    (item) => item.id !== period.id,
                  ),
                }),
              )
            }
          />
        ))
      )}
      <Button
        text={t("addRecurring")}
        variant="outline"
        onPress={() => setDraft(createPeriodDraft())}
      />
      <PeriodEditor
        draft={draft}
        setDraft={setDraft}
        apps={state.apps.items}
        onClose={() => setDraft(null)}
        onSave={() =>
          perform(async () => {
            if (!draft) return;
            const period = validatePeriodDraft(draft, Crypto.randomUUID());
            await updateFocus({
              ...state.focus,
              periods: [
                ...state.focus.periods.filter((item) => item.id !== period.id),
                period,
              ],
            });
            setDraft(null);
          })
        }
      />
    </Screen>
  );
}

import React, { useEffect, useRef, useState } from "react";
import { Alert, View } from "react-native";
import { useTranslation } from "react-i18next";
import * as Crypto from "expo-crypto";
import {
  Button,
  Flex,
  Modal,
  Text,
  useThemedStyles,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { SymbolTile } from "../../components/SymbolTile/SymbolTile";
import { useRoute, type RouteProp } from "@react-navigation/native";
import { Screen, perform } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
import { useAppSelector } from "../../redux/store";
import type { FocusCommand, FocusOccurrence } from "../../redux/focusSlice";
import type { MainTabs } from "../../navigation/types";
import { applyFocusCommand, syncNative } from "../../services/runtime";
import {
  createPeriodDraft,
  focusDateTime,
  focusName,
  hasApps,
  isValidPeriod,
  type PeriodDraft,
} from "./focusPresentation";
import { SessionSection } from "./components/SessionSection";
import { PeriodCard } from "./components/PeriodCard";
import { PeriodEditor } from "./components/PeriodEditor";

export function FocusScreen(): React.JSX.Element {
  const { t, i18n } = useTranslation();
  const route = useRoute<RouteProp<MainTabs, "Focus">>();
  const styles = useThemedStyles(createStyles);
  const {
    focus,
    apps: { items },
  } = useAppSelector((state) => state);
  const apps = items.filter((app) => app.isEnabled);
  const [draft, setDraft] = useState<PeriodDraft | null>(null);
  const [detailId, setDetailId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const running = useRef(false);
  const editorRevision = useRef(0);
  const locale = i18n.resolvedLanguage;
  const detail = [...focus.active, ...focus.upcoming].find(
    (item) => item.sourceId === detailId,
  );
  useEffect(() => {
    if (route.params?.sourceId) setDetailId(route.params.sourceId);
  }, [route.params]);

  const mutate = async (command: FocusCommand): Promise<void> => {
    if (running.current) throw new Error(t("focusBusy"));
    running.current = true;
    setBusy(true);
    try {
      await applyFocusCommand(command);
    } finally {
      running.current = false;
      setBusy(false);
    }
  };
  const edit = (period?: (typeof focus.periods)[number]) => {
    editorRevision.current = focus.revision;
    setDraft(createPeriodDraft(period));
  };
  const appNames = (ids: string[]) =>
    apps
      .filter(({ id }) => ids.includes(id))
      .map(({ name }) => name)
      .join(", ");
  const session = focus.session;
  const next = focus.upcoming[0];
  const summary = (item: FocusOccurrence, active: boolean) => (
    <Flex vertical gap="xxs">
      <Text weight="SemiBold">{focusName(item, t("quickFocus"))}</Text>
      <Text type="Small">
        {t(active ? "focusEndsAt" : "focusStartsAt", {
          time: focusDateTime(active ? item.endsAt : item.startsAt, locale),
        })}
      </Text>
      {active && (
        <Text type="Small">
          {t("protects", {
            apps:
              appNames(
                item.appIDs.filter((id) => !item.exceptedAppIDs.includes(id)),
              ) || t("focusNoApps"),
          })}
        </Text>
      )}
      {item.exceptedAppIDs.length > 0 && (
        <Text type="Small">
          {t("focusExceptions", { apps: appNames(item.exceptedAppIDs) })}
        </Text>
      )}
    </Flex>
  );

  return (
    <Screen title={t("focus")}>
      {focus.monitoringUnavailable && (
        <VolitionCard>
          <Flex vertical gap="xs">
            <Text accessibilityRole="alert">{t("focusRegistration")}</Text>
            <Button
              text={t("focusRetry")}
              variant="outline"
              onPress={() => perform(syncNative)}
            />
          </Flex>
        </VolitionCard>
      )}
      <VolitionCard accent={focus.active.length > 0}>
        <Flex vertical gap="sm">
          <Flex alignItems="flex-start" gap="sm">
            <SymbolTile name={focus.active.length ? "moon" : "moon-outline"} />
            <Flex vertical gap="xxs" flex={1}>
              <Text type="Small" weight="SemiBold" style={styles.eyebrow}>
                {t("focusNow")}
              </Text>
              {focus.active.length === 0 ? (
                <Text weight="SemiBold">
                  {t(session ? "focusChooseApps" : "focusIdle")}
                </Text>
              ) : (
                focus.active.map((item) => (
                  <View key={item.id}>{summary(item, true)}</View>
                ))
              )}
            </Flex>
          </Flex>
          <View style={styles.divider} />
          <Flex alignItems="flex-start" gap="sm">
            <SymbolTile name="time-outline" />
            <Flex vertical gap="xxs" flex={1}>
              <Text type="Small" weight="SemiBold" style={styles.eyebrow}>
                {t("focusUpNext")}
              </Text>
              {next ? (
                summary(next, false)
              ) : (
                <Text type="Small">{t("focusNothingUpcoming")}</Text>
              )}
            </Flex>
          </Flex>
          <View style={styles.divider} />
          <SessionSection
            preferences={focus.preferences}
            isRunning={Boolean(session)}
            apps={apps}
            busy={busy || focus.revision < 0}
            onSave={(preferences) =>
              mutate({
                kind: "savePreferences",
                preferences,
                expectedRevision: focus.revision,
              })
            }
            onStart={() => perform(() => mutate({ kind: "startSession" }))}
            onEnd={() => {
              if (session)
                perform(() =>
                  mutate({ kind: "endSession", sourceId: session.id }),
                );
            }}
          />
        </Flex>
      </VolitionCard>
      <Flex vertical gap="xs">
        <Flex
          wrap="wrap"
          alignItems="center"
          justifyContent="space-between"
          gap="xs"
        >
          <Text type="H3" accessibilityRole="header">
            {t("focusRoutines")}
          </Text>
          <Button
            layout="inline"
            text={t("focusAddRoutine")}
            variant="outline"
            disabled={busy || focus.revision < 0}
            testID="addFocusRoutine"
            onPress={() => edit()}
          />
        </Flex>
        {focus.periods.length === 0 && (
          <Text type="Small">{t("focusRoutinesEmpty")}</Text>
        )}
      </Flex>
      {focus.periods.map((period) => (
        <PeriodCard
          key={period.id}
          period={period}
          apps={apps}
          busy={busy}
          onEdit={() => edit(period)}
          onToggle={() =>
            perform(() =>
              mutate({
                kind: "saveRoutine",
                expectedRevision: focus.revision,
                period: { ...period, isEnabled: !period.isEnabled },
              }),
            )
          }
          onDelete={() =>
            Alert.alert(
              t("focusDeleteRoutine", { name: period.name }),
              undefined,
              [
                { text: t("cancel"), style: "cancel" },
                {
                  text: t("delete"),
                  style: "destructive",
                  onPress: () =>
                    perform(() =>
                      mutate({
                        kind: "deleteRoutine",
                        sourceId: period.id,
                        expectedRevision: focus.revision,
                      }),
                    ),
                },
              ],
            )
          }
        />
      ))}
      <PeriodEditor
        draft={draft}
        setDraft={setDraft}
        apps={apps}
        busy={busy}
        onClose={() => setDraft(null)}
        onSave={() =>
          perform(async () => {
            if (!draft) return;
            if (!isValidPeriod(draft)) throw new Error(t("focusInvalid"));
            if (!hasApps(draft, apps)) throw new Error(t("focusChooseApps"));
            await mutate({
              kind: "saveRoutine",
              expectedRevision: editorRevision.current,
              period: {
                ...draft,
                name: draft.name.trim(),
                id: draft.id ?? Crypto.randomUUID(),
              },
            });
            setDraft(null);
          })
        }
      />
      <Modal
        title={t("focus")}
        isVisible={detailId !== null}
        onClose={() => setDetailId(null)}
        scrollable
      >
        {detail ? (
          summary(
            detail,
            focus.active.some(({ id }) => id === detail.id),
          )
        ) : (
          <Text>{t("focusNothingActive")}</Text>
        )}
      </Modal>
    </Screen>
  );
}

const createStyles = (theme: Theme) => ({
  eyebrow: { color: theme.colors.textSecondary },
  divider: { height: 1, backgroundColor: theme.colors.border },
});

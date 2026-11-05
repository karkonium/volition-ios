import { AppRow } from "./components/AppRow";
import { EmptyState } from "../../components/EmptyState/EmptyState";
import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { Button, Text, Modal, TextField, Flex } from "@itsRares/ahhzo-elements";
import { useNavigation, type NavigationProp } from "@react-navigation/native";
import { Screen, perform } from "../../components/Screen";
import { useNow } from "../../components/ActiveGrantBanner";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import type { VolitionSavedApp } from "../../redux/appsSlice";
import { chatActions } from "../../redux/chatSlice";
import { removeApp, recordRemoval } from "../../services/runtime";
import { focusProtects } from "../../services/policy";
import type { AppsStack, MainTabs } from "../../navigation/types";
import type { CompositeNavigationProp } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
export function AppsScreen(): React.JSX.Element {
  const { t } = useTranslation();
  const state = useAppSelector((state) => state);
  const dispatch = useAppDispatch();
  const navigation =
    useNavigation<
      CompositeNavigationProp<
        StackNavigationProp<AppsStack, "AppsHome">,
        NavigationProp<MainTabs>
      >
    >();
  const now = useNow();
  const [removing, setRemoving] = useState<VolitionSavedApp | null>(null);
  const [reason, setReason] = useState("");
  const [step, setStep] = useState(1);
  const [minutes, setMinutes] = useState("5");
  return (
    <Screen title={t("apps")} subtitle={t("appsSubtitle")}>
      {state.apps.items.length === 0 && (
        <EmptyState
          icon="apps-outline"
          title={t("appsEmptyTitle")}
          description={t("appsEmptyBody")}
        />
      )}
      {state.apps.items.map((app) => {
        const grant = state.grants.activeGrants.find(
          (item) => item.appId === app.id,
        );
        const deal = state.grants.commitments.find(
          (item) =>
            item.appId === app.id &&
            !item.overriddenAt &&
            Date.parse(item.blockedUntil) > now,
        );
        const status = focusProtects(state.focus, app.id, now)
          ? t("focusProtected")
          : grant
            ? t("temporarilyOpen", {
                count: Math.max(
                  0,
                  Math.ceil((Date.parse(grant.expiresAt) - now) / 60000),
                ),
              })
            : deal
              ? t("activeBreak", {
                  count: Math.ceil(
                    (Date.parse(deal.blockedUntil) - now) / 60000,
                  ),
                })
              : t("shielded");
        return (
          <AppRow
            key={app.id}
            app={app}
            status={status}
            onEdit={() => {
              navigation.navigate("AppEditor", { appId: app.id });
            }}
            onRemove={() => {
              setRemoving(app);
              setStep(1);
              setReason("");
              setMinutes("5");
            }}
          />
        );
      })}
      <Button
        text={t("addApp")}
        testID="addVolitionAppButton"
        onPress={() => {
          navigation.navigate("AppEditor", {});
        }}
      />
      <Modal
        title={t("removeApp")}
        isVisible={removing !== null}
        scrollable
        onClose={() => setRemoving(null)}
      >
        <Flex vertical gap="md">
          {step === 1 ? (
            <>
              <Text>{t("removeReasonPrompt")}</Text>
              <TextField
                placeholderLabel={t("optionalReason")}
                value={reason}
                onChange={setReason}
                maxLength={2000}
                multiline
              />
              <Button text={t("continue")} onPress={() => setStep(2)} />
            </>
          ) : (
            <>
              <Text>{t("removeAlternative")}</Text>
              <TextField
                placeholderLabel={t("minutesRange")}
                value={minutes}
                onChange={setMinutes}
                keyboardType="number-pad"
              />
              {(!Number.isInteger(Number(minutes)) ||
                Number(minutes) < 1 ||
                Number(minutes) > 60) && (
                <Text accessibilityRole="alert">{t("minutesValidation")}</Text>
              )}
              <Button
                text={t("requestTemporary")}
                onPress={() => {
                  if (!removing) return;
                  const count = Number(minutes);
                  if (!Number.isInteger(count) || count < 1 || count > 60)
                    return;
                  recordRemoval(removing, reason, "requested_access");
                  dispatch(
                    chatActions.boundRequest({
                      appId: removing.id,
                      draft: t("removalDraft", { count, reason }),
                    }),
                  );
                  setRemoving(null);
                  navigation.navigate("Chat");
                }}
              />
              <Button
                text={t("removeNow")}
                tone="danger"
                variant="outline"
                onPress={() =>
                  perform(async () => {
                    if (removing) {
                      await removeApp(removing.id, reason);
                      setRemoving(null);
                    }
                  })
                }
              />
            </>
          )}
          <Button
            text={t("keepApp")}
            variant="ghost"
            onPress={() => {
              if (removing) recordRemoval(removing, reason, "kept");
              setRemoving(null);
            }}
          />
        </Flex>
      </Modal>
    </Screen>
  );
}

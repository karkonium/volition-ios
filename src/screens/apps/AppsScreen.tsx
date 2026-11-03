import { VolitionAppIcon } from "../../components/VolitionAppIcon";
import React, { useState } from "react";
import { Button, Text, Modal, TextField, Flex } from "@itsRares/ahhzo-elements";
import { useNavigation, type NavigationProp } from "@react-navigation/native";
import { Screen, perform } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
import { useNow } from "../../components/ActiveGrantBanner";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import type { VolitionSavedApp } from "../../redux/appsSlice";
import { activityLogActions } from "../../redux/activityLogSlice";
import { chatActions } from "../../redux/chatSlice";
import { removeApp } from "../../services/runtime";
import { focusProtects } from "../../services/policy";
import { AppEditorModal } from "./AppEditorModal";
import type { MainTabs } from "../../navigation/types";
export function AppsScreen(): React.JSX.Element {
  const state = useAppSelector((state) => state);
  const dispatch = useAppDispatch();
  const navigation = useNavigation<NavigationProp<MainTabs>>();
  const now = useNow();
  const [editing, setEditing] = useState<VolitionSavedApp | undefined>();
  const [editor, setEditor] = useState(false);
  const [removing, setRemoving] = useState<VolitionSavedApp | null>(null);
  const [reason, setReason] = useState("");
  const [step, setStep] = useState(1);
  const [minutes, setMinutes] = useState("5");
  return (
    <Screen title="Apps" subtitle="Your apps, with intention">
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
          ? "Focus protected"
          : grant
            ? `Temporarily open · ${Math.max(0, Math.ceil((Date.parse(grant.expiresAt) - now) / 60000))}m`
            : deal
              ? `Active break · ${Math.ceil((Date.parse(deal.blockedUntil) - now) / 60000)}m`
              : "Shielded";
        return (
          <VolitionCard key={app.id}>
            <VolitionAppIcon tokenBase64={app.tokenBase64} />
            <Text type="H3">{app.name}</Text>
            <Text type="Small">{status}</Text>
            <Text>{app.goal}</Text>
            <Button
              text="Edit"
              variant="ghost"
              onPress={() => {
                setEditing(app);
                setEditor(true);
              }}
            />
            <Button
              text="Remove app"
              variant="ghost"
              tone="danger"
              onPress={() => {
                setRemoving(app);
                setStep(1);
                setReason("");
              }}
            />
          </VolitionCard>
        );
      })}
      <Button
        text="Add app"
        testID="addVolitionAppButton"
        onPress={() => {
          setEditing(undefined);
          setEditor(true);
        }}
      />
      <AppEditorModal
        visible={editor}
        existing={editing}
        onClose={() => setEditor(false)}
      />
      <Modal
        title="Remove app"
        isVisible={removing !== null}
        onClose={() => setRemoving(null)}
      >
        <Flex vertical gap="md">
          {step === 1 ? (
            <>
              <Text>
                What made this feel unhelpful? This feedback stays private.
              </Text>
              <TextField
                placeholderLabel="Optional reason"
                value={reason}
                onChange={setReason}
                maxLength={2000}
                multiline
              />
              <Button text="Continue" onPress={() => setStep(2)} />
            </>
          ) : (
            <>
              <Text>
                Would a little access help instead? You can ask the coach, or
                remove this app now.
              </Text>
              <TextField
                placeholderLabel="Minutes (1–60)"
                value={minutes}
                onChange={setMinutes}
                keyboardType="number-pad"
              />
              <Button
                text="Request temporary access"
                onPress={() => {
                  if (!removing) return;
                  const count = Number(minutes);
                  if (!Number.isInteger(count) || count < 1 || count > 60)
                    return;
                  dispatch(
                    activityLogActions.removalRecorded({
                      appId: removing.id,
                      date: new Date().toISOString(),
                      reason,
                      disposition: "requested_access",
                    }),
                  );
                  dispatch(
                    chatActions.boundRequest({
                      appId: removing.id,
                      draft: `I'd like ${count} minutes of access. ${reason}`,
                    }),
                  );
                  setRemoving(null);
                  navigation.navigate("Chat");
                }}
              />
              <Button
                text="Remove app now"
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
            text="Keep app"
            variant="ghost"
            onPress={() => setRemoving(null)}
          />
        </Flex>
      </Modal>
    </Screen>
  );
}

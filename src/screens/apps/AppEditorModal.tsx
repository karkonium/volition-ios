import { AttentionRegion } from "../../components/AttentionRegion";
import React, { useRef, useState } from "react";
import { AccessibilityInfo } from "react-native";
import * as Crypto from "expo-crypto";
import {
  Modal,
  Button,
  Text,
  TextField,
  Flex,
  type TextFieldRef,
} from "@itsRares/ahhzo-elements";
import { VolitionScreenTime } from "../../../modules/volition-screen-time";
import type { VolitionSavedApp } from "../../redux/appsSlice";
import { saveApp } from "../../services/runtime";
import { perform } from "../../components/Screen";
export function AppEditorForm({
  existing,
  onSaved,
}: {
  existing?: VolitionSavedApp;
  onSaved: () => void;
}): React.JSX.Element {
  const [token, setToken] = useState(existing?.tokenBase64 ?? "");
  const [name, setName] = useState(existing?.name ?? "");
  const [notes, setNotes] = useState(existing?.notes ?? "");
  const [purposes, setPurposes] = useState(existing?.purposes ?? []);
  const [changes, setChanges] = useState(existing?.changes ?? []);
  const [style, setStyle] = useState(existing?.sessionStyle ?? "unsure");
  const [missing, setMissing] = useState(false);
  const [busy, setBusy] = useState(false);
  const nameField = useRef<TextFieldRef>(null);
  const toggle = (
    value: string,
    items: string[],
    set: (items: string[]) => void,
  ): void =>
    set(
      items.includes(value)
        ? items.filter((item) => item !== value)
        : [...items, value],
    );
  return (
    <Flex vertical gap="md">
      <Text type="H3">1. Choose one app</Text>
      <Button
        text={token ? "Change selected app" : "Choose app"}
        testID="pickVolitionAppButton"
        onPress={() =>
          perform(async () => {
            try {
              const selection = await VolitionScreenTime.presentAppPicker();
              setToken(selection.tokenBase64);
            } catch (error) {
              if (
                error instanceof Error &&
                error.message.toLowerCase().includes("cancel")
              )
                return;
              throw error;
            }
          })
        }
      />
      <Text type="H3">2. Give it a name</Text>
      <AttentionRegion trigger={missing ? 1 : 0}>
        <TextField
          ref={nameField}
          placeholderLabel="e.g. SoundCloud"
          value={name}
          onChange={(text) => {
            setName(text);
            setMissing(false);
          }}
          maxLength={600}
          testID="volitionAppName"
        />
      </AttentionRegion>
      {missing && (
        <Text accessibilityRole="alert">Please give this app a name.</Text>
      )}
      <Text type="H3">3. Set your intention</Text>
      <Text>What do you want this app for?</Text>
      <Flex wrap="wrap" gap="sm">
        {[
          "communication",
          "productivity",
          "learning",
          "relaxation",
          "other",
        ].map((purpose) => (
          <Button
            key={purpose}
            text={`${purposes.includes(purpose) ? "✓ " : ""}${purpose}`}
            variant={purposes.includes(purpose) ? "filled" : "outline"}
            onPress={() => toggle(purpose, purposes, setPurposes)}
          />
        ))}
      </Flex>
      <Text>What would you like to change?</Text>
      <Flex wrap="wrap" gap="sm">
        {[
          "habit",
          "duration",
          "frequency",
          "distraction",
          "timing",
          "intention",
          "unsure",
        ].map((change) => (
          <Button
            key={change}
            text={`${changes.includes(change) ? "✓ " : ""}${change}`}
            variant="outline"
            onPress={() => toggle(change, changes, setChanges)}
          />
        ))}
      </Flex>
      <Text>Session style</Text>
      <Flex wrap="wrap" gap="sm">
        {["shortVisits", "longerSessions", "both", "unsure"].map((value) => (
          <Button
            key={value}
            text={`${style === value ? "✓ " : ""}${value}`}
            variant="ghost"
            onPress={() => setStyle(value)}
          />
        ))}
      </Flex>
      <TextField
        placeholderLabel="Optional notes"
        value={notes}
        onChange={setNotes}
        maxLength={2000}
        multiline
        testID="volitionAppIntention"
      />
      <Button
        text="Save app"
        testID="saveVolitionAppButton"
        loading={busy}
        disabled={!token}
        onPress={() => {
          if (!name.trim()) {
            setMissing(true);
            nameField.current?.focus();
            AccessibilityInfo.announceForAccessibility(
              "Please give this app a name.",
            );
            return;
          }
          perform(async () => {
            setBusy(true);
            try {
              await saveApp({
                id: existing?.id ?? Crypto.randomUUID(),
                name: name.trim(),
                goal: purposes.length
                  ? `Use this app for ${purposes.join(", ")}.`
                  : "Use this app with intention.",
                notes,
                tokenBase64: token,
                isEnabled: true,
                createdAt: existing?.createdAt ?? new Date().toISOString(),
                purposes,
                changes,
                sessionStyle: style,
              });
              onSaved();
            } finally {
              setBusy(false);
            }
          });
        }}
      />
    </Flex>
  );
}
export function AppEditorModal({
  visible,
  existing,
  onClose,
}: {
  visible: boolean;
  existing?: VolitionSavedApp;
  onClose: () => void;
}): React.JSX.Element {
  return (
    <Modal
      title={existing ? "Edit app" : "Save an app"}
      isVisible={visible}
      onClose={onClose}
    >
      <AppEditorForm
        key={existing?.id ?? "new"}
        existing={existing}
        onSaved={onClose}
      />
    </Modal>
  );
}

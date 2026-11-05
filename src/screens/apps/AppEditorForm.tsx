import React, { useRef, useState } from "react";
import { AccessibilityInfo, Pressable, View } from "react-native";
import * as Crypto from "expo-crypto";
import {
  Button,
  Text,
  TextField,
  Flex,
  Icon,
  useTheme,
  useThemedStyles,
  type TextFieldRef,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { VolitionScreenTime } from "../../../modules/volition-screen-time";
import { AttentionRegion } from "../../components/AttentionRegion";
import { VolitionAppIcon } from "../../components/VolitionAppIcon";
import { perform } from "../../components/Screen";
import type { VolitionSavedApp } from "../../redux/appsSlice";
import { saveApp } from "../../services/runtime";
import { ProfileQuestion } from "./components/ProfileQuestion";
import { editorGoal, sessionStyles } from "./editorProfile";

const purposesOptions = [
  ["communication", "Communication"],
  ["productivity", "Productivity"],
  ["learning", "Learning"],
  ["relaxation", "Relaxation"],
  ["other", "Something else"],
].map(([value, label]) => ({ value: value!, label: label! }));
const changeOptions = [
  ["habit", "Build a healthier habit"],
  ["duration", "Spend less time"],
  ["frequency", "Open it less often"],
  ["distraction", "Reduce distractions"],
  ["timing", "Use it at better times"],
  ["intention", "Be more intentional"],
  ["unsure", "Not sure yet"],
].map(([value, label]) => ({ value: value!, label: label! }));

export function AppEditorForm({
  existing,
  onSaved,
}: {
  existing?: VolitionSavedApp;
  onSaved: () => void;
}): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  const { theme } = useTheme();
  const [token, setToken] = useState(existing?.tokenBase64 ?? "");
  const [name, setName] = useState(existing?.name ?? "");
  const [notes, setNotes] = useState(existing?.notes ?? "");
  const [purposes, setPurposes] = useState(existing?.purposes ?? []);
  const [changes, setChanges] = useState(existing?.changes ?? []);
  const [style, setStyle] = useState(existing?.sessionStyle ?? "unsure");
  const [missing, setMissing] = useState(0);
  const [busy, setBusy] = useState(false);
  const nameField = useRef<TextFieldRef>(null);
  return (
    <Flex vertical gap="md">
      <View style={styles.stepCard}>
        <Text type="H4">1. Choose one app</Text>
        <Text type="Small">
          Choose the app you’d like to use more intentionally.
        </Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={token ? "Change selected app" : "Choose app"}
          testID="pickVolitionAppButton"
          style={styles.preview}
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
        >
          <VolitionAppIcon key={token} tokenBase64={token} />
          <Flex vertical style={styles.previewText}>
            <Text weight="SemiBold">
              {token ? name.trim() || "App selected" : "Choose an app"}
            </Text>
            <Text type="Small">
              {token ? "Tap to change" : "Select one app"}
            </Text>
          </Flex>
          <Icon
            name="chevron-forward"
            family="Ionicons"
            size={theme.sizes.md}
            color={theme.colors.textSecondary}
            accessible={false}
          />
        </Pressable>
      </View>
      <View style={styles.stepCard}>
        <Text type="H4">2. Give it a name</Text>
        <AttentionRegion trigger={missing}>
          <TextField
            ref={nameField}
            placeholderLabel="App name"
            inputStyle={styles.input}
            value={name}
            onChange={(text) => {
              setName(text);
              setMissing(0);
            }}
            maxLength={600}
            showCharacterCount={name.length > 500}
            testID="volitionAppName"
          />
        </AttentionRegion>
        <Text type="Small" testID="volitionAppNameHelp">
          Use the app’s actual name, for example SoundCloud.
        </Text>
        {missing > 0 && (
          <Text accessibilityRole="alert" style={styles.error}>
            Please give this app a name.
          </Text>
        )}
      </View>
      <View style={styles.stepCard}>
        <Text type="H4">3. Set your intention</Text>
        <Text type="Small">
          Think about when you want to use it, work you need to do, or how you’d
          like to scroll.
        </Text>
        <ProfileQuestion
          title="What do you want this app for?"
          options={purposesOptions}
          values={purposes}
          onChange={setPurposes}
          testID="profilePurposes"
        />
        <ProfileQuestion
          title="What would you like to change?"
          options={changeOptions}
          values={changes}
          onChange={setChanges}
        />
        <View style={styles.session}>
          <Text weight="SemiBold">What kind of sessions work for you?</Text>
          <Flex vertical>
            {sessionStyles.map((option) => (
              <Pressable
                key={option.value}
                accessibilityRole="radio"
                accessibilityState={{ checked: style === option.value }}
                onPress={() => setStyle(option.value)}
                style={styles.option}
              >
                <Text
                  style={
                    style === option.value ? styles.selected : styles.radio
                  }
                >
                  {style === option.value ? "●" : "○"}
                </Text>
                <Text>{option.label}</Text>
              </Pressable>
            ))}
          </Flex>
        </View>
        <Text weight="SemiBold">Anything else?</Text>
        <Text type="Small">
          Optional notes can help your coach understand your intention.
        </Text>
        <TextField
          placeholderLabel="Add a note"
          inputStyle={styles.input}
          value={notes}
          onChange={setNotes}
          maxLength={2000}
          showCharacterCount={notes.length > 1800}
          multiline
          testID="volitionAppIntention"
        />
      </View>
      <Button
        text="Save app"
        testID="saveVolitionAppButton"
        loading={busy}
        disabled={!token || busy}
        onPress={() => {
          if (!name.trim()) {
            setMissing((value) => value + 1);
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
                goal: editorGoal(existing?.goal, purposes),
                notes,
                tokenBase64: token,
                isEnabled: existing?.isEnabled ?? true,
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
const createStyles = (theme: Theme) =>
  ({
    stepCard: {
      backgroundColor: theme.colors.card,
      borderColor: theme.colors.border,
      borderWidth: 1,
      borderRadius: theme.radii.md,
      padding: theme.spacing.md,
      gap: theme.spacing.sm,
    },
    preview: {
      backgroundColor: theme.colors.secondary,
      borderRadius: theme.radii.base,
      minHeight: 64,
      padding: theme.spacing.sm,
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.sm,
    },
    previewText: { flex: 1, minWidth: 0 },
    input: { backgroundColor: theme.colors.background },
    error: { color: theme.colors.error },
    session: {
      borderTopWidth: 1,
      borderColor: theme.colors.border,
      paddingTop: theme.spacing.md,
      gap: theme.spacing.xs,
    },
    option: {
      minHeight: 44,
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.sm,
    },
    selected: {
      color: theme.colors.textLink,
      fontSize: theme.typography.sizes.xl,
    },
    radio: {
      color: theme.colors.textSecondary,
      fontSize: theme.typography.sizes.xl,
    },
  }) satisfies Record<string, ResponsiveStyle>;

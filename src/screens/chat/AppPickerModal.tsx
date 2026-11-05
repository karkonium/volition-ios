import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { StyleSheet, useWindowDimensions } from "react-native";
import {
  Flex,
  Icon,
  Modal,
  Text,
  TextField,
  Touchable,
  colorWithOpacity,
  useTheme,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { VolitionAppIcon } from "../../components/VolitionAppIcon";
import { layout } from "../../layout/layout";
import { chatActions } from "../../redux/chatSlice";
import { useAppDispatch, useAppSelector } from "../../redux/store";

export function AppPickerModal({
  visible,
  onClose,
}: {
  visible: boolean;
  onClose: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const { theme } = useTheme();
  const { width } = useWindowDimensions();
  const styles = useThemedStyles(createStyles);
  const [search, setSearch] = useState("");
  const apps = useAppSelector((state) => state.apps.items);
  const selectedId = useAppSelector((state) => state.chat.selectedAppId);
  const dispatch = useAppDispatch();
  const enabled = apps.filter((app) => app.isEnabled);
  const query = search.trim().toLocaleLowerCase();
  const matching = enabled.filter((app) =>
    [app.name, app.goal, app.notes].some((value) =>
      value?.toLocaleLowerCase().includes(query),
    ),
  );
  const close = () => {
    setSearch("");
    onClose();
  };

  return (
    <Modal
      title={t("chooseApp")}
      isVisible={visible}
      onClose={close}
      presentation={width >= 768 ? "centered" : "bottom"}
      avoidKeyboard
      contentContainerStyle={styles.sheet}
      titleTextStyle={styles.title}
      iconContainerStyle={styles.close}
    >
      <Flex vertical gap="sm">
        {enabled.length >= 5 && (
          <TextField
            placeholderLabel={t("searchSavedApps")}
            accessibilityLabel={t("searchSavedApps")}
            leftIcon="search-outline"
            value={search}
            onChange={setSearch}
            autoCorrect={false}
          />
        )}
        <Flex vertical style={styles.list}>
          {matching.map((app) => {
            const selected = selectedId === app.id;
            return (
              <Touchable
                key={app.id}
                type="opacity"
                accessibilityRole="button"
                accessibilityState={{ selected }}
                accessibilityLabel={app.name}
                style={[styles.row, selected && styles.selected]}
                testID="conversationAppOption"
                onPress={() => {
                  dispatch(chatActions.boundSelected(app.id));
                  close();
                }}
              >
                <VolitionAppIcon tokenBase64={app.tokenBase64} />
                <Flex vertical flex={1} gap="xxs">
                  <Text weight="SemiBold" numberOfLines={2}>
                    {app.name}
                  </Text>
                  <Text type="Small" numberOfLines={2}>
                    {app.goal}
                  </Text>
                </Flex>
                <Icon
                  name={selected ? "checkmark-circle" : "chevron-forward"}
                  size={theme.typography.sizes.lg}
                  color={selected ? theme.colors.textLink : theme.colors.textSecondary}
                />
              </Touchable>
            );
          })}
        </Flex>
        {matching.length === 0 && (
          <Text type="Small" style={styles.empty}>
            {t(enabled.length ? "chatNoMatchingApps" : "chatNoSavedApps")}
          </Text>
        )}
      </Flex>
    </Modal>
  );
}

const createStyles = (theme: Theme) =>
  ({
    sheet: { maxWidth: 460, padding: theme.spacing.md },
    title: { fontSize: theme.typography.sizes.xxxl },
    close: { backgroundColor: theme.colors.secondary },
    list: { gap: theme.spacing.xxs },
    row: {
      minHeight: layout.minimumTouchSize,
      flexDirection: "row",
      alignItems: "center",
      gap: theme.spacing.xs,
      borderRadius: theme.radii.base,
      padding: theme.spacing.xs,
      backgroundColor: theme.colors.background,
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: theme.colors.border,
    },
    selected: {
      backgroundColor: colorWithOpacity(theme.colors.accent, 0.09),
      borderColor: colorWithOpacity(theme.colors.accent, 0.35),
    },
    empty: { padding: theme.spacing.xs },
  }) satisfies Record<string, ResponsiveStyle>;

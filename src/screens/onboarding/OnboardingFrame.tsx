import React, { type PropsWithChildren } from "react";
import { Pressable, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import {
  Icon,
  ScrollArea,
  Text,
  useTheme,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { useTranslation } from "react-i18next";

export function OnboardingFrame({
  step,
  onBack,
  children,
}: PropsWithChildren<{
  step: number;
  onBack?: () => void;
}>): React.JSX.Element {
  const styles = useThemedStyles(createStyles);
  const { theme } = useTheme();
  const { t } = useTranslation();
  return (
    <SafeAreaView
      style={styles.safe}
      edges={["top", "bottom", "left", "right"]}
    >
      <View style={styles.container}>
        <View style={styles.header}>
          {onBack ? (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t("onboardingBack")}
              onPress={onBack}
              style={styles.back}
            >
              <Icon
                name="chevron-back"
                family="Ionicons"
                size={theme.sizes.lg}
                color={theme.colors.text}
                accessible={false}
              />
            </Pressable>
          ) : (
            <View style={styles.back} />
          )}
          <View
            accessible
            accessibilityLabel={t("onboardingProgress", { step, total: 4 })}
            style={styles.progress}
          >
            <View style={styles.dots}>
              {[1, 2, 3, 4].map((item) => (
                <View
                  key={item}
                  style={[
                    styles.dot,
                    item === step && styles.activeDot,
                    item < step && styles.completedDot,
                  ]}
                />
              ))}
            </View>
            <Text type="ExtraSmall">
              {t("onboardingProgress", { step, total: 4 })}
            </Text>
          </View>
          <View style={styles.back} />
        </View>
        <ScrollArea
          sizing="fill"
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="interactive"
          automaticallyAdjustKeyboardInsets
          contentStyle={styles.scroll}
        >
          {children}
        </ScrollArea>
      </View>
    </SafeAreaView>
  );
}
const createStyles = (theme: Theme) =>
  ({
    safe: { flex: 1, backgroundColor: theme.colors.background },
    container: { flex: 1, width: "100%", maxWidth: 720, alignSelf: "center" },
    header: {
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "space-between",
      paddingHorizontal: theme.spacing.md,
    },
    back: {
      width: 44,
      height: 44,
      justifyContent: "center",
      alignItems: "center",
    },
    progress: { alignItems: "center", gap: theme.spacing.xxs },
    dots: { flexDirection: "row", gap: theme.spacing.xs, alignItems: "center" },
    dot: {
      width: 7,
      height: 7,
      borderRadius: theme.radii.pill,
      backgroundColor: theme.colors.border,
    },
    activeDot: { width: 22, backgroundColor: theme.colors.accent },
    completedDot: { backgroundColor: theme.colors.accent, opacity: 0.5 },
    scroll: {
      flexGrow: 1,
      paddingHorizontal: theme.spacing.lg,
      paddingTop: theme.spacing.sm,
      paddingBottom: theme.spacing.lg,
    },
  }) satisfies Record<string, ResponsiveStyle>;

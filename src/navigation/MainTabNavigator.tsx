import { previewMode } from "../../modules/volition-screen-time";
import React from "react";
import { useTranslation } from "react-i18next";
import { useWindowDimensions } from "react-native";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createStackNavigator } from "@react-navigation/stack";
import { getFocusedRouteNameFromRoute } from "@react-navigation/native";
import Ionicons from "@expo/vector-icons/Ionicons";
import {
  useTheme,
  useThemedStyles,
  Text,
  Flex,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { ChatScreen } from "../screens/chat/ChatScreen";
import { AppsScreen } from "../screens/apps/AppsScreen";
import { AppEditorScreen } from "../screens/apps/AppEditorScreen";
import { InsightsScreen } from "../screens/insights/InsightsScreen";
import { FocusScreen } from "../screens/focus/FocusScreen";
import { SettingsScreen } from "../screens/settings/SettingsScreen";
import { PreferencesScreen } from "../screens/settings/PreferencesScreen";
import { CoachSettingsScreen } from "../screens/settings/CoachSettingsScreen";
import { PrivacyDataScreen } from "../screens/settings/PrivacyDataScreen";
import { ActivityLogScreen } from "../screens/settings/ActivityLogScreen";
import { DiagnosticsLogsScreen } from "../screens/settings/DiagnosticsLogsScreen";
import type { AppsStack, MainTabs, SettingsStack } from "./types";
const Tabs = createBottomTabNavigator<MainTabs>();
const Stack = createStackNavigator<SettingsStack>();
const AppsStackNavigator = createStackNavigator<AppsStack>();
function AppsNavigator(): React.JSX.Element {
  const { theme } = useTheme();
  return (
    <AppsStackNavigator.Navigator
      screenOptions={{
        headerShown: false,
        cardStyle: { backgroundColor: theme.colors.background },
      }}
    >
      <AppsStackNavigator.Screen
        name="AppsHome"
        component={AppsScreen}
        options={{ headerShown: false }}
      />
      <AppsStackNavigator.Screen name="AppEditor" component={AppEditorScreen} />
    </AppsStackNavigator.Navigator>
  );
}
function SettingsNavigator(): React.JSX.Element {
  const { theme } = useTheme();
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
        cardStyle: { backgroundColor: theme.colors.background },
      }}
    >
      <Stack.Screen
        name="SettingsHome"
        component={SettingsScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen name="Preferences" component={PreferencesScreen} />
      <Stack.Screen name="CoachSettings" component={CoachSettingsScreen} />
      <Stack.Screen name="PrivacyData" component={PrivacyDataScreen} />
      <Stack.Screen name="ActivityLog" component={ActivityLogScreen} />
      <Stack.Screen name="Diagnostics" component={DiagnosticsLogsScreen} />
    </Stack.Navigator>
  );
}
const icons: Record<
  keyof MainTabs,
  React.ComponentProps<typeof Ionicons>["name"]
> = {
  Chat: "chatbubble-outline",
  Apps: "apps-outline",
  Insights: "bar-chart-outline",
  Focus: "moon-outline",
  Settings: "settings-outline",
};
export function MainTabNavigator(): React.JSX.Element {
  const { t } = useTranslation();
  const { width } = useWindowDimensions();
  const sidebar = width >= 768;
  const { theme } = useTheme();
  const styles = useThemedStyles(createStyles);
  const tabs = (
    <Tabs.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarLabel: t(
          (
            {
              Chat: "chat",
              Apps: "apps",
              Insights: "insights",
              Focus: "focus",
              Settings: "settings",
            } as const
          )[route.name],
        ),
        tabBarButtonTestID: `sidebarItem-${route.name.toLowerCase()}`,
        tabBarPosition: sidebar ? "left" : "bottom",
        tabBarVariant: sidebar ? "material" : "uikit",
        tabBarHideOnKeyboard: true,
        tabBarLabelStyle: { fontSize: sidebar ? 15 : 10, fontWeight: "500" },
        tabBarItemStyle: {
          borderRadius: 14,
          marginHorizontal: sidebar ? 12 : 0,
          marginVertical: sidebar ? 4 : 0,
        },
        tabBarActiveBackgroundColor: sidebar
          ? theme.colors.secondary
          : "transparent",
        sceneStyle: { backgroundColor: theme.colors.background },
        tabBarActiveTintColor: theme.colors.tabBarActiveTintColor,
        tabBarInactiveTintColor: theme.colors.textSecondary,
        tabBarStyle: {
          display:
            !sidebar &&
            route.name === "Apps" &&
            getFocusedRouteNameFromRoute(route) === "AppEditor"
              ? "none"
              : "flex",
          backgroundColor: theme.colors.tabBarBackground,
          borderColor: theme.colors.border,
          borderTopWidth: sidebar ? 0 : 0.5,
          elevation: 0,
          ...(sidebar ? { width: 210, paddingTop: 60 } : { paddingTop: 7 }),
        },
        tabBarIcon: ({ color, size }) => (
          <Ionicons name={icons[route.name]} color={color} size={size} />
        ),
      })}
    >
      <Tabs.Screen name="Chat" component={ChatScreen} />
      <Tabs.Screen name="Apps" component={AppsNavigator} />
      <Tabs.Screen name="Insights" component={InsightsScreen} />
      <Tabs.Screen name="Focus" component={FocusScreen} />
      <Tabs.Screen name="Settings" component={SettingsNavigator} />
    </Tabs.Navigator>
  );
  return previewMode ? (
    <Flex vertical flex={1}>
      <SafeAreaView edges={["top", "left", "right"]} style={styles.preview}>
        <Text type="ExtraSmall" style={styles.previewText}>
          {t("preview")}
        </Text>
      </SafeAreaView>
      <SafeAreaProvider>{tabs}</SafeAreaProvider>
    </Flex>
  ) : (
    tabs
  );
}

const createStyles = (theme: Theme) => ({
  preview: { backgroundColor: theme.colors.background },
  previewText: {
    textAlign: "center" as const,
    backgroundColor: theme.colors.secondary,
    color: theme.colors.textSecondary,
    paddingVertical: theme.spacing.xxs,
  },
});

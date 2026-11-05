import { previewMode } from "../../modules/volition-screen-time";
import React from "react";
import { useWindowDimensions } from "react-native";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createStackNavigator } from "@react-navigation/stack";
import Ionicons from "@expo/vector-icons/Ionicons";
import { useTheme, Text, Flex } from "@itsRares/ahhzo-elements";
import { ChatScreen } from "../screens/chat/ChatScreen";
import { AppsScreen } from "../screens/apps/AppsScreen";
import { InsightsScreen } from "../screens/insights/InsightsScreen";
import { FocusScreen } from "../screens/focus/FocusScreen";
import { SettingsScreen } from "../screens/settings/SettingsScreen";
import { CoachSettingsScreen } from "../screens/settings/CoachSettingsScreen";
import { PrivacyDataScreen } from "../screens/settings/PrivacyDataScreen";
import { ActivityLogScreen } from "../screens/settings/ActivityLogScreen";
import { DiagnosticsLogsScreen } from "../screens/settings/DiagnosticsLogsScreen";
import type { MainTabs, SettingsStack } from "./types";
const Tabs = createBottomTabNavigator<MainTabs>();
const Stack = createStackNavigator<SettingsStack>();
function SettingsNavigator(): React.JSX.Element {
  const { theme } = useTheme();
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: theme.colors.background },
        headerTintColor: theme.colors.text,
        cardStyle: { backgroundColor: theme.colors.background },
        headerTitle: "",
      }}
    >
      <Stack.Screen
        name="SettingsHome"
        component={SettingsScreen}
        options={{ headerShown: false }}
      />
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
  const { width } = useWindowDimensions();
  const sidebar = width >= 768;
  const { theme } = useTheme();
  return (
    <Flex vertical flex={1}>
      {previewMode && (
        <Text
          type="ExtraSmall"
          style={{
            textAlign: "center",
            backgroundColor: theme.colors.secondary,
            color: theme.colors.textSecondary,
            paddingVertical: 4,
          }}
        >
          Preview mode · no device restrictions
        </Text>
      )}
      <Tabs.Navigator
        screenOptions={({ route }) => ({
          headerShown: false,
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
        <Tabs.Screen name="Apps" component={AppsScreen} />
        <Tabs.Screen name="Insights" component={InsightsScreen} />
        <Tabs.Screen name="Focus" component={FocusScreen} />
        <Tabs.Screen name="Settings" component={SettingsNavigator} />
      </Tabs.Navigator>
    </Flex>
  );
}

import { previewMode } from "../../modules/volition-screen-time";
import React, { useEffect, useState, useRef } from "react";
import { AppState, Linking, useColorScheme } from "react-native";
import {
  NavigationContainer,
  DefaultTheme,
  DarkTheme,
  createNavigationContainerRef,
} from "@react-navigation/native";
import { useTheme, Button, Text } from "@itsRares/ahhzo-elements";
import { useAppDispatch, useAppSelector } from "../redux/store";
import { authActions } from "../redux/authSlice";
import { initializeRuntime, syncNative } from "../services/runtime";
import { trackScreen } from "../services/telemetry";
import { diagnostic } from "../services/diagnostics";
import { Screen, perform } from "../components/Screen";
import { WelcomeScreen } from "../screens/onboarding/WelcomeScreen";
import { AIConsentScreen } from "../screens/onboarding/AIConsentScreen";
import { ScreenTimeGateScreen } from "../screens/onboarding/ScreenTimeGateScreen";
import { SetupFirstAppScreen } from "../screens/onboarding/SetupFirstAppScreen";
import { MainTabNavigator } from "./MainTabNavigator";
import type { MainTabs } from "./types";
const navigation = createNavigationContainerRef<MainTabs>();
export function AppNavigator(): React.JSX.Element {
  const state = useAppSelector((state) => state);
  const dispatch = useAppDispatch();
  const { theme } = useTheme();
  const scheme = useColorScheme();
  const [ready, setReady] = useState(false);
  const initialized = useRef(false);
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState(0);
  const initialize = async (): Promise<void> => {
    setError(null);
    try {
      await initializeRuntime();
      initialized.current = true;
      setReady(true);
    } catch {
      setError(
        "Your saved data could not be opened. It has been preserved. Please retry.",
      );
    }
  };
  useEffect(() => {
    void initialize();
    const listener = AppState.addEventListener("change", (status) => {
      if (status === "active" && initialized.current)
        void syncNative().catch(() => diagnostic("native.sync_failed"));
    });
    const timer = setInterval(() => {
      if (AppState.currentState === "active" && initialized.current)
        void syncNative().catch(() => diagnostic("native.sync_failed"));
    }, 30000);
    return () => {
      listener.remove();
      clearInterval(timer);
    };
  }, []);
  useEffect(() => {
    if (!previewMode) return;
    const listener = Linking.addEventListener("url", ({ url }) => {
      const route = url.split("/").pop();
      if (
        navigation.isReady() &&
        ["Chat", "Apps", "Insights", "Focus", "Settings"].includes(route ?? "")
      )
        navigation.navigate(route as keyof MainTabs);
    });
    return () => listener.remove();
  }, []);
  useEffect(() => {
    if (navigation.isReady() && state.chat.selectedAppId)
      navigation.navigate("Chat");
  }, [state.chat.routeVersion]);
  if (!ready)
    return (
      <Screen title="Volition">
        <Text>{error ?? "Preparing your saved apps…"}</Text>
        {error && <Button text="Retry" onPress={() => perform(initialize)} />}
      </Screen>
    );
  const finish = (): void => {
    dispatch(authActions.onboardingCompleted());
  };
  let content: React.JSX.Element;
  if (!state.auth.onboarded && step === 0)
    content = <WelcomeScreen onContinue={() => setStep(1)} />;
  else if (!state.auth.onboarded && step === 1)
    content = <AIConsentScreen onContinue={() => setStep(2)} />;
  else if (state.auth.authorization !== "approved")
    content = <ScreenTimeGateScreen onApproved={() => setStep(3)} />;
  else if (!state.apps.items.length)
    content = <SetupFirstAppScreen onSaved={finish} />;
  else content = <MainTabNavigator />;
  return (
    <NavigationContainer
      ref={navigation}
      onReady={() => trackScreen(navigation.getCurrentRoute()?.name)}
      onStateChange={() => trackScreen(navigation.getCurrentRoute()?.name)}
      theme={{
        ...(scheme === "dark" ? DarkTheme : DefaultTheme),
        colors: {
          ...(scheme === "dark" ? DarkTheme.colors : DefaultTheme.colors),
          background: theme.colors.background,
          card: theme.colors.card,
          text: theme.colors.text,
          primary: theme.colors.accent,
          border: theme.colors.border,
          notification: theme.colors.notification,
        },
      }}
    >
      {content}
    </NavigationContainer>
  );
}

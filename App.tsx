import "react-native-gesture-handler";
import React, { useEffect, useState } from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { Provider } from "react-redux";
import { PersistGate } from "redux-persist/integration/react";
import { StatusBar } from "expo-status-bar";
import { useAppSelector } from "./src/redux/store";
import { updateTelemetry } from "./src/services/telemetry";
import { store, persistor } from "./src/redux/store";
import { VolitionThemeProvider } from "./src/layout/VolitionThemeProvider";
import { AppNavigator } from "./src/navigation/AppNavigator";
import { i18nReady } from "./src/translations/i18n";
function TelemetryPreferences(): null {
  const analytics = useAppSelector((state) => state.settings.analyticsEnabled);
  const crashReports = useAppSelector(
    (state) => state.settings.crashReportsEnabled,
  );
  useEffect(
    () => updateTelemetry(analytics, crashReports),
    [analytics, crashReports],
  );
  return null;
}
export default function App(): React.JSX.Element | null {
  const [languageReady, setLanguageReady] = useState(false);
  useEffect(() => {
    void i18nReady.finally(() => setLanguageReady(true));
  }, []);
  if (!languageReady) return null;
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <Provider store={store}>
          <PersistGate loading={null} persistor={persistor}>
            <TelemetryPreferences />
            <VolitionThemeProvider>
              <StatusBar style="auto" />
              <AppNavigator />
            </VolitionThemeProvider>
          </PersistGate>
        </Provider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

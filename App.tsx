import "react-native-gesture-handler";
import React from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { Provider } from "react-redux";
import { PersistGate } from "redux-persist/integration/react";
import { StatusBar } from "expo-status-bar";
import { store, persistor } from "./src/redux/store";
import { VolitionThemeProvider } from "./src/layout/VolitionThemeProvider";
import { AppNavigator } from "./src/navigation/AppNavigator";
export default function App(): React.JSX.Element | null {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <Provider store={store}>
          <PersistGate loading={null} persistor={persistor}>
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

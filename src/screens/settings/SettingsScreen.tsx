import React from "react";
import { Button } from "@itsRares/ahhzo-elements";
import { useNavigation, type NavigationProp } from "@react-navigation/native";
import { Screen } from "../../components/Screen";
import type { SettingsStack } from "../../navigation/types";
export function SettingsScreen(): React.JSX.Element {
  const navigation = useNavigation<NavigationProp<SettingsStack>>();
  return (
    <Screen title="Settings">
      <Button
        text="Coach settings"
        variant="outline"
        onPress={() => navigation.navigate("CoachSettings")}
      />
      <Button
        text="Activity log"
        testID="conversationActivityLogButton"
        variant="outline"
        onPress={() => navigation.navigate("ActivityLog")}
      />
      <Button
        text="Privacy & data"
        variant="outline"
        onPress={() => navigation.navigate("PrivacyData")}
      />
      <Button
        text="Diagnostics"
        variant="outline"
        onPress={() => navigation.navigate("Diagnostics")}
      />
    </Screen>
  );
}

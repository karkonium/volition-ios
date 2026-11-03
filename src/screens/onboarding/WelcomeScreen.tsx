import { Image } from "react-native";
import React from "react";
import { Button, Text, useThemedStyles } from "@itsRares/ahhzo-elements";
import { Screen } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
export function WelcomeScreen({
  onContinue,
}: {
  onContinue: () => void;
}): React.JSX.Element {
  const styles = useThemedStyles((theme) => ({
    logo: {
      width: 96,
      height: 96,
      borderRadius: theme.radii.lg,
      alignSelf: "center" as const,
      marginVertical: theme.spacing.md,
    },
  }));
  return (
    <Screen title="Volition" subtitle="Make room for what matters">
      <Image
        source={require("../../../assets/icon.png")}
        style={styles.logo}
        accessibilityLabel="Volition"
      />
      <VolitionCard>
        <Text type="H3">A conversation before a scroll</Text>
        <Text>
          Tell your coach what you want to do. Choose a pause, a little access,
          or an agreement that helps you stop.
        </Text>
      </VolitionCard>
      <Text>1. Choose AI sharing</Text>
      <Text>2. Allow Screen Time access</Text>
      <Text>3. Save an app with intention</Text>
      <Button text="Get started" onPress={onContinue} />
    </Screen>
  );
}

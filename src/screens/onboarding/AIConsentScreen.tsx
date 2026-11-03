import React from "react";
import { Button, Text } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { useAppSelector } from "../../redux/store";
import { setConsent } from "../../services/runtime";
export function AIConsentScreen({
  onContinue,
}: {
  onContinue: () => void;
}): React.JSX.Element {
  const consent = useAppSelector((state) => state.auth.aiConsent);
  return (
    <Screen title="Your coach, your choice">
      <Text>
        To respond, OpenAI receives your messages, app names, intentions and
        notes, recent allocated access sessions, active grants, waits,
        agreements and optional recent check-ins. This is not measured app
        usage.
      </Text>
      <Text>
        Chat and private activity history stay on this device. You can withdraw
        sharing at any time in Privacy & Data, which cancels pending responses
        and offers.
      </Text>
      <Button
        text={consent ? "AI sharing: On" : "AI sharing: Off"}
        variant="outline"
        onPress={() => perform(() => setConsent(!consent))}
      />
      <Button text="Continue" onPress={onContinue} />
    </Screen>
  );
}

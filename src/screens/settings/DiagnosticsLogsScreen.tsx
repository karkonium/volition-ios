import React from "react";
import { Text } from "@itsRares/ahhzo-elements";
import { Screen } from "../../components/Screen";
import { diagnosticEntries } from "../../services/diagnostics";
export function DiagnosticsLogsScreen(): React.JSX.Element {
  return (
    <Screen title="Diagnostics">
      <Text>
        Technical event names only. No messages, app selections or credentials.
      </Text>
      {[...diagnosticEntries()].reverse().map((entry, index) => (
        <Text type="Small" key={`${entry.date}-${index}`}>
          {entry.date} · {entry.event}
        </Text>
      ))}
    </Screen>
  );
}

import React from "react";
import { Screen } from "../../components/Screen";
import { AppEditorForm } from "../apps/AppEditorModal";
export function SetupFirstAppScreen({
  onSaved,
}: {
  onSaved: () => void;
}): React.JSX.Element {
  return (
    <Screen title="Save your first app">
      <AppEditorForm onSaved={onSaved} />
    </Screen>
  );
}

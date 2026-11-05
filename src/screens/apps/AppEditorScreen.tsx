import React from "react";
import type { StackScreenProps } from "@react-navigation/stack";
import { Header, Page } from "@itsRares/ahhzo-elements";
import type { AppsStack } from "../../navigation/types";
import { useAppSelector } from "../../redux/store";
import { AppEditorForm } from "./AppEditorForm";

export function AppEditorScreen({
  route,
  navigation,
}: StackScreenProps<AppsStack, "AppEditor">): React.JSX.Element {
  const appId = route.params.appId;
  const existing = useAppSelector((state) =>
    state.apps.items.find((app) => app.id === appId),
  );
  return (
    <Page tabHidden>
      <Header
        title={appId ? "Edit app" : "Save an app"}
        leftIcon="chevron-back"
        leftIconFamily="Ionicons"
        leftIconLabel="Back to Apps"
        onLeftIconPress={() => navigation.goBack()}
      />
      {appId && !existing ? null : (
        <AppEditorForm
          existing={existing}
          onSaved={() => navigation.goBack()}
        />
      )}
    </Page>
  );
}

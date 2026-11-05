import React from "react";
import { useTranslation } from "react-i18next";
import { Screen } from "../../components/Screen";
import { AppEditorForm } from "../apps/AppEditorForm";
export function SetupFirstAppScreen({
  onSaved,
}: {
  onSaved: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  return (
    <Screen title={t("firstApp")}>
      <AppEditorForm onSaved={onSaved} />
    </Screen>
  );
}

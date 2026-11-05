import React from "react";
import { useTranslation } from "react-i18next";
import { ConversationMessage } from "./ConversationMessage";

export function ChatEmptyState({
  appName,
}: {
  appName?: string;
}): React.JSX.Element {
  const { t } = useTranslation();
  return (
    <ConversationMessage
      role="assistant"
      text={appName ? t("chatPromptWithApp", { app: appName }) : t("chatPromptWithoutApp")}
    />
  );
}

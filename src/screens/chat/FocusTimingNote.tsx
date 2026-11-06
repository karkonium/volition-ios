import React from "react";
import { useTranslation } from "react-i18next";
import { Text } from "@itsRares/ahhzo-elements";
import { focusTime } from "../focus/focusPresentation";

export function FocusTimingNote({ until }: { until: string }) {
  const { t, i18n } = useTranslation();
  return (
    <Text type="Small" accessibilityLiveRegion="polite">
      {t("focusAccessLimit", { time: focusTime(until, i18n.resolvedLanguage) })}
    </Text>
  );
}

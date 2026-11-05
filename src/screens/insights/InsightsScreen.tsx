import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { Flex } from "@itsRares/ahhzo-elements";
import { Screen } from "../../components/Screen";
import { useAppSelector } from "../../redux/store";
import { useNow } from "../../components/ActiveGrantBanner";
import { buildInsights, type InsightsPeriod } from "./insightsData";
import { InsightsOverview } from "./InsightsOverview";
import { InsightsApps } from "./InsightsApps";

export function InsightsScreen(): React.JSX.Element {
  const { t } = useTranslation();
  const [period, setPeriod] = useState<InsightsPeriod>("week");
  const history = useAppSelector((state) => state.grants.accessHistory);
  const apps = useAppSelector((state) => state.apps.items);
  const now = new Date(useNow());
  const data = buildInsights(history, period, now);
  return (
    <Screen title={t("insights")} subtitle={t("insightsSubtitle")}>
      <Flex vertical gap="lg">
        <InsightsOverview
          data={data}
          period={period}
          onPeriodChange={setPeriod}
          now={now}
        />
        <InsightsApps apps={apps} totals={data.apps} period={period} />
      </Flex>
    </Screen>
  );
}

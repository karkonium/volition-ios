import React from "react";
import { useTranslation } from "react-i18next";
import { Flex, Text } from "@itsRares/ahhzo-elements";
import { FocusChoice } from "./FocusChoice";

export type DraftScope = { allApps: boolean | null; appIDs: string[] };

export function AppSelection({
  apps,
  scope,
  onChange,
}: {
  apps: { id: string; name: string }[];
  scope: DraftScope;
  onChange: (scope: DraftScope) => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  return (
    <Flex vertical gap="xs">
      <Text type="H4">{t("protectedApps")}</Text>
      <Flex wrap="wrap" gap="xs">
        <FocusChoice
          label={t("focusAllSavedApps")}
          selected={scope.allApps === true}
          onPress={() => onChange({ allApps: true, appIDs: [] })}
        />
        <FocusChoice
          label={t("focusSelectedApps")}
          selected={scope.allApps === false}
          onPress={() => onChange({ allApps: false, appIDs: scope.appIDs })}
        />
      </Flex>
      {scope.allApps && <Text type="Small">{t("focusAllAppsHelp")}</Text>}
      {scope.allApps === false && (
        <Flex wrap="wrap" gap="xs">
          {apps.map((app) => (
            <FocusChoice
              key={app.id}
              label={app.name}
              multiple
              selected={scope.appIDs.includes(app.id)}
              onPress={() =>
                onChange({
                  allApps: false,
                  appIDs: scope.appIDs.includes(app.id)
                    ? scope.appIDs.filter((id) => id !== app.id)
                    : [...scope.appIDs, app.id],
                })
              }
            />
          ))}
        </Flex>
      )}
      {!apps.length && <Text type="Small">{t("saveAppsFirst")}</Text>}
    </Flex>
  );
}

import React from "react";
import { useTranslation } from "react-i18next";
import { Flex, Text } from "@itsRares/ahhzo-elements";
import { FocusChoice } from "./FocusChoice";

export function AppSelection({
  apps,
  selected,
  onChange,
}: {
  apps: { id: string; name: string }[];
  selected: string[];
  onChange: (ids: string[]) => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  return (
    <Flex vertical gap="xxs">
      <Text type="H4">{t("protectedApps")}</Text>
      <Text type="Small">{t("protectedAppsHelp")}</Text>
      <Flex wrap="wrap" gap="xs">
        <FocusChoice
          label={t("allApps")}
          selected={!selected.length}
          onPress={() => onChange([])}
        />
        {apps.map((app) => (
          <FocusChoice
            key={app.id}
            label={app.name}
            multiple
            selected={selected.includes(app.id)}
            onPress={() =>
              onChange(
                selected.includes(app.id)
                  ? selected.filter((id) => id !== app.id)
                  : [...selected, app.id],
              )
            }
          />
        ))}
      </Flex>
      {!apps.length && <Text type="Small">{t("saveAppsFirst")}</Text>}
    </Flex>
  );
}

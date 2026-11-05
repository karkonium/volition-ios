import React from "react";
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
  return (
    <Flex vertical gap="xxs">
      <Text type="H4">Protected apps</Text>
      <Text type="Small">
        Choose specific saved apps, or leave all apps selected to protect every
        app.
      </Text>
      <Flex wrap="wrap" gap="xs">
        <FocusChoice
          label="All apps"
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
      {!apps.length && (
        <Text type="Small">Save apps in Apps to choose them individually.</Text>
      )}
    </Flex>
  );
}

import React, { useState } from "react";
import { useTranslation } from "react-i18next";
import { Modal, Button, TextField, Flex } from "@itsRares/ahhzo-elements";
import { useAppSelector, useAppDispatch } from "../../redux/store";
import { chatActions } from "../../redux/chatSlice";
export function AppPickerModal({
  visible,
  onClose,
}: {
  visible: boolean;
  onClose: () => void;
}): React.JSX.Element {
  const { t } = useTranslation();
  const [search, setSearch] = useState("");
  const apps = useAppSelector((state) => state.apps.items);
  const dispatch = useAppDispatch();
  return (
    <Modal title={t("chooseApp")} isVisible={visible} onClose={onClose}>
      <Flex vertical gap="sm">
        <TextField
          placeholderLabel={t("searchSavedApps")}
          value={search}
          onChange={setSearch}
        />
        {apps
          .filter(
            (app) =>
              app.isEnabled &&
              app.name.toLowerCase().includes(search.toLowerCase()),
          )
          .map((app) => (
            <Button
              key={app.id}
              text={app.name}
              variant="outline"
              testID="conversationAppOption"
              onPress={() => {
                dispatch(chatActions.boundSelected(app.id));
                onClose();
              }}
            />
          ))}
      </Flex>
    </Modal>
  );
}

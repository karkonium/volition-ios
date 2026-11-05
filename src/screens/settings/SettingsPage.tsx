import React, { type PropsWithChildren } from "react";
import { Flex, Header, Page } from "@itsRares/ahhzo-elements";
import { useNavigation } from "@react-navigation/native";
import { useTranslation } from "react-i18next";

export function SettingsPage({
  title,
  subtitle,
  children,
}: PropsWithChildren<{ title: string; subtitle?: string }>): React.JSX.Element {
  const navigation = useNavigation();
  const { t } = useTranslation();
  return (
    <Page tabHidden bottomInset={false}>
      <Header
        title={title}
        subtitle={subtitle}
        leftIcon="chevron-back-outline"
        leftIconLabel={t("settings")}
        onLeftIconPress={() => navigation.goBack()}
      />
      <Flex vertical gap="md">
        {children}
      </Flex>
    </Page>
  );
}

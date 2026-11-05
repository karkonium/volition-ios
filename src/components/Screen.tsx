import React, { type PropsWithChildren, type ReactNode } from "react";
import { Alert } from "react-native";
import { Page, Header, Flex } from "@itsRares/ahhzo-elements";
export function Screen({
  title,
  subtitle,
  children,
  action,
}: PropsWithChildren<{
  title: string;
  subtitle?: string;
  action?: ReactNode;
}>): React.JSX.Element {
  return (
    <Page tabHidden bottomInset={false}>
      <Flex alignItems="center" gap="sm">
        <Flex flex={1}>
          <Header title={title} subtitle={subtitle} />
        </Flex>
        {action}
      </Flex>
      <Flex vertical gap="md">
        {children}
      </Flex>
    </Page>
  );
}
export function perform(action: () => Promise<unknown>): void {
  void action().catch((error: unknown) =>
    Alert.alert(
      "Volition",
      error instanceof Error
        ? error.message
        : "This action could not be completed. Please try again.",
    ),
  );
}

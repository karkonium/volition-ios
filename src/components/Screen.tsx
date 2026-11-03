import React, { type PropsWithChildren } from "react";
import { Alert } from "react-native";
import { Page, Header, Flex } from "@itsRares/ahhzo-elements";
export function Screen({
  title,
  subtitle,
  children,
}: PropsWithChildren<{ title: string; subtitle?: string }>): React.JSX.Element {
  return (
    <Page>
      <Header title={title} subtitle={subtitle} />
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

import {
  nativeAvailable,
  previewMode,
} from "../../modules/volition-screen-time";
import React from "react";
import { requireNativeViewManager } from "expo-modules-core";
import { Text, useThemedStyles } from "@itsRares/ahhzo-elements";
import type { ViewProps } from "react-native";
const NativeIcon =
  nativeAvailable && !previewMode
    ? requireNativeViewManager<ViewProps & { tokenBase64: string }>(
        "VolitionScreenTime",
      )
    : null;
export function VolitionAppIcon({
  tokenBase64,
}: {
  tokenBase64: string;
}): React.JSX.Element {
  const styles = useThemedStyles((theme) => ({
    icon: { width: theme.spacing.xxl, height: theme.spacing.xxl },
  }));
  return tokenBase64 && NativeIcon ? (
    <NativeIcon tokenBase64={tokenBase64} style={styles.icon} />
  ) : (
    <Text type="Small">App</Text>
  );
}

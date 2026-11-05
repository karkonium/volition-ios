import {
  nativeAvailable,
  previewMode,
} from "../../modules/volition-screen-time";
import React from "react";
import { requireNativeViewManager } from "expo-modules-core";
import {
  useThemedStyles,
  type Theme,
  type ResponsiveStyle,
} from "@itsRares/ahhzo-elements";
import { SymbolTile } from "./SymbolTile/SymbolTile";
import { View, type ViewProps } from "react-native";
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
  const styles = useThemedStyles(createStyles);
  return (
    <View style={styles.container}>
      <SymbolTile name="apps-outline" />
      {tokenBase64 && NativeIcon ? (
        <NativeIcon tokenBase64={tokenBase64} style={styles.icon} />
      ) : null}
    </View>
  );
}

const createStyles = (theme: Theme) =>
  ({
    container: {
      width: theme.spacing.xxl,
      height: theme.spacing.xxl,
      alignItems: "center",
      justifyContent: "center",
    },
    icon: {
      position: "absolute",
      width: theme.spacing.xxl,
      height: theme.spacing.xxl,
    },
  }) satisfies Record<string, ResponsiveStyle>;

import React, { useEffect, useRef, type PropsWithChildren } from "react";
import { AccessibilityInfo, Animated } from "react-native";
import { useThemedStyles } from "@itsRares/ahhzo-elements";
/// Shared, reduced-motion-aware attention for missing app names and targets.
export function AttentionRegion({
  trigger,
  children,
}: PropsWithChildren<{ trigger: number }>): React.JSX.Element {
  const scale = useRef(new Animated.Value(1)).current;
  const styles = useThemedStyles((theme) => ({
    region: {
      borderWidth: trigger ? 1 : 0,
      borderColor: theme.colors.accent,
      borderRadius: theme.radii.base,
      padding: trigger ? theme.spacing.xs : 0,
    },
  }));
  useEffect(() => {
    let cancelled = false;
    if (trigger)
      void AccessibilityInfo.isReduceMotionEnabled().then((reduced) => {
        if (!cancelled && !reduced)
          Animated.sequence([
            Animated.timing(scale, {
              toValue: 1.025,
              duration: 120,
              useNativeDriver: true,
            }),
            Animated.timing(scale, {
              toValue: 1,
              duration: 160,
              useNativeDriver: true,
            }),
          ]).start();
      });
    return () => {
      cancelled = true;
      scale.stopAnimation();
      scale.setValue(1);
    };
  }, [trigger, scale]);
  return (
    <Animated.View style={[styles.region, { transform: [{ scale }] }]}>
      {children}
    </Animated.View>
  );
}

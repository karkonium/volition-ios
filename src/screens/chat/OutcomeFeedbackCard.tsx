import React from "react";
import { useTranslation } from "react-i18next";
import {
  Text,
  Button,
  Flex,
  useThemedStyles,
  type ResponsiveStyle,
  type Theme,
} from "@itsRares/ahhzo-elements";
import { layout } from "../../layout/layout";
import { useAppDispatch } from "../../redux/store";
import {
  activityLogActions,
  type ActivityLogEntry,
  type OutcomeFeedback,
} from "../../redux/activityLogSlice";

const ratings: OutcomeFeedback[] = ["helpful", "neutral", "annoying"];

export function OutcomeFeedbackCard({
  entry,
}: {
  entry: ActivityLogEntry;
}): React.JSX.Element {
  const { t } = useTranslation();
  const styles = useThemedStyles(createStyles);
  const dispatch = useAppDispatch();

  return (
    <Flex vertical style={styles.feedback}>
      <Text type="ExtraSmall" weight="SemiBold">
        {t("chatPrivateFeedback")}
      </Text>
      <Text type="Small">{t("chatFeedbackPrompt")}</Text>
      <Flex wrap="wrap" gap="xxs">
        {ratings.map((feedback) => (
          <Button
            key={feedback}
            text={t(feedback)}
            variant="secondary"
            layout="inline"
            buttonStyle={styles.rating}
            onPress={() =>
              dispatch(activityLogActions.rated({ id: entry.id, feedback }))
            }
          />
        ))}
      </Flex>
    </Flex>
  );
}

const createStyles = (theme: Theme) =>
  ({
    feedback: {
      alignSelf: "flex-start",
      gap: theme.spacing.xxs,
      paddingHorizontal: theme.spacing.xxs,
    },
    rating: {
      minHeight: layout.minimumTouchSize,
      padding: theme.spacing.xs,
      borderRadius: theme.radii.pill,
    },
  }) satisfies Record<string, ResponsiveStyle>;

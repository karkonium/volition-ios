import React, { useState } from "react";
import * as Crypto from "expo-crypto";
import { Button, Flex, Text, Modal, TextField } from "@itsRares/ahhzo-elements";
import { Screen, perform } from "../../components/Screen";
import { VolitionCard } from "../../components/VolitionCard";
import { useNow } from "../../components/ActiveGrantBanner";
import { useAppSelector } from "../../redux/store";
import { updateFocus } from "../../services/runtime";
import type { FocusPeriod } from "../../redux/focusSlice";
function parseTime(value: string): number {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!match) throw new Error("Use a time such as 09:00.");
  const hour = Number(match[1]),
    minute = Number(match[2]);
  if (hour > 23 || minute > 59) throw new Error("Enter a valid time.");
  return hour * 60 + minute;
}
export function FocusScreen(): React.JSX.Element {
  const state = useAppSelector((state) => state);
  const now = useNow();
  const [duration, setDuration] = useState("25");
  const [selected, setSelected] = useState<string[]>([]);
  const [visible, setVisible] = useState(false);
  const [editing, setEditing] = useState<string | null>(null);
  const [name, setName] = useState("Focus time");
  const [start, setStart] = useState("09:00");
  const [end, setEnd] = useState("10:00");
  const [weekdays, setWeekdays] = useState([2, 3, 4, 5, 6]);
  const session = state.focus.session;
  const active =
    session && Date.parse(session.start) + session.minutes * 60000 > now;
  const toggle = (id: string): void =>
    setSelected((items) =>
      items.includes(id) ? items.filter((item) => item !== id) : [...items, id],
    );
  const open = (period?: FocusPeriod): void => {
    setEditing(period?.id ?? null);
    setName(period?.name ?? "Focus time");
    setWeekdays(period?.weekdays ?? [2, 3, 4, 5, 6]);
    setSelected(period?.appIDs ?? []);
    setStart(
      period
        ? `${String(Math.floor(period.startMinutes / 60)).padStart(2, "0")}:${String(period.startMinutes % 60).padStart(2, "0")}`
        : "09:00",
    );
    setEnd(
      period
        ? `${String(Math.floor(period.endMinutes / 60)).padStart(2, "0")}:${String(period.endMinutes % 60).padStart(2, "0")}`
        : "10:00",
    );
    setVisible(true);
  };
  return (
    <Screen title="Focus" subtitle="A deliberate boundary">
      {active && (
        <VolitionCard accent>
          <Text type="H2">
            {Math.ceil(
              (Date.parse(session.start) + session.minutes * 60000 - now) /
                60000,
            )}{" "}
            minutes left
          </Text>
          <Button
            text="End Focus"
            variant="outline"
            onPress={() =>
              perform(() => updateFocus({ ...state.focus, session: null }))
            }
          />
        </VolitionCard>
      )}
      <Text type="H3">Start a session</Text>
      <Flex gap="sm" wrap="wrap">
        {[15, 25, 50].map((minutes) => (
          <Button
            key={minutes}
            text={`${minutes}m`}
            variant="outline"
            onPress={() => setDuration(String(minutes))}
          />
        ))}
      </Flex>
      <TextField
        placeholderLabel="Minutes (15–180)"
        value={duration}
        onChange={setDuration}
        keyboardType="number-pad"
      />
      <Text type="H3">
        Protect {selected.length ? "selected apps" : "all apps"}
      </Text>
      <Button text="All apps" variant="ghost" onPress={() => setSelected([])} />
      <Flex gap="sm" wrap="wrap">
        {state.apps.items.map((app) => (
          <Button
            key={app.id}
            text={`${selected.includes(app.id) ? "✓ " : ""}${app.name}`}
            variant="outline"
            onPress={() => toggle(app.id)}
          />
        ))}
      </Flex>
      <Button
        text="Start Focus"
        disabled={Boolean(active)}
        onPress={() =>
          perform(async () => {
            const minutes = Number(duration);
            if (!Number.isInteger(minutes) || minutes < 15 || minutes > 180)
              throw new Error("Choose 15–180 minutes.");
            await updateFocus({
              ...state.focus,
              session: {
                id: Crypto.randomUUID(),
                appIDs: selected,
                start: new Date().toISOString(),
                minutes,
              },
            });
          })
        }
      />
      <Text type="H3">Recurring periods</Text>
      {state.focus.periods.map((period) => (
        <VolitionCard key={period.id}>
          <Text type="H3">{period.name}</Text>
          <Text>
            {period.isEnabled ? "Enabled" : "Paused"} · {period.weekdays.length}{" "}
            days
          </Text>
          <Button
            text="Edit period"
            variant="ghost"
            onPress={() => open(period)}
          />
          <Button
            text={period.isEnabled ? "Pause" : "Enable"}
            variant="ghost"
            onPress={() =>
              perform(() =>
                updateFocus({
                  ...state.focus,
                  periods: state.focus.periods.map((item) =>
                    item.id === period.id
                      ? { ...item, isEnabled: !item.isEnabled }
                      : item,
                  ),
                }),
              )
            }
          />
          <Button
            text="Delete period"
            variant="ghost"
            tone="danger"
            onPress={() =>
              perform(() =>
                updateFocus({
                  ...state.focus,
                  periods: state.focus.periods.filter(
                    (item) => item.id !== period.id,
                  ),
                }),
              )
            }
          />
        </VolitionCard>
      ))}
      <Button text="Add period" variant="outline" onPress={() => open()} />
      <Modal
        title="Focus period"
        isVisible={visible}
        onClose={() => setVisible(false)}
      >
        <Flex vertical gap="sm">
          <TextField
            placeholderLabel="Name"
            value={name}
            onChange={setName}
            maxLength={100}
          />
          <TextField
            placeholderLabel="Start (HH:mm)"
            value={start}
            onChange={setStart}
          />
          <TextField
            placeholderLabel="End (HH:mm)"
            value={end}
            onChange={setEnd}
          />
          <Text>
            Uses the apps selected above. No selection protects all apps.
          </Text>
          <Flex wrap="wrap" gap="sm">
            {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map(
              (day, index) => (
                <Button
                  key={day}
                  text={`${weekdays.includes(index + 1) ? "✓ " : ""}${day}`}
                  variant="outline"
                  onPress={() =>
                    setWeekdays((items) =>
                      items.includes(index + 1)
                        ? items.filter((item) => item !== index + 1)
                        : [...items, index + 1],
                    )
                  }
                />
              ),
            )}
          </Flex>
          <Button
            text="Save period"
            onPress={() =>
              perform(async () => {
                const startMinutes = parseTime(start),
                  endMinutes = parseTime(end);
                if (
                  !name.trim() ||
                  !weekdays.length ||
                  (endMinutes - startMinutes + 1440) % 1440 < 15
                )
                  throw new Error(
                    "Choose a name, weekdays, and a period of at least 15 minutes.",
                  );
                const period: FocusPeriod = {
                  id: editing ?? Crypto.randomUUID(),
                  name: name.trim(),
                  appIDs: selected,
                  weekdays,
                  startMinutes,
                  endMinutes,
                  isEnabled: true,
                };
                await updateFocus({
                  ...state.focus,
                  periods: [
                    ...state.focus.periods.filter(
                      (item) => item.id !== period.id,
                    ),
                    period,
                  ],
                });
                setVisible(false);
              })
            }
          />
        </Flex>
      </Modal>
    </Screen>
  );
}

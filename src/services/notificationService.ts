import * as Notifications from "expo-notifications";
import { VolitionScreenTime } from "../../modules/volition-screen-time";
// Native presentation owns grant-specific 60/30/10 identifiers and rechecks the
// durable grant after every await. JS never runs an independent expiry timer.
export async function requestNotifications(): Promise<boolean> {
  const result = await Notifications.requestPermissionsAsync();
  return result.granted;
}
export async function syncNotifications(): Promise<void> {
  await VolitionScreenTime.syncPresentation();
}

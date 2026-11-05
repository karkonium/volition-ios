import type {
  AuthorizationStatus,
  ScreenTimeBridge,
} from "../../../modules/volition-screen-time";

type AuthorizationBridge = Pick<
  ScreenTimeBridge,
  "requestAuthorization" | "getAuthorizationStatus"
>;

/** The system status, not the prompt's return value, determines whether setup may advance. */
export async function requestScreenTimeAuthorization(
  bridge: AuthorizationBridge,
): Promise<{ status: AuthorizationStatus; failed: boolean }> {
  let failed = false;
  try {
    await bridge.requestAuthorization();
  } catch {
    failed = true;
  }
  return { status: bridge.getAuthorizationStatus(), failed };
}

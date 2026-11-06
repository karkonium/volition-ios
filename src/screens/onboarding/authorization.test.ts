import { requestScreenTimeAuthorization } from "./authorization";

describe("Screen Time authorization", () => {
  it("advances only when a fresh status read confirms approval", async () => {
    const result = await requestScreenTimeAuthorization({
      requestAuthorization: async () => "approved",
      getAuthorizationStatus: () => "notDetermined",
    });
    expect(result).toEqual({ status: "notDetermined", failed: false });
  });

  it("keeps a dismissed prompt retryable", async () => {
    const result = await requestScreenTimeAuthorization({
      requestAuthorization: async () => "notDetermined",
      getAuthorizationStatus: () => "notDetermined",
    });
    expect(result).toEqual({ status: "notDetermined", failed: false });
  });

  it("uses the current status after failures and reports the failure", async () => {
    const result = await requestScreenTimeAuthorization({
      requestAuthorization: async () => {
        throw new Error("native details");
      },
      getAuthorizationStatus: () => "denied",
    });
    expect(result).toEqual({ status: "denied", failed: true });
  });
});

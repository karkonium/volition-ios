import {
  crashReportAction,
  isTelemetryScreen,
  telemetryPreferences,
} from "./telemetryPolicy";

describe("telemetry privacy policy", () => {
  it("defaults both collections off for existing and new users", () => {
    expect(telemetryPreferences(undefined, undefined, false)).toEqual({
      analytics: false,
      crashReports: false,
    });
  });
  it("always disables collection in preview", () => {
    expect(telemetryPreferences(true, true, true)).toEqual({
      analytics: false,
      crashReports: false,
    });
  });
  it("only permits fixed screen names", () => {
    expect(isTelemetryScreen("Chat")).toBe(true);
    expect(isTelemetryScreen("a user supplied app name")).toBe(false);
  });
});

describe("crash report consent", () => {
  it("sends only when reporting was enabled before this launch", () => {
    expect(crashReportAction(true, undefined)).toBe("send");
    expect(crashReportAction(true, true)).toBe("send");
    expect(crashReportAction(true, false)).toBe("delete");
    expect(crashReportAction(false, true)).toBe("delete");
    expect(crashReportAction(false, undefined)).toBe("delete");
  });
});

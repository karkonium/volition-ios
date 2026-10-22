# Single-app picker and naming guidance

Scope: Add/Edit App only; retain per-app intentions and enforcement behavior.
Use the public FamilyActivityPicker in a separate empty draft. Close immediately
on one individual app. Reject categories, websites and bulk selections with clear
guidance. Cancel preserves the existing app. Add a persistent App Name footer
asking users to match the selected app’s name, with SoundCloud as the example.

Red: unit tests for the shared selection boundary fail to compile before the
helper exists. Extend setup UI coverage for guidance, bulk rejection, automatic
close and edit cancellation. Then run focused tests, the full suite and inspect
iPhone/iPad screenshots. Xcode MCP is unavailable; use xcodebuild/XCUITest and
inspect exported screenshots. Real picker interactions require authorization on
a device; the UI harness uses synthetic selections through the same draft binding.
No commit unless requested. Work remains on fix/single-app-picker.

Focused verification passed: five Volition unit tests and the full setup/edit UI
flow on iPhone. Read the iPhone screenshots of the name footer and invalid bulk
selection. Signed iPhone build passed and CoreDevice confirmed the updated app
installed. The full iPad suite passed all 447 tests (433 unit + 14 UI). Read the iPad
screenshots too; the footer and picker guidance are visible in centered sheets.
The user confirmed the real iPhone picker closes automatically after selecting
one app and the App Name hint appears. The test harness also verifies the shared
draft/validation flow with synthetic tokens.

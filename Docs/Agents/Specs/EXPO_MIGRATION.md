# Expo application and native compatibility boundary

Volition starts at `App.tsx`. React Navigation owns the five tabs and the iPad
sidebar. Redux Persist stores profiles, chat, offers, local outcomes and coaching
history. `src/layout/VolitionThemeProvider.tsx` applies Ahhzo Elements 0.8.2 tokens.

`modules/volition-screen-time/ios/` owns the shipping Swift. `LegacyModels/`
retains the frozen V1–V5 schemas. `LegacyImport.swift` opens the original SwiftData
store and exports data once to Redux without deleting the original. Subsequent
launches reopen it to retain enforced legacy waits. API keys use Keychain;
Redux and technical diagnostics never store them.

`Shared/` under the module owns coordinated grant transactions, committed break
terms, Focus and shield writes. Native grant publication requires timer
registration, durable state and configured blocker readback. JavaScript performs
foreground, consent revision, offer identity and configuration checks; native
admission rechecks consent inside both publication transactions. Failed or stale
publication rolls back the exact grant and restores replacement-deal terms.

The five extension entry points live in `targets/`. They retain the original
bundle identifiers, App Group and legacy monitor callbacks. Their shared source
files link to the module. `Scripts/link-native-sources.py` maintains these links.
The report preset adapter in `plugins/with-volition-targets.js` preserves the
DeviceActivity Report extension missing from apple-targets 5.0's preset registry.

The superseded SwiftUI screens and launch shell have been removed.
`NativeCompatibility/` is a test-only host and compatibility logic for the
existing native domain suites; it does not ship in Expo. `OpenAppLock.xcodeproj`
exists only to run these suites. Its tiny host can seed a synthetic original-module
SwiftData store using `-seed-expo-migration` on an owned simulator.

## Verification

Run `npm ci`, `npm run typecheck`, `npm test`, and `npx expo prebuild --clean
--platform ios`. Build `ios/Volition.xcworkspace`, scheme `Volition`. The local
module keeps complete concurrency checking and Swift warnings as errors. SDK 57
and React Native 0.86 need the checked-in header corrections applied by
`Scripts/patch-expo-headers.cjs`: explicit nullability, a missing protocol import,
and private framework membership for internal headers. They do not disable
compiler diagnostics. Expo and React Native build from source with Xcode 27 scene
support. Upstream dependency warnings remain visible.

The compatibility command is `xcodebuild test -project OpenAppLock.xcodeproj
-scheme OpenAppLock -destination 'platform=iOS Simulator,id=<owned-UDID>'
-only-testing:OpenAppLockTests SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`.

`EXPO_PUBLIC_VOLITION_PREVIEW=1` enables an explicitly labeled development preview
with synthetic selections and model responses. It never calls FamilyControls or
OpenAI. Production builds cannot enable it. `ExpoMigrationUITests` is opt-in via
`VOLITION_EXPO_UI_TESTS=1` and exercises that preview, never real app access.

Real-device acceptance remains required for shields, picker authorization,
background/terminated expiry, notification delivery and Live Activities. A
successful unsigned build or preview is not evidence that iOS dismissed a shield.

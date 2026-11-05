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

The superseded SwiftUI screens, native project, signing/launch configuration,
compatibility harness and old native test folders have been removed at the user's
explicit request. Production native code is owned by the module and targets.
New regression coverage uses the Expo test setup.

## Verification

Run `npm ci`, `npm run typecheck`, `npm test`, and `npx expo prebuild --clean
--platform ios`. Build `ios/Volition.xcworkspace`, scheme `Volition`. The local
module keeps complete concurrency checking and Swift warnings as errors. SDK 57
and React Native 0.86 need the checked-in header corrections applied by
`Scripts/patch-expo-headers.cjs`: explicit nullability, a missing protocol import,
and private framework membership for internal headers. They do not disable
compiler diagnostics. Expo and React Native build from source with Xcode 27 scene
support. Upstream dependency warnings remain visible.

`EXPO_PUBLIC_VOLITION_PREVIEW=1` enables an explicitly labeled development preview
with synthetic selections and model responses. It never calls FamilyControls or
OpenAI. Production builds cannot enable it.

Real-device acceptance remains required for shields, picker authorization,
background/terminated expiry, notification delivery and Live Activities. A
successful unsigned build or preview is not evidence that iOS dismissed a shield.

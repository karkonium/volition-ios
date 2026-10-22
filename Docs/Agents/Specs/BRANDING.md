# Volition identity and cleanup

## Identity

A single gold V with precise flared terminals and three restrained sun rays on a
midnight navy field. Warm, professional and legible as a small iOS icon. Keep the
native blue interface tint; this change does not reskin the controls.

Production assets:

- `OpenAppLock/Assets.xcassets/VolitionLogo.imageset/volition-sunlit-v.png`: 1024px
  opaque square, used by the welcome screen via Image("VolitionLogo").
- `OpenAppLock/AppIcon.icon/Assets/volition-sunlit-v.png`: identical bitmap in the
  existing Icon Composer package. The icon name/target build settings stay AppIcon.
- `OpenAppLock/AppIcon.icon/icon.json`: one non-glass image layer. System icon masks
  supply the rounded shape; no rounded rectangle is baked into the bitmap.

Generated with the built-in imagegen tool, then resized to 1024px for iOS packaging.
The generated original is retained outside the repo; both production copies live
inside the project. No runtime downloads or new package dependencies.

## Final generation prompt

Use case: logo-brand. Create the final professional iOS app icon for Volition,
a thoughtful screen-time app about choosing how to spend your attention. One
single uppercase letter V, custom elegant contemporary typography: strong precise
tapered strokes, refined slightly flared terminals, striking and immediately
legible at small sizes. The V itself glows with warm golden sunlight, a few short
restrained sun rays radiate outward from its upper right stroke like a small rising
sun, tastefully integrated into the letter rather than a separate sun illustration.
Premium, calm, optimistic identity, minimal design with vector-clean edges, not a
generic wellness illustration. Center the large V optically within a perfect square
full-bleed deep midnight navy background. Golden amber to pale warm gold on the V
with a subtle polished luminous highlight, no lens flare or photorealistic
reflections. The V occupies roughly 60 percent of canvas width and height; rays
remain within an ample safe margin. No rounded square outline or corners drawn
into image: iOS applies its own mask. No extra letters, no wordmark, no caption,
no watermarks, no device mockup. Only one finalized icon, not a sheet of options.
Square high-resolution production asset.

## Conservative cleanup boundary

Removed unreachable Home/Rules/App Lists screens, their UI environment wiring,
notification settings/timer-test views, old phone/cross logo assets, invalid legacy
navigation destinations and 155 unreferenced symbolic copy keys/catalog entries.
Completed agent plans and obsolete feature journals were consolidated into the
current conversation, operations, compatibility and branding specs. Human README,
license/project metadata, all schemas/migrations, services/extensions and domain
regression tests are preserved. Removed material is recoverable from Git history.

Red/green tests cover missing brand assets and rejection of retired destinations;
existing tests cover data migration, grants, waits, expiry, settings and onboarding.
Inspect the welcome screen on iPhone/iPad and verify actual-device icon appearance.
Do not remove compatibility enforcement as another cosmetic cleanup.

## Validation

The full iPhone suite passed 449 tests (435 unit + 14 UI); seven affected iPad UI
tests also passed. Read the welcome screenshots on both devices. The signed
generic iPhone build passed, and its bundled personal configuration matches the
local ignored file without printing it. No schemas, services, shared stores,
enforcement implementations or extension targets changed in this cleanup.

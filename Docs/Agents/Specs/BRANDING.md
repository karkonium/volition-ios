# Volition identity and cleanup

## Identity

The user-supplied white V on an opaque black field, with broad clean strokes and
softened inner shoulders/bottom. Preserve the supplied artwork and proportions.
Keep the native blue interface tint; this does not reskin the controls.

Production assets:

- `OpenAppLock/Assets.xcassets/VolitionLogo.imageset/volition-sunlit-v.png`: 1024px
  opaque square, used by the welcome screen via Image("VolitionLogo").
- `OpenAppLock/AppIcon.icon/Assets/volition-sunlit-v.png`: identical bitmap in the
  existing Icon Composer package. The icon name/target build settings stay AppIcon.
- `OpenAppLock/AppIcon.icon/icon.json`: one non-glass image layer. System icon masks
  supply the rounded shape; no rounded rectangle is baked into the bitmap.

The user supplied the current square image on 2026-10-28. It was resized to
1024px with `sips` for packaging and copied identically into both production
locations above. No regeneration, recoloring or design changes. The legacy
`volition-sunlit-v.png` filenames remain stable resource references; the icon's
layer display name is now Volition V. No generation prompt applies to this asset.

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

Both production bitmaps are identical opaque 1024px squares. The white-V welcome
screen was verified with an iPhone UI test and its exported screenshot inspected.
493 domain tests (including branding resource loading) and the signed generic iOS
build pass. The artifact includes all five extensions; the local ignored config
remains bundled without exposing its contents. Physical-device icon appearance
has not been verified or installed in this revision.

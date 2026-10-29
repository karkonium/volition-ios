# Volition identity

## Identity

The owner selected concept C: an open charcoal ring with a separate blue segment
on an off-white field. The flat, simple silhouette matches the restrained native
interface. Keep the native blue control tint.

Production assets:

- `OpenAppLock/Assets.xcassets/VolitionLogo.imageset/volition-open-circle.png`:
  1024px opaque square, used by the welcome screen through `Image("VolitionLogo")`.
- `OpenAppLock/AppIcon.icon/Assets/volition-open-circle.png`: identical bitmap
  inside the existing Icon Composer package. The icon name remains `AppIcon`.
- `OpenAppLock/AppIcon.icon/icon.json`: one non-glass image layer, no added shadow.
  The system applies its icon mask; no rounded outer corners are baked in.

The selected built-in imagegen output was downsampled for packaging without
changing the design. Both production copies live in the project. No runtime
asset download or new dependencies. The original is retained with the four
concepts in the chat workspace, outside the app source.

## Selected generation prompt

Use case: logo-brand. Asset type: square iOS app icon concept for Volition, a calm
adult voluntary self-control app where a conversation precedes access. Match a
quiet native interface with fine outlined cards, black/white typography and a
restrained system-blue accent. Flat vector-like graphic, exceptionally clean edges,
strong silhouette legible at 40 pixels, intentional optical alignment. Full-bleed
opaque square canvas, no inset rounded-square frame, no device mockup, no text
labels, no watermark. No gold, serif lettering, sparkles, gloss, bevel, lighting
effects, 3D, gradients, texture, drop shadows, or decorative detail. One icon only,
centered with generous but not excessive breathing room.

Direction C — Open circle. Off-white background #F5F3EE. One bold charcoal circular
arc with rounded ends, deliberately open at the upper right, resembling an
intentional pause in a continuous habit. A small muted blue rounded lozenge sits
in the opening and follows the arc’s angle while remaining clearly separated by
negative space from both ends. The circle occupies about 55% of the square. A
quiet distinctive emblem of choice and space, with an elegant balanced silhouette.
Not a power button or letter C; make it feel like a considered open ring.

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

The simulator build, bundled-logo check and onboarding UI check passed after this
replacement (two tests). The welcome render was inspected. Simulator validation does not establish actual
home-screen icon appearance on a physical device. No schemas, enforcement logic,
services or extension targets change with this asset replacement.

"""Production Swift lives in modules/ and targets/; legacy tests reuse file links."""
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'modules/volition-screen-time/ios'
COMPATIBILITY = ROOT / 'NativeCompatibility'


def link(source: Path, destination: Path) -> None:
    if source.is_dir():
        destination.mkdir(parents=True, exist_ok=True)
        for child in source.iterdir():
            link(child, destination / child.name)
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    relative = os.path.relpath(source, destination.parent)
    if destination.is_symlink():
        if os.readlink(destination) == relative:
            return
        destination.unlink()
    if not destination.exists():
        destination.symlink_to(relative)


for directory in ['Shared', 'ActivityShared']:
    link(NATIVE / directory, COMPATIBILITY / directory)
link(NATIVE / 'LegacyModels', COMPATIBILITY / 'App/Models')
for source in NATIVE.glob('Conversation*.swift'):
    link(source, COMPATIBILITY / 'App/Services/Conversation' / source.name)
link(NATIVE / 'VolitionApps.swift', COMPATIBILITY / 'App/Services/Conversation/VolitionApps.swift')
link(NATIVE / 'RuleScheduler.swift', COMPATIBILITY / 'App/Services/RuleScheduler.swift')

for directory, old_name in [
    ('shield-config', 'OpenAppLockShieldConfig'),
    ('shield-action', 'OpenAppLockShieldAction'),
    ('activity-monitor', 'OpenAppLockMonitor'),
    ('activity-report', 'OpenAppLockReport'),
    ('live-activity', 'VolitionLiveActivity'),
]:
    target = ROOT / 'targets' / directory
    link(NATIVE / 'Shared', target / 'Shared')
    link(NATIVE / 'ActivityShared', target / 'ActivityShared')
    for source in target.glob('*.swift'):
        if source.name != 'RuleScheduler.swift':
            link(source, COMPATIBILITY / 'Extensions' / old_name / source.name)

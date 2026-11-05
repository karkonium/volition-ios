"""Link production shared Swift into the five Expo extension targets."""
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'modules/volition-screen-time/ios'


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


for directory in ['shield-config', 'shield-action', 'activity-monitor', 'activity-report', 'live-activity']:
    target = ROOT / 'targets' / directory
    link(NATIVE / 'Shared', target / 'Shared')
    link(NATIVE / 'ActivityShared', target / 'ActivityShared')

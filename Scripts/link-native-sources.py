"""Keep one authoritative copy of legacy enforcement and extension sources."""
from pathlib import Path
import os,json
root=Path(__file__).resolve().parent.parent

def link(source,destination):
    source=root/source; destination=root/destination
    destination.parent.mkdir(parents=True,exist_ok=True)
    if source.is_dir():
        if destination.is_symlink(): destination.unlink()
        destination.mkdir(exist_ok=True)
        for child in source.iterdir(): link(child.relative_to(root), (destination/child.name).relative_to(root))
        return
    if not destination.exists() and not destination.is_symlink(): destination.symlink_to(os.path.relpath(source,destination.parent))

native='modules/volition-screen-time/ios'
link(Path('Shared'),Path(native)/'Shared')
link(Path('ActivityShared'),Path(native)/'ActivityShared')
for name in ['ConversationDiagnostics','ConversationEnvironment','ConversationSessionPresentation']:
    link(Path('OpenAppLock/Services/Conversation')/(name+'.swift'),Path(native)/(name+'.swift'))
link(Path('OpenAppLock/Services/RuleScheduler.swift'),Path(native)/'RuleScheduler.swift')
targets=[('shield-config','shield-config','OpenAppLockShieldConfig','ShieldConfig','ShieldConfigurationExtension.swift'),('shield-action','shield-action','OpenAppLockShieldAction','ShieldAction','ShieldActionExtension.swift'),('activity-monitor','device-activity-monitor','OpenAppLockMonitor','Monitor','DeviceActivityMonitorExtension.swift'),('activity-report','device-activity-report','OpenAppLockReport','Report',None),('live-activity','widget','VolitionLiveActivity','LiveActivity','VolitionUnlockWidget.swift')]
for directory,kind,original,suffix,filename in targets:
    dest=Path('targets')/directory
    (root/dest).mkdir(parents=True,exist_ok=True)
    config={'type':kind,'name':original,'bundleIdentifier':'com.a5karki.volition.'+suffix,'deploymentTarget':'18.0','frameworks':['FamilyControls','ManagedSettings','ManagedSettingsUI','DeviceActivity','SwiftUI','ActivityKit','UserNotifications'],'entitlements':{'com.apple.developer.family-controls':True,'com.apple.security.application-groups':['group.com.a5karki.volition']}}
    (root/dest/'expo-target.config.js').write_text('module.exports = '+json.dumps(config,indent=2)+';\n')
    if filename:link(Path(original)/filename,dest/filename)
    else:
        for source in (root/original).glob('*.swift'):link(source.relative_to(root),dest/source.name)
    link(Path('Shared'),dest/'Shared')
    link(Path('ActivityShared'),dest/'ActivityShared')
    link(Path('OpenAppLock/Services/RuleScheduler.swift'),dest/'RuleScheduler.swift')

for source in (root/"OpenAppLockMonitor").glob("*.swift"):
    link(source.relative_to(root),Path("targets/activity-monitor")/source.name)
link(Path('OpenAppLock/Models'),Path(native)/'LegacyModels')
for name in ['ConversationHistory','ConversationActivityLog','ConversationReflection','ConversationDecision','ConversationUsageProfile','ConversationRemovalAttempt','VolitionApps']:
    link(Path('OpenAppLock/Services/Conversation')/(name+'.swift'),Path(native)/(name+'.swift'))

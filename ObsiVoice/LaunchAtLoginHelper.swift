import Foundation
import ServiceManagement

class LaunchAtLoginHelper {
    static let shared = LaunchAtLoginHelper()
    
    private init() {}
    
    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                // For older macOS versions, check using the legacy method
                return legacyIsEnabled()
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        if SMAppService.mainApp.status == .enabled {
                            // Already enabled
                            return
                        }
                        try SMAppService.mainApp.register()
                    } else {
                        if SMAppService.mainApp.status == .notRegistered {
                            // Already disabled
                            return
                        }
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to update launch at login: \(error)")
                }
            } else {
                // For older macOS versions, use the legacy method
                legacySetEnabled(newValue)
            }
        }
    }
    
    // Legacy methods for macOS < 13.0
    private func legacyIsEnabled() -> Bool {
        
        // Check if app is in login items
        let script = """
        tell application "System Events"
            get the name of every login item
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            if let items = output.stringValue {
                if items.contains("ObsiVoice") || items.contains("VoiceLogger") {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func legacySetEnabled(_ enabled: Bool) {
        guard let bundlePath = Bundle.main.bundlePath else { return }
        let appName = (bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        if enabled {
            // Add to login items
            let script = """
            tell application "System Events"
                make login item at end with properties {path:"\(bundlePath)", hidden:false}
            end tell
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("Failed to add login item: \(error)")
                }
            }
        } else {
            // Remove from login items
            let script = """
            tell application "System Events"
                delete login item "\(appName)"
            end tell
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("Failed to remove login item: \(error)")
                }
            }
        }
    }
}
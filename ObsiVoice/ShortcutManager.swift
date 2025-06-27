import Cocoa
import Carbon

struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifierFlags: UInt
    
    var displayString: String {
        var parts: [String] = []
        
        if modifierFlags & NSEvent.ModifierFlags.control.rawValue != 0 {
            parts.append("⌃")
        }
        if modifierFlags & NSEvent.ModifierFlags.option.rawValue != 0 {
            parts.append("⌥")
        }
        if modifierFlags & NSEvent.ModifierFlags.shift.rawValue != 0 {
            parts.append("⇧")
        }
        if modifierFlags & NSEvent.ModifierFlags.command.rawValue != 0 {
            parts.append("⌘")
        }
        
        if let keyString = KeyboardShortcut.keyCodeToString(keyCode) {
            parts.append(keyString)
        }
        
        return parts.joined()
    }
    
    static func keyCodeToString(_ keyCode: UInt16) -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        
        guard let data = layoutData else { return nil }
        
        let layout = unsafeBitCast(data, to: CFData.self)
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)
        
        var keysDown: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var realLength: Int = 0
        
        UCKeyTranslate(keyboardLayout,
                      keyCode,
                      UInt16(kUCKeyActionDisplay),
                      0,
                      UInt32(LMGetKbdType()),
                      0,
                      &keysDown,
                      chars.count,
                      &realLength,
                      &chars)
        
        return String(utf16CodeUnits: chars, count: realLength).uppercased()
    }
}

class ShortcutManager {
    static let shared = ShortcutManager()
    
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var registeredShortcut: KeyboardShortcut?
    private var action: (() -> Void)?
    
    private let shortcutKey = "RecordingShortcut"
    
    private init() {
        loadShortcut()
    }
    
    var currentShortcut: KeyboardShortcut? {
        return registeredShortcut
    }
    
    func saveShortcut(_ shortcut: KeyboardShortcut?) {
        if let shortcut = shortcut, shortcut.keyCode != 0 {
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: shortcutKey)
                registeredShortcut = shortcut
                
                // Re-register with new shortcut
                if action != nil {
                    stopMonitoring()
                    startMonitoring()
                }
                
                print("Saved shortcut: \(shortcut.displayString)")
            }
        } else {
            // Clear shortcut
            UserDefaults.standard.removeObject(forKey: shortcutKey)
            registeredShortcut = nil
            stopMonitoring()
            print("Cleared shortcut")
        }
    }
    
    func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: shortcutKey),
           let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            registeredShortcut = shortcut
        }
    }
    
    func register(action: @escaping () -> Void) {
        self.action = action
        loadShortcut() // Ensure shortcut is loaded
        startMonitoring()
    }
    
    func unregister() {
        stopMonitoring()
        self.action = nil
    }
    
    private func startMonitoring() {
        guard let shortcut = registeredShortcut else { 
            print("No shortcut registered")
            return 
        }
        
        print("Starting monitoring for shortcut: \(shortcut.displayString)")
        
        // Define the event handler
        let eventHandler: (NSEvent) -> NSEvent? = { [weak self] event in
            let eventModifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            
            if event.keyCode == shortcut.keyCode && eventModifiers == shortcut.modifierFlags {
                print("Shortcut triggered!")
                DispatchQueue.main.async {
                    self?.action?()
                }
                return nil // Consume the event
            }
            return event
        }
        
        // Local monitor for when app has focus
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return eventHandler(event)
        }
        
        // Global monitor for when other apps have focus
        // Request accessibility permissions if needed
        let options = NSDictionary(object: kCFBooleanTrue!, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString)
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                _ = eventHandler(event)
            }
            print("Global event monitor installed successfully")
        } else {
            print("Accessibility permissions not granted - global shortcuts won't work")
        }
        
        if localEventMonitor != nil {
            print("Local event monitor installed successfully")
        }
    }
    
    private func stopMonitoring() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}
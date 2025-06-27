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
        // Common key codes mapping
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
            21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'",
            40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "␣",
            50: "`", 51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16",
            117: "⌦", 118: "F4", 119: "⇞", 120: "F2", 121: "⇟", 122: "F1", 123: "←", 124: "→",
            125: "↓", 126: "↑"
        ]
        
        if let key = keyMap[keyCode] {
            return key
        }
        
        // Fallback to system method
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        
        guard let data = layoutData else { return "?" }
        
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
        
        let result = String(utf16CodeUnits: chars, count: realLength)
        return result.isEmpty ? "?" : result.uppercased()
    }
}

class ShortcutManager {
    static let shared = ShortcutManager()
    
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var registeredShortcut: KeyboardShortcut?
    private var keyDownAction: (() -> Void)?
    private var keyUpAction: (() -> Void)?
    private var toggleAction: (() -> Void)?
    
    private let shortcutKey = "RecordingShortcut"
    
    // State tracking
    private var isKeyPressed = false
    private var keyPressTime: Date?
    private let longPressThreshold: TimeInterval = 0.3 // 300ms to distinguish between tap and hold
    private var longPressTimer: Timer?
    private var isRecordingFromHold = false
    
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
                if keyDownAction != nil || keyUpAction != nil {
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
            print("Loaded shortcut: \(shortcut.displayString)")
        } else {
            print("No saved shortcut found")
        }
    }
    
    func register(keyDown: @escaping () -> Void, keyUp: @escaping () -> Void, toggle: @escaping () -> Void) {
        self.keyDownAction = keyDown
        self.keyUpAction = keyUp
        self.toggleAction = toggle
        loadShortcut() // Ensure shortcut is loaded
        startMonitoring()
    }
    
    func unregister() {
        stopMonitoring()
        self.keyDownAction = nil
        self.keyUpAction = nil
        self.toggleAction = nil
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    private func startMonitoring() {
        guard let shortcut = registeredShortcut else { 
            print("No shortcut registered")
            return 
        }
        
        print("Starting monitoring for shortcut: \(shortcut.displayString)")
        
        // Define the keyDown event handler
        let keyDownHandler: (NSEvent) -> NSEvent? = { [weak self] event in
            guard let self = self else { return event }
            
            let eventModifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            
            if event.keyCode == shortcut.keyCode && eventModifiers == shortcut.modifierFlags {
                // Prevent key repeat
                if !self.isKeyPressed {
                    self.isKeyPressed = true
                    self.keyPressTime = Date()
                    self.isRecordingFromHold = false
                    
                    print("Key down detected")
                    
                    // Start a timer to detect long press
                    self.longPressTimer?.invalidate()
                    self.longPressTimer = Timer.scheduledTimer(withTimeInterval: self.longPressThreshold, repeats: false) { _ in
                        DispatchQueue.main.async {
                            print("Long press detected - starting hold-to-record")
                            self.isRecordingFromHold = true
                            self.keyDownAction?()
                        }
                    }
                }
                return nil // Consume the event
            }
            return event
        }
        
        // Define the keyUp event handler
        let keyUpHandler: (NSEvent) -> NSEvent? = { [weak self] event in
            guard let self = self else { return event }
            
            let eventModifiers = event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            
            if event.keyCode == shortcut.keyCode && eventModifiers == shortcut.modifierFlags {
                if self.isKeyPressed {
                    self.isKeyPressed = false
                    let pressDuration = Date().timeIntervalSince(self.keyPressTime ?? Date())
                    
                    print("Key up detected, duration: \(pressDuration)s")
                    
                    // Cancel the long press timer
                    self.longPressTimer?.invalidate()
                    self.longPressTimer = nil
                    
                    if self.isRecordingFromHold {
                        // Was holding - stop recording
                        print("Stopping hold-to-record")
                        DispatchQueue.main.async {
                            self.keyUpAction?()
                        }
                    } else if pressDuration < self.longPressThreshold {
                        // Short tap - toggle recording
                        print("Short tap detected - toggling recording")
                        DispatchQueue.main.async {
                            self.toggleAction?()
                        }
                    }
                }
                return nil // Consume the event
            }
            return event
        }
        
        // Local monitors for when app has focus
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return keyDownHandler(event)
        }
        
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            return keyUpHandler(event)
        }
        
        // Global monitors for when other apps have focus
        // Check accessibility permissions without prompting first
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            print("⚠️ Accessibility permissions not granted")
            
            // Try to use the API first to ensure we appear in the list
            _ = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
            
            // Show alert to user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "ObsiVoice needs accessibility permissions to use global keyboard shortcuts.\n\nObsiVoice should now appear in the Accessibility list. Please enable it and restart the app."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Later")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open System Preferences directly to Accessibility
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    } else {
                        // Fallback: Open System Preferences app
                        NSWorkspace.shared.launchApplication("System Preferences")
                    }
                }
            }
            
            // Also prompt system dialog
            let options = NSDictionary(object: kCFBooleanTrue!, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString)
            _ = AXIsProcessTrustedWithOptions(options)
        }
        
        // Install global monitors if we have accessibility permissions
        if trusted {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                _ = keyDownHandler(event)
            }
            
            globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { event in
                _ = keyUpHandler(event)
            }
            
            if globalEventMonitor != nil && globalKeyUpMonitor != nil {
                print("✓ Global event monitors installed successfully")
            } else {
                print("✗ Failed to install global event monitors (unexpected)")
            }
        } else {
            print("✗ Cannot install global event monitor without accessibility permissions")
            
            // Try again in a few seconds (user might grant permission)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if AXIsProcessTrusted() {
                    print("Accessibility permissions now granted, restarting monitoring...")
                    self?.stopMonitoring()
                    self?.startMonitoring()
                }
            }
        }
        
        if localEventMonitor != nil && localKeyUpMonitor != nil {
            print("Local event monitors installed successfully")
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
        
        if let monitor = globalKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyUpMonitor = nil
        }
        
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyUpMonitor = nil
        }
        
        longPressTimer?.invalidate()
        longPressTimer = nil
        isKeyPressed = false
        isRecordingFromHold = false
    }
}
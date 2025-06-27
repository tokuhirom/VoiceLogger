import Cocoa
import SwiftUI
import Speech

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private var settingsWindow: NSWindow?
    private var stopRecordingTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app appears in accessibility list immediately
        ensureInAccessibilityList()
        
        setupMenuBar()
        setupShortcuts()
    }
    
    private func ensureInAccessibilityList() {
        // Use multiple methods to ensure we appear in the accessibility list
        
        // Method 1: Try to create and immediately release a CGEvent tap
        if let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, _, _ in return nil },
            userInfo: nil
        ) {
            CFMachPortInvalidate(eventTap)
        }
        
        // Method 2: Create a temporary global event monitor
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { _ in }) {
            NSEvent.removeMonitor(monitor)
        }
        
        // Method 3: Check trusted status with prompt
        let options = NSDictionary(object: kCFBooleanFalse!, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString)
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Re-check accessibility permissions when app becomes active
        if AXIsProcessTrusted() {
            registerShortcuts()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ShortcutManager.shared.unregister()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "ObsiVoice")
            button.action = #selector(togglePopover)
        }
        
        setupMenu()
    }
    
    private func setupShortcuts() {
        print("Setting up shortcuts...")
        
        // Request accessibility permissions on first launch to ensure we appear in the list
        ensureAccessibilityPermissions()
        
        registerShortcuts()
    }
    
    private func registerShortcuts() {
        ShortcutManager.shared.unregister()
        ShortcutManager.shared.register(
            keyDown: { [weak self] in
                print("Key down action in AppDelegate - starting hold-to-record")
                DispatchQueue.main.async {
                    self?.startRecording()
                }
            },
            keyUp: { [weak self] in
                print("Key up action in AppDelegate - stopping hold-to-record after delay")
                DispatchQueue.main.async {
                    self?.scheduleStopRecording()
                }
            },
            toggle: { [weak self] in
                print("Toggle action in AppDelegate")
                DispatchQueue.main.async {
                    self?.toggleRecording()
                }
            }
        )
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            print("Toggle: stopping recording")
            stopRecordingAndTranscribe()
        } else {
            print("Toggle: starting recording")
            startRecording()
        }
    }
    
    private func scheduleStopRecording() {
        // Cancel any existing timer
        stopRecordingTimer?.invalidate()
        
        // Update icon to show we're in the delay period
        updateStatusItemForProcessing()
        
        // Schedule stop after 1 second
        stopRecordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.stopRecordingAndTranscribe()
            self?.stopRecordingTimer = nil
        }
    }
    
    private func ensureAccessibilityPermissions() {
        // Check if this is the first launch
        let hasRequestedPermissionKey = "HasRequestedAccessibilityPermission"
        let hasRequested = UserDefaults.standard.bool(forKey: hasRequestedPermissionKey)
        
        if !hasRequested {
            // First, ensure we're in the list
            ensureInAccessibilityList()
            
            // Then check if we're trusted
            let trusted = AXIsProcessTrusted()
            
            if !trusted {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Enable Keyboard Shortcuts"
                    alert.informativeText = "ObsiVoice uses global keyboard shortcuts to start recording from any app.\n\nPlease:\n1. Click 'Open System Preferences'\n2. Find ObsiVoice in the list\n3. Check the box next to ObsiVoice\n4. Restart ObsiVoice"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Open System Preferences")
                    alert.addButton(withTitle: "Skip")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        // Open System Preferences
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            
            UserDefaults.standard.set(true, forKey: hasRequestedPermissionKey)
        }
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        let recordItem = NSMenuItem(title: "Record Voice Note", action: #selector(startRecording), keyEquivalent: "")
        if let shortcut = ShortcutManager.shared.currentShortcut {
            recordItem.keyEquivalent = ""
            if AXIsProcessTrusted() {
                recordItem.title = "Record Voice Note (\(shortcut.displayString))"
            } else {
                recordItem.title = "Record Voice Note (\(shortcut.displayString) - ⚠️ No Permission)"
            }
        }
        menu.addItem(recordItem)
        menu.addItem(NSMenuItem.separator())
        
        // Microphone selection submenu
        let microphoneItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        let microphoneSubmenu = NSMenu()
        microphoneItem.submenu = microphoneSubmenu
        microphoneItem.tag = 100 // Tag to identify this menu item
        menu.addItem(microphoneItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Obsidian settings submenu
        let obsidianItem = NSMenuItem(title: "Obsidian Settings", action: nil, keyEquivalent: "")
        let obsidianSubmenu = NSMenu()
        
        let vaultItem = NSMenuItem(title: "Vault: \(ObsidianManager.shared.vaultName.isEmpty ? "Not configured" : ObsidianManager.shared.vaultName)", action: nil, keyEquivalent: "")
        vaultItem.isEnabled = false
        obsidianSubmenu.addItem(vaultItem)
        
        obsidianSubmenu.addItem(NSMenuItem(title: "Set Vault Name...", action: #selector(setVaultName), keyEquivalent: ""))
        obsidianSubmenu.addItem(NSMenuItem(title: "Test Connection", action: #selector(testObsidianConnection), keyEquivalent: ""))
        
        obsidianItem.submenu = obsidianSubmenu
        menu.addItem(obsidianItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ObsiVoice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func updateMicrophoneMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        
        audioRecorder.updateAvailableDevices()
        
        for device in audioRecorder.availableDevices {
            let item = NSMenuItem(title: device.name, action: #selector(selectMicrophone(_:)), keyEquivalent: "")
            item.representedObject = device
            item.target = self
            
            if device == audioRecorder.selectedDevice {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        if audioRecorder.availableDevices.isEmpty {
            let item = NSMenuItem(title: "No microphones available", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }
    
    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioRecorder.AudioDevice else { return }
        
        audioRecorder.selectDevice(device)
        
        // Update checkmarks
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item.representedObject as? AudioRecorder.AudioDevice) == device ? .on : .off
            }
        }
    }
    
    @objc private func togglePopover() {
        // This will be used later for popover functionality
    }
    
    @objc func startRecording() {
        if audioRecorder.isRecording {
            stopRecordingAndTranscribe()
        } else {
            if let request = audioRecorder.startRecording() {
                updateStatusItemForRecording(true)
                
                speechRecognizer.startTranscription(
                    with: request,
                    completion: { [weak self] finalText, error in
                        DispatchQueue.main.async {
                            if let text = finalText, !text.isEmpty {
                                // Final text is handled when recording stops
                                print("Final transcription received: \(text)")
                            } else if let error = error {
                                let micName = self?.audioRecorder.getCurrentMicrophoneName() ?? "Unknown"
                                self?.showAlert(title: "Transcription Error", 
                                              message: "\(error.localizedDescription)\n\nCurrent microphone: \(micName)")
                            } else {
                                // No speech detected
                                let micName = self?.audioRecorder.getCurrentMicrophoneName() ?? "Unknown"
                                self?.showAlert(title: "No Speech Detected", 
                                              message: "No speech was detected in the recording.\n\nCurrent microphone: \(micName)")
                            }
                        }
                    },
                    onSegment: { [weak self] segmentText in
                        DispatchQueue.main.async {
                            print("Segment detected: \(segmentText)")
                            self?.handleTranscribedText(segmentText)
                        }
                    }
                )
            } else {
                let micName = audioRecorder.getCurrentMicrophoneName()
                showAlert(title: "Recording Error", 
                         message: "Failed to start recording. Please check microphone permissions.\n\nCurrent microphone: \(micName)")
            }
        }
    }
    
    private func stopRecordingAndTranscribe() {
        // Cancel any pending stop timer
        stopRecordingTimer?.invalidate()
        stopRecordingTimer = nil
        
        // Don't cancel the speech recognition task immediately
        // Let the audio recorder handle the proper shutdown sequence
        audioRecorder.stopRecording()
        updateStatusItemForRecording(false)
        
        // Speech recognition will complete on its own when audio ends
    }
    
    private func updateStatusItemForRecording(_ isRecording: Bool) {
        if let button = statusItem.button {
            let imageName = isRecording ? "mic.circle.fill" : "mic.fill"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "ObsiVoice")
        }
    }
    
    private func updateStatusItemForProcessing() {
        if let button = statusItem.button {
            // Use a different icon to show we're processing/waiting
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "ObsiVoice Processing")
        }
    }
    
    private func handleTranscribedText(_ text: String) {
        // Send to Obsidian via Advanced URI
        ObsidianManager.shared.appendToDaily(text: text)
        showNotification(title: "Voice Note Transcribed", subtitle: text)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private func showNotification(title: String, subtitle: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.subtitle = subtitle
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.title = "ObsiVoice Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func setVaultName() {
        let alert = NSAlert()
        alert.messageText = "Set Obsidian Vault Name"
        alert.informativeText = "Enter the name of your Obsidian vault:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = ObsidianManager.shared.vaultName
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            ObsidianManager.shared.vaultName = textField.stringValue
            // Refresh menu to show new vault name
            setupMenu()
        }
    }
    
    @objc private func testObsidianConnection() {
        ObsidianManager.shared.testConnection { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showAlert(title: "Success", message: "Successfully connected to Obsidian vault!")
                } else {
                    self?.showAlert(title: "Connection Failed", message: error ?? "Unknown error")
                }
            }
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Update microphone submenu when main menu opens
        if let microphoneItem = menu.item(withTag: 100),
           let microphoneSubmenu = microphoneItem.submenu {
            updateMicrophoneMenu(microphoneSubmenu)
        }
    }
}
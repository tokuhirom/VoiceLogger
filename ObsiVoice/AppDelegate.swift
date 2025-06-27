import Cocoa
import SwiftUI
import Speech

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "ObsiVoice")
            button.action = #selector(togglePopover)
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        menu.addItem(NSMenuItem(title: "Record Voice Note", action: #selector(startRecording), keyEquivalent: "r"))
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
    
    @objc private func startRecording() {
        if audioRecorder.isRecording {
            stopRecordingAndTranscribe()
        } else {
            if let request = audioRecorder.startRecording() {
                updateStatusItemForRecording(true)
                
                speechRecognizer.startTranscription(with: request) { [weak self] finalText, error in
                    DispatchQueue.main.async {
                        if let text = finalText, !text.isEmpty {
                            self?.handleTranscribedText(text)
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
                }
            } else {
                let micName = audioRecorder.getCurrentMicrophoneName()
                showAlert(title: "Recording Error", 
                         message: "Failed to start recording. Please check microphone permissions.\n\nCurrent microphone: \(micName)")
            }
        }
    }
    
    private func stopRecordingAndTranscribe() {
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
        print("Opening settings...")
        // TODO: Implement settings window
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
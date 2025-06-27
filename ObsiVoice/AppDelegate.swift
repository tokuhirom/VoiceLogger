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
        audioRecorder.stopRecording()
        speechRecognizer.stopTranscription()
        updateStatusItemForRecording(false)
    }
    
    private func updateStatusItemForRecording(_ isRecording: Bool) {
        if let button = statusItem.button {
            let imageName = isRecording ? "mic.circle.fill" : "mic.fill"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "ObsiVoice")
        }
    }
    
    private func handleTranscribedText(_ text: String) {
        print("Transcribed text: \(text)")
        // TODO: Send to Obsidian via Advanced URI
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
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Update microphone submenu when main menu opens
        if let microphoneItem = menu.item(withTag: 100),
           let microphoneSubmenu = microphoneItem.submenu {
            updateMicrophoneMenu(microphoneSubmenu)
        }
    }
}
import SwiftUI

struct SettingsView: View {
    @State private var filePathTemplate = FileManager.shared.filePathTemplate
    @State private var noteTemplate = FileManager.shared.noteTemplate
    @State private var recordingShortcut = ShortcutManager.shared.currentShortcut
    @State private var showingFileTest = false
    @State private var fileTestResult: (success: Bool, message: String)?
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("ObsiVoice Settings")
                .font(.largeTitle)
                .padding(.top)
            
            // Shortcut Settings
            GroupBox(label: Label("Recording Shortcut", systemImage: "keyboard")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Set a global keyboard shortcut to start/stop recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ShortcutRecorderView(shortcut: $recordingShortcut)
                            .frame(width: 200, height: 30)
                            .onChange(of: recordingShortcut) { newShortcut in
                                if let shortcut = newShortcut {
                                    // Check accessibility permissions when setting shortcut
                                    if !AXIsProcessTrusted() {
                                        let alert = NSAlert()
                                        alert.messageText = "Accessibility Permission Required"
                                        alert.informativeText = "Global keyboard shortcuts require accessibility permissions.\n\nWould you like to grant permission now?"
                                        alert.alertStyle = .informational
                                        alert.addButton(withTitle: "Grant Permission")
                                        alert.addButton(withTitle: "Continue Anyway")
                                        
                                        if alert.runModal() == .alertFirstButtonReturn {
                                            openAccessibilityPreferences()
                                        }
                                    }
                                    ShortcutManager.shared.saveShortcut(shortcut)
                                }
                            }
                        
                        if recordingShortcut != nil {
                            Button("Clear") {
                                recordingShortcut = nil
                                ShortcutManager.shared.saveShortcut(nil)
                            }
                        }
                    }
                    
                    // Accessibility permission status
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: AXIsProcessTrusted() ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(AXIsProcessTrusted() ? .green : .red)
                            Text(AXIsProcessTrusted() ? "Accessibility permissions granted" : "Accessibility permissions required for global shortcuts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !AXIsProcessTrusted() {
                            Button("Open System Preferences") {
                                openAccessibilityPreferences()
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.top, 5)
                }
                .padding()
            }
            
            // File Settings
            GroupBox(label: Label("File Settings", systemImage: "folder")) {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("File Path Template")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("~/Documents/VoiceLogger/%Y%m/%Y-%m-%d.md", text: $filePathTemplate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("Placeholders: %Y (year), %m (month), %d (day), %H (hour), %M (minute), %S (second)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Note Template")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("- {time} {text}", text: $noteTemplate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("Available placeholders: {time}, {text}")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Button("Test File Access") {
                            testFileAccess()
                        }
                        
                        if let result = fileTestResult {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                            Text(result.message)
                                .font(.caption)
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Save and Cancel buttons
            HStack {
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveSettings()
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .padding()
    }
    
    private func testFileAccess() {
        FileManager.shared.filePathTemplate = filePathTemplate
        FileManager.shared.testFileAccess { success, error in
            fileTestResult = (success, success ? "File access successful!" : error ?? "Failed")
            
            // Clear the result after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                fileTestResult = nil
            }
        }
    }
    
    private func saveSettings() {
        FileManager.shared.filePathTemplate = filePathTemplate
        FileManager.shared.noteTemplate = noteTemplate
    }
    
    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
    
    private func openAccessibilityPreferences() {
        // Try multiple methods to open accessibility preferences
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: Open System Preferences app
            NSWorkspace.shared.launchApplication("System Preferences")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
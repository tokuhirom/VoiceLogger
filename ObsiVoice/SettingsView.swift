import SwiftUI

struct SettingsView: View {
    @State private var filePathTemplate = FileManager.shared.filePathTemplate
    @State private var noteTemplate = FileManager.shared.noteTemplate
    @State private var dateHeaderFormat = FileManager.shared.dateHeaderFormat
    @State private var dateLocale = FileManager.shared.dateLocale
    @State private var recordingShortcut = ShortcutManager.shared.currentShortcut
    @State private var expandedPath: String = ""
    @State private var dateHeaderPreview: String = ""
    
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
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Date Header Format")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("yyyy-MM-dd (EEEE)", text: $dateHeaderFormat)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: dateHeaderFormat) { _ in
                                updateDateHeaderPreview()
                            }
                        HStack {
                            Text("Locale:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("en_US", text: $dateLocale)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .onChange(of: dateLocale) { _ in
                                    updateDateHeaderPreview()
                                }
                            Text("(e.g., en_US, ja_JP, fr_FR)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text("Preview: \(dateHeaderPreview)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onAppear {
                                updateDateHeaderPreview()
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Current file path:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(expandedPath.isEmpty ? FileManager.shared.getCurrentLogFilePath() : expandedPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .onAppear {
                                expandedPath = FileManager.shared.getCurrentLogFilePath()
                            }
                            .onChange(of: filePathTemplate) { _ in
                                expandedPath = FileManager.shared.getCurrentLogFilePath()
                            }
                        
                        Button("Open Log File") {
                            FileManager.shared.openCurrentLogFile()
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
        .frame(width: 500, height: 500)
        .padding()
    }
    
    private func saveSettings() {
        FileManager.shared.filePathTemplate = filePathTemplate
        FileManager.shared.noteTemplate = noteTemplate
        FileManager.shared.dateHeaderFormat = dateHeaderFormat
        FileManager.shared.dateLocale = dateLocale
    }
    
    private func updateDateHeaderPreview() {
        dateHeaderPreview = FileManager.shared.getDateHeaderPreview()
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
import SwiftUI

struct SettingsView: View {
    @State private var vaultName = ObsidianManager.shared.vaultName
    @State private var noteTemplate = ObsidianManager.shared.noteTemplate
    @State private var recordingShortcut = ShortcutManager.shared.currentShortcut
    @State private var showingConnectionTest = false
    @State private var connectionTestResult: (success: Bool, message: String)?
    
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
                }
                .padding()
            }
            
            // Obsidian Settings
            GroupBox(label: Label("Obsidian Integration", systemImage: "note.text")) {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Vault Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Your Vault Name", text: $vaultName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
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
                        Button("Test Connection") {
                            testConnection()
                        }
                        .disabled(vaultName.isEmpty)
                        
                        if let result = connectionTestResult {
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
    
    private func testConnection() {
        ObsidianManager.shared.vaultName = vaultName
        ObsidianManager.shared.testConnection { success, error in
            connectionTestResult = (success, success ? "Connected!" : error ?? "Failed")
            
            // Clear the result after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                connectionTestResult = nil
            }
        }
    }
    
    private func saveSettings() {
        ObsidianManager.shared.vaultName = vaultName
        ObsidianManager.shared.noteTemplate = noteTemplate
    }
    
    private func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
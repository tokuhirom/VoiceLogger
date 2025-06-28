import Foundation
import AppKit

class FileManager {
    static let shared = FileManager()
    
    private let filePathTemplateKey = "FilePathTemplate"
    private let noteTemplateKey = "NoteTemplate"
    private let dateHeaderFormatKey = "DateHeaderFormat"
    private let dateLocaleKey = "DateLocale"
    private let showNotificationsKey = "ShowNotifications"
    private let autoStartRecordingKey = "AutoStartRecording"
    private let launchAtLoginKey = "LaunchAtLogin"
    
    private init() {}
    
    var filePathTemplate: String {
        get {
            UserDefaults.standard.string(forKey: filePathTemplateKey) ?? "~/Documents/VoiceLogger/%Y%m/%Y-%m-%d.md"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: filePathTemplateKey)
        }
    }
    
    var noteTemplate: String {
        get {
            UserDefaults.standard.string(forKey: noteTemplateKey) ?? "- {time} {text}"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: noteTemplateKey)
        }
    }
    
    var dateHeaderFormat: String {
        get {
            UserDefaults.standard.string(forKey: dateHeaderFormatKey) ?? "yyyy-MM-dd (EEEE)"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dateHeaderFormatKey)
        }
    }
    
    var dateLocale: String {
        get {
            UserDefaults.standard.string(forKey: dateLocaleKey) ?? "en_US"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dateLocaleKey)
        }
    }
    
    var showNotifications: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: showNotificationsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showNotificationsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showNotificationsKey)
        }
    }
    
    var autoStartRecording: Bool {
        get {
            return UserDefaults.standard.bool(forKey: autoStartRecordingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoStartRecordingKey)
        }
    }
    
    var launchAtLogin: Bool {
        get {
            return LaunchAtLoginHelper.shared.isEnabled
        }
        set {
            LaunchAtLoginHelper.shared.isEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
        }
    }
    
    private func expandPath(_ template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        var path = template
        
        // Expand home directory
        if path.hasPrefix("~/") {
            path = NSString(string: path).expandingTildeInPath
        }
        
        // Replace date placeholders
        let date = Date()
        
        // Year
        formatter.dateFormat = "yyyy"
        path = path.replacingOccurrences(of: "%Y", with: formatter.string(from: date))
        
        // Month
        formatter.dateFormat = "MM"
        path = path.replacingOccurrences(of: "%m", with: formatter.string(from: date))
        
        // Day
        formatter.dateFormat = "dd"
        path = path.replacingOccurrences(of: "%d", with: formatter.string(from: date))
        
        // Hour
        formatter.dateFormat = "HH"
        path = path.replacingOccurrences(of: "%H", with: formatter.string(from: date))
        
        // Minute
        formatter.dateFormat = "mm"
        path = path.replacingOccurrences(of: "%M", with: formatter.string(from: date))
        
        // Second
        formatter.dateFormat = "ss"
        path = path.replacingOccurrences(of: "%S", with: formatter.string(from: date))
        
        // Year (2 digits)
        formatter.dateFormat = "yy"
        path = path.replacingOccurrences(of: "%y", with: formatter.string(from: date))
        
        // Month name (full)
        formatter.dateFormat = "MMMM"
        path = path.replacingOccurrences(of: "%B", with: formatter.string(from: date))
        
        // Month name (abbreviated)
        formatter.dateFormat = "MMM"
        path = path.replacingOccurrences(of: "%b", with: formatter.string(from: date))
        
        return path
    }
    
    func appendToFile(text: String) {
        let filePath = expandPath(filePathTemplate)
        let url = URL(fileURLWithPath: filePath)
        
        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        do {
            try Foundation.FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory: \(error)")
            return
        }
        
        // Format the text with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timestamp = formatter.string(from: Date())
        
        let formattedText = noteTemplate
            .replacingOccurrences(of: "{time}", with: timestamp)
            .replacingOccurrences(of: "{text}", with: text)
        
        // Append to file
        do {
            let isNewFile = !Foundation.FileManager.default.fileExists(atPath: filePath)
            
            if isNewFile {
                // Create new file with date header
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: dateLocale)
                dateFormatter.dateFormat = dateHeaderFormat
                let dateHeader = "# \(dateFormatter.string(from: Date()))\n\n"
                
                let initialContent = dateHeader + formattedText
                try initialContent.write(to: url, atomically: true, encoding: .utf8)
            } else {
                // Append to existing file
                let dataToAppend = "\n\(formattedText)".data(using: .utf8)!
                let fileHandle = try FileHandle(forWritingTo: url)
                fileHandle.seekToEndOfFile()
                fileHandle.write(dataToAppend)
                fileHandle.closeFile()
            }
            
            print("Successfully wrote to: \(filePath)")
        } catch {
            print("Failed to write to file: \(error)")
        }
    }
    
    func openCurrentLogFile() {
        let filePath = expandPath(filePathTemplate)
        let url = URL(fileURLWithPath: filePath)
        
        if Foundation.FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.open(url)
        } else {
            // If file doesn't exist, open the directory
            let directory = url.deletingLastPathComponent()
            if Foundation.FileManager.default.fileExists(atPath: directory.path) {
                NSWorkspace.shared.open(directory)
            } else {
                // Try to create directory and open it
                do {
                    try Foundation.FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                    NSWorkspace.shared.open(directory)
                } catch {
                    print("Failed to create directory: \(error)")
                }
            }
        }
    }
    
    func getCurrentLogFilePath() -> String {
        return expandPath(filePathTemplate)
    }
    
    func getDateHeaderPreview() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: dateLocale)
        formatter.dateFormat = dateHeaderFormat
        return "# \(formatter.string(from: Date()))"
    }
}
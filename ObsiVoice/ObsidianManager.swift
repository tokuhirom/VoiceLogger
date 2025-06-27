import Foundation
import AppKit

class ObsidianManager {
    static let shared = ObsidianManager()
    
    private let vaultNameKey = "ObsidianVaultName"
    private let templateKey = "ObsidianNoteTemplate"
    
    private init() {}
    
    var vaultName: String {
        get {
            UserDefaults.standard.string(forKey: vaultNameKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: vaultNameKey)
        }
    }
    
    var noteTemplate: String {
        get {
            UserDefaults.standard.string(forKey: templateKey) ?? "- {time} {text}"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: templateKey)
        }
    }
    
    func appendToDaily(text: String) {
        guard !vaultName.isEmpty else {
            print("Obsidian vault name not configured")
            return
        }
        
        // Format the text with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timestamp = formatter.string(from: Date())
        
        let formattedText = noteTemplate
            .replacingOccurrences(of: "{time}", with: timestamp)
            .replacingOccurrences(of: "{text}", with: text)
        
        // Create the Advanced URI
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "advanced-uri"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName),
            URLQueryItem(name: "daily", value: "true"),
            URLQueryItem(name: "mode", value: "append"),
            URLQueryItem(name: "data", value: "\n\(formattedText)")
        ]
        
        guard let url = components.url else {
            print("Failed to create Obsidian URL")
            return
        }
        
        // Open the URL
        NSWorkspace.shared.open(url)
    }
    
    func testConnection(completion: @escaping (Bool, String?) -> Void) {
        guard !vaultName.isEmpty else {
            completion(false, "Vault name not configured")
            return
        }
        
        // Test by trying to open the vault
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName)
        ]
        
        guard let url = components.url else {
            completion(false, "Failed to create test URL")
            return
        }
        
        if NSWorkspace.shared.open(url) {
            completion(true, nil)
        } else {
            completion(false, "Failed to open Obsidian. Make sure Obsidian is installed and the vault name is correct.")
        }
    }
}
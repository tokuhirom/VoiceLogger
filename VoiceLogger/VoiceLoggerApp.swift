//
//  VoiceLoggerApp.swift
//  VoiceLogger
//
//  Created by 松野 徳大 on 2025/06/27.
//

import SwiftUI

@main
struct VoiceLoggerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

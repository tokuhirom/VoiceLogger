# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ObsiVoice is a macOS menu bar application that captures voice notes via keyboard shortcuts, transcribes them using native macOS APIs, and appends them to Obsidian daily notes via Advanced URI.

**Current Status**: Initial project setup with no features implemented yet. The codebase consists of a basic SwiftUI template.

## Build and Run Commands

```bash
# Build the project
xcodebuild -project ObsiVoice.xcodeproj -scheme ObsiVoice -configuration Debug build

# Run the app
open build/Debug/ObsiVoice.app

# Run unit tests
xcodebuild test -project ObsiVoice.xcodeproj -scheme ObsiVoice -destination 'platform=macOS'

# Clean build folder
xcodebuild clean -project ObsiVoice.xcodeproj -scheme ObsiVoice
```

For development, use Xcode:
```bash
open ObsiVoice.xcodeproj
```

## Architecture Requirements

This app needs to be transformed from a window-based SwiftUI app to a menu bar application with the following architecture:

### Core Components to Implement

1. **Menu Bar App Structure**
   - Convert from window-based to NSStatusItem-based app
   - Remove default ContentView window
   - Add menu bar icon (🎙️) and dropdown menu

2. **Audio Recording System**
   - Use AVFoundation for microphone access
   - Implement push-to-talk and toggle recording modes
   - Handle audio session management

3. **Speech Recognition**
   - Use Speech framework for on-device transcription
   - Request speech recognition permissions
   - Process audio buffers to text

4. **Keyboard Shortcut Handler**
   - Global hotkey registration (likely using CGEventTap or similar)
   - Support for hold-to-record and double-tap modes
   - Configurable shortcuts

5. **Obsidian Integration**
   - Implement Advanced URI protocol handling
   - Format: `obsidian://advanced-uri?vault=VAULT_NAME&daily=true&mode=append&data=TRANSCRIBED_TEXT`
   - Store vault name in UserDefaults

6. **Settings Window**
   - Preferences for keyboard shortcuts
   - Obsidian vault configuration
   - Recording mode selection

## Required Entitlements

Update `ObsiVoice.entitlements` to include:
- `com.apple.security.device.audio-input` - Microphone access
- `NSSpeechRecognitionUsageDescription` in Info.plist
- `NSMicrophoneUsageDescription` in Info.plist

## Key Implementation Notes

- Use `NSStatusBar.system.statusItem(withLength:)` for menu bar presence
- Implement `NSApplicationDelegate` lifecycle methods
- Consider using `LaunchAtLogin` for startup behavior
- Store user preferences in `UserDefaults`
- Use `NSWorkspace.shared.open(URL)` for Obsidian URI calls

## Testing Approach

- Test audio recording permissions handling
- Test speech recognition accuracy
- Test Obsidian URI generation and execution
- Test keyboard shortcut conflicts
- UI tests for menu bar interactions

## Dependencies

Currently no external dependencies. The app uses only native macOS frameworks:
- SwiftUI
- AVFoundation (to be added)
- Speech (to be added)
- AppKit for menu bar functionality (to be added)

## Version Control Guidelines

- Commit message must be in english.

## Platform Specific Notes

- This app runs on MacOS. Not run on iOS. AVAudioSession is not available on Mac.
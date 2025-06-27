# ObsiVoice 🎙️🪶

**ObsiVoice** is a lightweight macOS menu bar app that lets you capture voice notes via a simple keyboard shortcut. It transcribes your speech using macOS native APIs and appends the result directly to your Obsidian daily note via Advanced URI.

---

## 🚀 Features

- 🎧 Dual recording modes:
  - **Single tap**: Toggle recording on/off
  - **Hold**: Push-to-talk (records while holding, with 1-second trailing buffer)
- 🎤 Microphone selection from available audio devices
- 🧠 On-device speech-to-text transcription (macOS built-in)
- 🌏 Supports multiple languages including Japanese
- 📝 Automatically appends transcribed text to Obsidian daily notes
- ⏰ Customizable note format with timestamp
- 🧵 Lives quietly in your Mac menu bar

---

## 🛠 Requirements

- macOS 13.0 Ventura or later
- [Obsidian](https://obsidian.md) with [Advanced URI plugin](https://github.com/Vinzent03/obsidian-advanced-uri) enabled
- Microphone access permission
- Speech recognition permission
- Accessibility permission (for global keyboard shortcuts)

---

## 🧩 Installation

> 🔧 The app is currently under development.

To build from source:

```bash
git clone https://github.com/yourusername/ObsiVoice.git
cd ObsiVoice
open ObsiVoice.xcodeproj
```

Then build and run from Xcode.

---

## 🎮 Usage

### Initial Setup
1. Launch ObsiVoice — it will appear in the macOS menu bar (🎙️ icon)
2. Click the menu bar icon and select "Settings..."
3. Configure your Obsidian vault name
4. Set your preferred keyboard shortcut
5. Grant required permissions when prompted

### Recording Voice Notes
- **Single tap** your shortcut key: Start/stop recording (toggle mode)
- **Hold** your shortcut key: Record while holding (push-to-talk mode)
  - Automatically stops 1 second after releasing to capture trailing audio
  - Shows hourglass icon during the delay

The transcribed text will be automatically appended to your Obsidian daily note.

---

## 📂 Configuration

### Settings Options
- **Recording Shortcut**: Set your preferred global keyboard shortcut
- **Microphone**: Select from available audio input devices
- **Obsidian Vault**: Configure your vault name
- **Note Template**: Customize the format (default: `- {time} {text}`)
  - `{time}`: Replaced with HH:mm timestamp
  - `{text}`: Replaced with transcribed text

---

## 🛡️ Permissions

ObsiVoice requires the following permissions:

1. **Microphone Access**: For recording audio
   - Grant when prompted on first recording
2. **Speech Recognition**: For transcribing voice to text
   - Grant when prompted on first use
3. **Accessibility**: For global keyboard shortcuts
   - Go to System Settings > Privacy & Security > Accessibility
   - Enable ObsiVoice in the list
4. **Obsidian URI**: Ensure Obsidian accepts Advanced URI requests

---

## 📄 License
MIT License © 2025 Tokuhiro Matsuno

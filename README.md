# ObsiVoice 🎙️🪶

**ObsiVoice** is a lightweight macOS menu bar app that lets you capture voice notes via a simple keyboard shortcut. It transcribes your speech using macOS native APIs and appends the result directly to your Obsidian daily note via Advanced URI.

---

## 🚀 Features

- 🎧 Start/stop voice recording with a keyboard shortcut
- 🔁 Hold key to record, double-tap to lock recording
- 🧠 On-device speech-to-text transcription (macOS built-in)
- 📝 Automatically writes transcribed text into Obsidian daily notes
- 🧵 Lives quietly in your Mac menu bar

---

## 🛠 Requirements

- macOS 13.0 Ventura or later
- [Obsidian](https://obsidian.md) with [Advanced URI plugin](https://github.com/Vinzent03/obsidian-advanced-uri) enabled
- Microphone access permission granted

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
1. Launch the app — it will appear in the macOS menu bar (🎙 icon).
2. Use the global shortcut (e.g. ⌘ + ⇧ + V) to start recording.
   - **Hold the key**: records while held
   - **Double-tap**: enters locked recording mode
3. When recording ends, speech will be transcribed.
4. Transcription will be sent to your Obsidian daily note via Advanced URI.

---

## 📂 Configuration
- Change your preferred shortcut in Settings.
- Set your Obsidian vault name and URI format in the preferences panel.

---

## 🛡️ Permissions
Please make sure the app has the following permissions:

- ✅ Microphone access
- ✅ Speech recognition
- ✅ Obsidian must accept URI requests

---

## 📄 License
MIT License © 2025 Tokuhiro Matsuno

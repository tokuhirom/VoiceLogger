# VoiceLogger 🎙️📝

**VoiceLogger** (formerly ObsiVoice) is a lightweight macOS menu bar app that lets you capture voice notes via a simple keyboard shortcut. It transcribes your speech using macOS native APIs and saves the result to markdown files with customizable paths and formats.

> **Note**: The project is in the process of being renamed from ObsiVoice to VoiceLogger. Some references may still use the old name.

---

## 🚀 Features

- 🎧 Dual recording modes:
  - **Single tap**: Toggle recording on/off
  - **Hold**: Push-to-talk (records while holding, with 1-second trailing buffer)
- 🎤 Microphone selection from available audio devices
- 🧠 On-device speech-to-text transcription (macOS built-in)
- 🌏 Supports multiple languages including Japanese
- 📝 Automatically saves transcribed text to markdown files
- 📁 Customizable file paths with date-based templates
- ⏰ Customizable note format with timestamps
- 🔕 Optional notifications (can be disabled for continuous recording)
- 🌍 Customizable date header format and locale
- 🧵 Lives quietly in your Mac menu bar
- ✍️ Real-time incremental writing with silence detection

---

## 🛠 Requirements

- macOS 13.0 Ventura or later
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
3. Configure your file path template
4. Set your preferred keyboard shortcut
5. Grant required permissions when prompted

### Recording Voice Notes
- **Single tap** your shortcut key: Start/stop recording (toggle mode)
- **Hold** your shortcut key: Record while holding (push-to-talk mode)
  - Automatically stops 1 second after releasing to capture trailing audio
  - Shows hourglass icon during the delay

The transcribed text will be automatically saved to your configured file path. With silence detection enabled, text is written incrementally during long recording sessions.

---

## 📂 Configuration

### Settings Options
- **Recording Shortcut**: Set your preferred global keyboard shortcut
- **Microphone**: Select from available audio input devices
- **File Path Template**: Customize where files are saved (default: `~/Documents/VoiceLogger/%Y%m/%Y-%m-%d.md`)
  - Supports date placeholders: `%Y` (year), `%m` (month), `%d` (day), etc.
- **Note Template**: Customize the format (default: `- {time} {text}`)
  - `{time}`: Replaced with HH:mm timestamp
  - `{text}`: Replaced with transcribed text
- **Date Header Format**: Customize the format for new file headers (default: `yyyy-MM-dd (EEEE)`)
- **Date Locale**: Set the locale for date formatting (default: `en_US`)
  - Examples: `ja_JP` for Japanese, `fr_FR` for French
- **Show Notifications**: Toggle transcription notifications on/off

---

## 🛡️ Permissions

VoiceLogger requires the following permissions:

1. **Microphone Access**: For recording audio
   - Grant when prompted on first recording
2. **Speech Recognition**: For transcribing voice to text
   - Grant when prompted on first use
3. **Accessibility**: For global keyboard shortcuts
   - Go to System Settings > Privacy & Security > Accessibility
   - Enable VoiceLogger (may still show as ObsiVoice) in the list

---

## 📝 File Organization

VoiceLogger automatically organizes your transcriptions:
- Creates directories based on your file path template
- Adds a date header when creating new daily files
- Appends new transcriptions with timestamps
- Supports continuous recording with automatic segmentation based on silence detection

### Example Output
```markdown
# 2025-06-28 (Friday)

- 09:30 First voice note of the day
- 10:15 Meeting notes about project planning
- 14:22 Quick reminder to buy groceries
```

---

## 📄 License
MIT License © 2025 Tokuhiro Matsuno

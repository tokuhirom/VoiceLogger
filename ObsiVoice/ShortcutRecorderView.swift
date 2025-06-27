import SwiftUI
import AppKit

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut?
    
    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.delegate = context.coordinator
        button.shortcut = shortcut
        return button
    }
    
    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcut = shortcut
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ShortcutRecorderButtonDelegate {
        let parent: ShortcutRecorderView
        
        init(_ parent: ShortcutRecorderView) {
            self.parent = parent
        }
        
        func shortcutRecorderButton(_ button: ShortcutRecorderButton, didReceiveShortcut shortcut: KeyboardShortcut?) {
            parent.shortcut = shortcut
        }
    }
}

protocol ShortcutRecorderButtonDelegate: AnyObject {
    func shortcutRecorderButton(_ button: ShortcutRecorderButton, didReceiveShortcut shortcut: KeyboardShortcut?)
}

class ShortcutRecorderButton: NSButton {
    weak var delegate: ShortcutRecorderButtonDelegate?
    
    var shortcut: KeyboardShortcut? {
        didSet {
            updateTitle()
        }
    }
    
    private var isRecording = false {
        didSet {
            updateTitle()
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(buttonClicked)
        updateTitle()
    }
    
    private func updateTitle() {
        if isRecording {
            title = "Type Shortcut..."
            contentTintColor = .systemRed
        } else if let shortcut = shortcut {
            title = shortcut.displayString
            contentTintColor = nil
        } else {
            title = "Click to Record Shortcut"
            contentTintColor = nil
        }
    }
    
    @objc private func buttonClicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
    }
    
    private func stopRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
    }
    
    override func keyDown(with event: NSEvent) {
        if isRecording {
            // Ignore plain keys without modifiers
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.isEmpty {
                NSSound.beep()
                return
            }
            
            let newShortcut = KeyboardShortcut(
                keyCode: event.keyCode,
                modifierFlags: flags.rawValue
            )
            
            shortcut = newShortcut
            delegate?.shortcutRecorderButton(self, didReceiveShortcut: newShortcut)
            stopRecording()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        if isRecording {
            // Allow recording modifier-only shortcuts (like Cmd+Shift)
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !flags.isEmpty && event.keyCode == 0 {
                // This is a modifier key press
            }
        } else {
            super.flagsChanged(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return isRecording
    }
    
    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return super.resignFirstResponder()
    }
}
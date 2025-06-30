import Speech
import Combine

class SpeechRecognizer: NSObject, ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer!
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var transcribedText = ""
    @Published var isAuthorized = false
    
    // Silence detection
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0 // 2 seconds of silence triggers segment
    private var lastSegmentText = ""
    private var segmentCallback: ((String) -> Void)?
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.isAuthorized = true
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    func startTranscription(with request: SFSpeechAudioBufferRecognitionRequest, 
                            completion: @escaping (String?, Error?) -> Void,
                            onSegment: ((String) -> Void)? = nil) {
        guard isAuthorized else {
            completion(nil, NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]))
            return
        }
        
        // Cancel any existing task properly
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
            // Give a small delay to ensure cleanup
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        transcribedText = ""
        lastSegmentText = ""
        var lastTranscribedText = ""
        segmentCallback = onSegment
        
        // Cancel any existing silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                // Keep track of the last non-empty transcription
                if !text.isEmpty {
                    lastTranscribedText = text
                    
                    // Check if we have new content since last segment
                    let newContent = self.extractNewContent(fullText: text, lastSegment: self.lastSegmentText)
                    if !newContent.isEmpty {
                        // Reset silence timer when we detect speech
                        self.resetSilenceTimer()
                    }
                }
                
                DispatchQueue.main.async {
                    self.transcribedText = text
                }
                
                if result.isFinal {
                    // Use the last non-empty transcription if the final is empty
                    let finalText = text.isEmpty ? lastTranscribedText : text
                    completion(finalText, nil)
                    // Clean up the task
                    self.recognitionTask = nil
                }
            }
            
            if let error = error {
                // If we got a cancel error but have transcribed text, return it
                if (error as NSError).code == 301 && !lastTranscribedText.isEmpty {
                    completion(lastTranscribedText, nil)
                } else if (error as NSError).code != 301 && (error as NSError).code != 1101 {
                    // Only log non-cancel and non-1101 errors
                    print("Speech recognition error: \(error)")
                    completion(nil, error)
                }
                // Clean up the task on error
                self.recognitionTask = nil
            }
        }
    }
    
    func stopTranscription() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // If we have any remaining text, send it as the final segment
        if !transcribedText.isEmpty && transcribedText != lastSegmentText {
            let finalSegment = extractNewContent(fullText: transcribedText, lastSegment: lastSegmentText)
            if !finalSegment.isEmpty {
                segmentCallback?(finalSegment)
            }
        }
        
        recognitionTask?.finish()
        recognitionTask = nil
    }
    
    private func setupSpeechRecognizer() {
        let localeIdentifier = FileManager.shared.speechRecognitionLocale
        let locale = Locale(identifier: localeIdentifier)
        
        // Check if the locale is supported
        if let recognizer = SFSpeechRecognizer(locale: locale) {
            speechRecognizer = recognizer
        } else {
            // Fallback to system locale
            print("Locale \(localeIdentifier) not supported for speech recognition, falling back to system locale")
            speechRecognizer = SFSpeechRecognizer()
        }
    }
    
    func updateLocale() {
        // Stop any ongoing transcription
        if recognitionTask != nil {
            stopTranscription()
        }
        
        // Setup with new locale
        setupSpeechRecognizer()
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            self?.handleSilenceDetected()
        }
    }
    
    private func handleSilenceDetected() {
        // Extract new content since last segment
        let newContent = extractNewContent(fullText: transcribedText, lastSegment: lastSegmentText)
        
        if !newContent.isEmpty {
            // Send the segment
            segmentCallback?(newContent)
            
            // Update last segment to current full text
            lastSegmentText = transcribedText
        }
    }
    
    private func extractNewContent(fullText: String, lastSegment: String) -> String {
        // If lastSegment is empty, return the full text
        if lastSegment.isEmpty {
            return fullText
        }
        
        // If full text starts with last segment, extract only the new part
        if fullText.hasPrefix(lastSegment) {
            let newPart = String(fullText.dropFirst(lastSegment.count))
            return newPart.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Otherwise, return the full text (might be a complete restart)
        return fullText
    }
    
    deinit {
        silenceTimer?.invalidate()
        stopTranscription()
    }
}

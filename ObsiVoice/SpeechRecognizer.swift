import Speech
import Combine

class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var transcribedText = ""
    @Published var isAuthorized = false
    
    override init() {
        super.init()
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
    
    func startTranscription(with request: SFSpeechAudioBufferRecognitionRequest, completion: @escaping (String?, Error?) -> Void) {
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
        var lastTranscribedText = ""
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                // Keep track of the last non-empty transcription
                if !text.isEmpty {
                    lastTranscribedText = text
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
        recognitionTask?.finish()
        recognitionTask = nil
    }
    
    deinit {
        stopTranscription()
    }
}
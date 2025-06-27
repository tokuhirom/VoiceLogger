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
        print("Starting transcription, authorized: \(isAuthorized)")
        guard isAuthorized else {
            completion(nil, NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]))
            return
        }
        
        recognitionTask?.cancel()
        transcribedText = ""
        var lastTranscribedText = ""
        
        print("Creating recognition task...")
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                print("Transcription result: '\(text)' (final: \(result.isFinal))")
                
                // Keep track of the last non-empty transcription
                if !text.isEmpty {
                    lastTranscribedText = text
                }
                
                DispatchQueue.main.async {
                    self?.transcribedText = text
                }
                
                if result.isFinal {
                    // Use the last non-empty transcription if the final is empty
                    let finalText = text.isEmpty ? lastTranscribedText : text
                    print("Final transcription: '\(finalText)'")
                    completion(finalText, nil)
                }
            }
            
            if let error = error {
                print("Recognition error: \(error)")
                // If we got a cancel error but have transcribed text, return it
                if (error as NSError).code == 301 && !lastTranscribedText.isEmpty {
                    print("Returning last transcribed text despite cancel: '\(lastTranscribedText)'")
                    completion(lastTranscribedText, nil)
                } else {
                    completion(nil, error)
                }
            }
        }
        
        print("Recognition task created: \(recognitionTask != nil)")
    }
    
    func stopTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    deinit {
        stopTranscription()
    }
}
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
        
        recognitionTask?.cancel()
        transcribedText = ""
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.transcribedText = text
                }
                
                if result.isFinal {
                    completion(text, nil)
                }
            }
            
            if let error = error {
                print("Recognition error: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func stopTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    deinit {
        stopTranscription()
    }
}
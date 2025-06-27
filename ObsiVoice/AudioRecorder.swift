import AVFoundation
import Combine
import Speech

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var inputNode: AVAudioInputNode?
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    
    override init() {
        super.init()
    }
    
    func startRecording() -> SFSpeechAudioBufferRecognitionRequest? {
        guard !isRecording else { return nil }
        
        // Check microphone permission first
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    DispatchQueue.main.async {
                        _ = self.startRecording()
                    }
                }
            }
            return nil
        case .denied, .restricted:
            print("Microphone access denied")
            return nil
        case .authorized:
            break
        @unknown default:
            return nil
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return nil }
        
        inputNode = audioEngine.inputNode
        
        // Use the input node's format to avoid format mismatch
        let recordingFormat = inputNode!.outputFormat(forBus: 0)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        do {
            inputNode!.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] (buffer, _) in
                self?.recognitionRequest?.append(buffer)
                
                // Calculate audio level for visual feedback
                let channelData = buffer.floatChannelData?[0]
                let channelDataValueCount = Int(buffer.frameLength)
                if let channelData = channelData {
                    var sum: Float = 0
                    for i in 0..<channelDataValueCount {
                        sum += channelData[i] * channelData[i]
                    }
                    let rms = sqrt(sum / Float(channelDataValueCount))
                    let avgPower = 20 * log10(max(0.00001, rms))
                    let level = max(0.0, min(1.0, (avgPower + 50) / 50))
                    
                    DispatchQueue.main.async {
                        self?.audioLevel = level
                    }
                }
            }
        } catch {
            print("Failed to install tap: \(error)")
            return nil
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            return recognitionRequest
        } catch {
            print("Failed to start audio engine: \(error)")
            stopRecording()
            return nil
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        
        audioEngine = nil
        recognitionRequest = nil
        inputNode = nil
        
        isRecording = false
        audioLevel = 0.0
    }
    
    deinit {
        stopRecording()
    }
}
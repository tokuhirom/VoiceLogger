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
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return nil }
        
        inputNode = audioEngine.inputNode
        let recordingFormat = inputNode!.outputFormat(forBus: 0)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        inputNode!.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
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
                let avgPower = 20 * log10(rms)
                let level = max(0.0, min(1.0, (avgPower + 50) / 50))
                
                DispatchQueue.main.async {
                    self?.audioLevel = level
                }
            }
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            return recognitionRequest
        } catch {
            print("Failed to start audio engine: \(error)")
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
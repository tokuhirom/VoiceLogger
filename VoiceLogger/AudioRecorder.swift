import AVFoundation
import Combine
import Speech
import CoreAudio

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var inputNode: AVAudioInputNode?
    private var selectedDeviceID: AudioDeviceID?
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevice: AudioDevice?
    
    struct AudioDevice: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
        let uid: String
    }
    
    override init() {
        super.init()
        setupNotifications()
        updateAvailableDevices()
        // loadSelectedDevice is now called after devices are loaded in updateAvailableDevices
    }
    
    private func setupNotifications() {
        // Disable automatic device change monitoring for now
        // This was causing excessive updates and speech recognition errors
    }
    
    deinit {
        stopRecording()
    }
    
    func updateAvailableDevices() {
        var devices: [AudioDevice] = []
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else {
            print("Failed to get audio devices size: \(status)")
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)
        guard status == noErr else {
            print("Failed to get audio devices: \(status)")
            return
        }
        
        for deviceID in audioDevices {
            // Check if it's an input device by getting stream configuration
            var streamConfigAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            // First get the size of the stream configuration
            var configSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &streamConfigAddress, 0, nil, &configSize)
            guard status == noErr, configSize > 0 else {
                continue // Not an input device or error
            }
            
            // Allocate buffer for the stream configuration
            // We need to allocate enough space for AudioBufferList + its variable number of AudioBuffer structs
            let bufferListPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(configSize))
            defer { bufferListPointer.deallocate() }
            
            status = AudioObjectGetPropertyData(deviceID, &streamConfigAddress, 0, nil, &configSize, bufferListPointer)
            guard status == noErr else {
                continue
            }
            
            // Cast to AudioBufferList pointer
            let bufferList = bufferListPointer.withMemoryRebound(to: AudioBufferList.self, capacity: 1) { $0 }
            
            // Check if there are input channels
            let bufferCount = Int(bufferList.pointee.mNumberBuffers)
            var totalChannels: UInt32 = 0
            
            if bufferCount > 0 {
                // Manually calculate channels from the buffer list
                withUnsafePointer(to: &bufferList.pointee.mBuffers) { buffersPtr in
                    let buffers = UnsafeBufferPointer(start: buffersPtr, count: bufferCount)
                    for idx in 0..<bufferCount {
                        totalChannels += buffers[idx].mNumberChannels
                    }
                }
            }
            
            if totalChannels > 0 {
                // Get device name
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                var nameSize = UInt32(MemoryLayout<CFString>.size)
                let cfNamePtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
                defer { cfNamePtr.deallocate() }
                
                status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, cfNamePtr)
                
                // Get device UID
                var uidAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceUID,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                var uidSize = UInt32(MemoryLayout<CFString>.size)
                let cfUIDPtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
                defer { cfUIDPtr.deallocate() }
                
                status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, cfUIDPtr)
                
                if let cfName = cfNamePtr.pointee, let cfUID = cfUIDPtr.pointee {
                    let deviceName = cfName as String
                    let deviceUID = cfUID as String
                    devices.append(AudioDevice(id: deviceID, name: deviceName, uid: deviceUID))
                }
            }
        }
        
        
        DispatchQueue.main.async {
            self.availableDevices = devices
            // Load selected device after devices are available
            self.loadSelectedDevice()
        }
    }
    
    func selectDevice(_ device: AudioDevice) {
        selectedDevice = device
        selectedDeviceID = device.id
        UserDefaults.standard.set(device.uid, forKey: "SelectedMicrophoneUID")
    }
    
    private func loadSelectedDevice() {
        guard let savedUID = UserDefaults.standard.string(forKey: "SelectedMicrophoneUID"),
              let device = availableDevices.first(where: { $0.uid == savedUID }) else {
            selectedDevice = availableDevices.first
            return
        }
        selectedDevice = device
        selectedDeviceID = device.id
    }
    
    func getCurrentMicrophoneName() -> String {
        return selectedDevice?.name ?? "Default Microphone"
    }
    
    func startRecording() -> SFSpeechAudioBufferRecognitionRequest? {
        guard !isRecording else { return nil }
        
        // Check microphone permission first
        guard checkMicrophonePermission() else { return nil }
        
        // Setup audio engine
        guard setupAudioEngine() else { return nil }
        
        // Setup recognition request
        guard let request = setupRecognitionRequest() else {
            stopRecording()
            return nil
        }
        
        return request
    }
    
    private func checkMicrophonePermission() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    DispatchQueue.main.async {
                        _ = self.startRecording()
                    }
                }
            }
            return false
        case .denied, .restricted:
            print("Microphone access denied")
            return false
        case .authorized:
            return true
        @unknown default:
            return false
        }
    }
    
    private func setupAudioEngine() -> Bool {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return false }
        
        // Set the selected audio device if available
        if let deviceID = selectedDeviceID {
            let audioUnit = audioEngine.inputNode.audioUnit
            var deviceIDProp = deviceID
            AudioUnitSetProperty(audioUnit!,
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Global,
                               0,
                               &deviceIDProp,
                               UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        
        inputNode = audioEngine.inputNode
        return true
    }
    
    private func setupRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest? {
        guard let inputNode = inputNode else { return nil }
        
        // Use the input node's format to avoid format mismatch
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = true
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            guard let self = self, let request = self.recognitionRequest else { return }
            request.append(buffer)
            self.processAudioLevel(from: buffer)
        }
        
        audioEngine?.prepare()
        
        do {
            try audioEngine?.start()
            isRecording = true
            return recognitionRequest
        } catch {
            print("Failed to start audio engine: \(error)")
            return nil
        }
    }
    
    private func processAudioLevel(from buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData?[0]
        let channelDataValueCount = Int(buffer.frameLength)
        guard let channelData = channelData else { return }
        
        var sum: Float = 0
        var maxValue: Float = 0
        for idx in 0..<channelDataValueCount {
            let value = channelData[idx]
            sum += value * value
            maxValue = max(maxValue, abs(value))
        }
        let rms = sqrt(sum / Float(channelDataValueCount))
        let avgPower = 20 * log10(max(0.00001, rms))
        let level = max(0.0, min(1.0, (avgPower + 50) / 50))
        
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop the audio engine immediately
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        // End the audio input to the recognition request
        recognitionRequest?.endAudio()
        
        // Clean up
        audioEngine = nil
        recognitionRequest = nil
        inputNode = nil
        
        isRecording = false
        audioLevel = 0.0
    }
}

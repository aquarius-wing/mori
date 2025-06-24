import AVFoundation
import Foundation

@MainActor
class AudioRecordingManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var recordingPermissionGranted = false
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    
    // MARK: - Public Methods
    
    /// Check and request recording permission
    func checkRecordingPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.recordingPermissionGranted = granted
                if granted {
                    print("✅ Recording permission granted")
                } else {
                    print("❌ Recording permission denied")
                }
            }
        }
    }
    
    /// Start recording audio
    func startRecording() throws {
        guard recordingPermissionGranted else {
            throw AudioRecordingError.permissionDenied
        }
        
        guard !isRecording else { 
            print("⚠️ Already recording")
            return 
        }
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        // Create recording URL in /recordings directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("recordings")
        
        // Create recordings directory if it doesn't exist
        try FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true, attributes: nil)
        
        let audioFilename = recordingsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        recordingURL = audioFilename
        
        // Setup recorder settings
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Create and start recorder
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.record()
        
        isRecording = true
        recordingStartTime = Date()
        print("🎤 Started recording to: \(audioFilename)")
    }
    
    /// Stop recording audio
    func stopRecording() {
        guard isRecording else { 
            print("⚠️ Not currently recording, ignoring stop request")
            return 
        }
        
        audioRecorder?.stop()
        isRecording = false
        
        print("⏹️ Stopped recording")
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    /// Check if recording duration meets minimum requirement
    func checkRecordingDuration() throws {
        guard let startTime = recordingStartTime else {
            throw AudioRecordingError.noRecordingFound
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let minimumDuration: TimeInterval = 1.0
        
        if duration < minimumDuration {
            throw AudioRecordingError.tooShort(duration: duration, minimum: minimumDuration)
        }
    }
    
    /// Transcribe audio using LLM service
    func transcribeAudio(using service: LLMAIService) async throws -> String {
        guard let url = recordingURL else {
            throw AudioRecordingError.noRecordingFound
        }
        
        isTranscribing = true
        
        do {
            let audioData = try Data(contentsOf: url)
            let transcribedText = try await service.transcribeAudio(data: audioData)
            
            isTranscribing = false
            
            // Only save recording in DEBUG mode, otherwise delete it
            #if DEBUG
            print("✅ Recording saved to: \(url) (DEBUG mode)")
            #else
            // Delete the recording file in release mode when transcription succeeds
            try? FileManager.default.removeItem(at: url)
            print("✅ Transcription completed, recording deleted (release mode)")
            #endif
            
            print("✅ Transcription completed: \(String(transcribedText.prefix(50)))...")
            
            return transcribedText
            
        } catch {
            isTranscribing = false
            
            // Always keep the recording file when transcription fails for debugging
            print("⚠️ Transcription failed but recording saved to: \(url)")
            
            throw AudioRecordingError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    /// Cancel current recording
    func cancelRecording() {
        if isRecording {
            stopRecording()
        }
        isTranscribing = false
        
        // Clean up recording file if exists
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ Cancelled and cleaned up recording")
        }
        
        recordingURL = nil
        recordingStartTime = nil
    }
}

// MARK: - Error Types
enum AudioRecordingError: LocalizedError {
    case permissionDenied
    case noRecordingFound
    case transcriptionFailed(String)
    case tooShort(duration: TimeInterval, minimum: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Recording permission denied"
        case .noRecordingFound:
            return "No audio recording found"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .tooShort(let duration, let minimum):
            return "Recording too short! Please record for at least \(Int(minimum)) second(s). Your recording was only \(String(format: "%.1f", duration)) second(s)."
        }
    }
} 
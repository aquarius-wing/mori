import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var isSimulator = false
    
    override init() {
        super.init()
        checkSimulator()
        setupAudioSession()
    }
    
    private func checkSimulator() {
        #if targetEnvironment(simulator)
        isSimulator = true
        print("⚠️ Running on iOS Simulator - audio recording features may be limited")
        #else
        isSimulator = false
        #endif
    }
    
    private func setupAudioSession() {
        do {
            // Use more compatible audio settings in simulator
            if isSimulator {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                try audioSession.setCategory(.playAndRecord, mode: .default)
            }
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
            // Ignore certain audio setup errors in simulator
            if !isSimulator {
                print("❌ Audio session setup failed on real device, this may affect recording functionality")
            }
        }
    }
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Add delay in simulator to avoid gesture conflicts
        if isSimulator {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.performStartRecording()
            }
        } else {
            performStartRecording()
        }
    }
    
    private func performStartRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            // Reset audio session (fixes simulator issues)
            try audioSession.setActive(false)
            try audioSession.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            
            if audioRecorder?.record() == true {
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.recordingURL = audioURL
                    print("✅ Recording started successfully")
                }
            } else {
                print("❌ Recording start failed - record() returned false")
                if isSimulator {
                    // Simulate recording start in simulator
                    DispatchQueue.main.async {
                        self.isRecording = true
                        self.recordingURL = audioURL
                        print("⚠️ Simulating recording start in simulator")
                    }
                }
            }
        } catch {
            print("Recording start failed: \(error)")
            if isSimulator {
                print("⚠️ Simulator recording error, trying to continue...")
                // Try to continue even with errors in simulator
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.recordingURL = audioURL
                }
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        if let recorder = audioRecorder {
            recorder.stop()
        }
        
        // Create a virtual audio file in simulator (for testing)
        if isSimulator && recordingURL != nil {
            createDummyAudioFile()
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
            print("✅ Recording stopped")
        }
    }
    
    private func createDummyAudioFile() {
        guard let url = recordingURL else { return }
        
        // Create a small virtual WAV file for testing in simulator
        let data = Data([
            // WAV file header (44 bytes) + a small segment of silence data
            0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
            0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20,
            0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
            0x80, 0x3E, 0x00, 0x00, 0x00, 0x7D, 0x00, 0x00,
            0x02, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
            0x00, 0x00, 0x00, 0x00
        ])
        
        try? data.write(to: url)
        print("⚠️ Created virtual audio file in simulator")
    }
    
    func deleteRecording() {
        guard let url = recordingURL else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to delete recording file: \(error)")
        }
        
        recordingURL = nil
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording encoding error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
} 
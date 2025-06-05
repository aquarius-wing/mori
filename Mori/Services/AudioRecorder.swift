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
        print("⚠️ 运行在iOS模拟器上 - 音频录制功能可能受限")
        #else
        isSimulator = false
        #endif
    }
    
    private func setupAudioSession() {
        do {
            // 在模拟器中使用更兼容的音频设置
            if isSimulator {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                try audioSession.setCategory(.playAndRecord, mode: .default)
            }
            try audioSession.setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
            // 在模拟器中忽略某些音频设置错误
            if !isSimulator {
                print("❌ 音频会话设置在真机上失败，这可能会影响录音功能")
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
        
        // 在模拟器中添加延迟以避免手势冲突
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
            // 重新设置音频会话（解决模拟器问题）
            try audioSession.setActive(false)
            try audioSession.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            
            if audioRecorder?.record() == true {
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.recordingURL = audioURL
                    print("✅ 录音开始成功")
                }
            } else {
                print("❌ 录音开始失败 - record()返回false")
                if isSimulator {
                    // 在模拟器中模拟录音开始
                    DispatchQueue.main.async {
                        self.isRecording = true
                        self.recordingURL = audioURL
                        print("⚠️ 模拟器中模拟录音开始")
                    }
                }
            }
        } catch {
            print("录音开始失败: \(error)")
            if isSimulator {
                print("⚠️ 模拟器录音错误，尝试继续...")
                // 在模拟器中即使出错也尝试继续
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
        
        // 在模拟器中创建一个虚拟的音频文件（用于测试）
        if isSimulator && recordingURL != nil {
            createDummyAudioFile()
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
            print("✅ 录音停止")
        }
    }
    
    private func createDummyAudioFile() {
        guard let url = recordingURL else { return }
        
        // 在模拟器中创建一个小的虚拟WAV文件用于测试
        let data = Data([
            // WAV文件头（44字节）+ 一小段静音数据
            0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
            0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20,
            0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
            0x80, 0x3E, 0x00, 0x00, 0x00, 0x7D, 0x00, 0x00,
            0x02, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
            0x00, 0x00, 0x00, 0x00
        ])
        
        try? data.write(to: url)
        print("⚠️ 模拟器中创建了虚拟音频文件")
    }
    
    func deleteRecording() {
        guard let url = recordingURL else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("删除录音文件失败: \(error)")
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
        print("录音编码错误: \(error?.localizedDescription ?? "未知错误")")
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
} 
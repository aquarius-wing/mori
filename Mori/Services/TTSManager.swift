import Foundation
import AVFoundation
import Combine

// MARK: - TTS Events
extension Notification.Name {
    static let ttsResponseReceived = Notification.Name("TTSResponseReceived")
    static let ttsStatusChanged = Notification.Name("TTSStatusChanged")
    static let ttsPlayMessage = Notification.Name("TTSPlayMessage")
}

// MARK: - TTS Status
enum TTSStatus {
    case idle
    case generating
    case playing
    case error(String)
}

// MARK: - TTS Manager
@MainActor
class TTSManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isEnabled = true
    @Published var currentStatus: TTSStatus = .idle
    @Published var isGenerating = false
    @Published var isPlaying = false
    
    // MARK: - Private Properties
    private var llmService: LLMAIService?
    private var audioPlayer: AVAudioPlayer?
    private var audioPlayerObserver: NSObjectProtocol?
    private var ttsQueue: [String] = []
    private var ttsBuffer = ""
    private var ttsProcessingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init() {
        setupNotificationObservers()
        setupAudioSession()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    func configure(with service: LLMAIService, enabled: Bool = true) {
        self.llmService = service
        self.isEnabled = enabled
        print("🎵 TTSManager configured with service")
    }
    
    func generateTTS(for text: String) {
        guard isEnabled, let service = llmService, !service.getTTSAPIKey().isEmpty else {
            print("⚠️ TTS disabled or TTS API key not available")
            return
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Empty text, skipping TTS")
            return
        }
        
        stopCurrentPlayback()
        updateStatus(.generating)
        
        Task {
            do {
                let audioData = try await performTTSGeneration(text: text)
                playTTSAudio(data: audioData)
            } catch {
                updateStatus(.error("TTS generation failed: \(error.localizedDescription)"))
                print("❌ TTS generation failed: \(error.localizedDescription)")
            }
        }
    }
    
    func processStreamingText(_ text: String) {
        guard isEnabled, let service = llmService, !service.getTTSAPIKey().isEmpty else {
            return
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Add text to buffer
        ttsBuffer += text
        
        // Check if we have enough text to generate TTS
        let shouldGenerateTTS = ttsBuffer.contains(".") || 
                               ttsBuffer.contains("!") || 
                               ttsBuffer.contains("?") || 
                               ttsBuffer.contains("\n") ||
                               ttsBuffer.count >= 50
        
        if shouldGenerateTTS {
            let textToSpeak = ttsBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            ttsBuffer = ""
            
            ttsQueue.append(textToSpeak)
            
            if ttsProcessingTask == nil {
                ttsProcessingTask = Task {
                    await processTTSQueue()
                }
            }
        }
    }
    
    func flushBuffer() {
        guard !ttsBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let remainingText = ttsBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        ttsBuffer = ""
        ttsQueue.append(remainingText)
        
        if ttsProcessingTask == nil {
            ttsProcessingTask = Task {
                await processTTSQueue()
            }
        }
    }
    
    func stopPlayback() {
        stopCurrentPlayback()
        cancelTTSProcessing()
        updateStatus(.idle)
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // Listen for response events
        NotificationCenter.default.addObserver(
            forName: .ttsResponseReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let text = notification.userInfo?["text"] as? String {
                self?.processStreamingText(text)
            }
        }
        
        // Listen for direct play requests
        NotificationCenter.default.addObserver(
            forName: .ttsPlayMessage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let text = notification.userInfo?["text"] as? String {
                self?.generateTTS(for: text)
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func updateStatus(_ status: TTSStatus) {
        currentStatus = status
        
        switch status {
        case .idle:
            isGenerating = false
            isPlaying = false
        case .generating:
            isGenerating = true
            isPlaying = false
        case .playing:
            isGenerating = false
            isPlaying = true
        case .error:
            isGenerating = false
            isPlaying = false
        }
        
        // Notify status change
        NotificationCenter.default.post(
            name: .ttsStatusChanged,
            object: self,
            userInfo: ["status": status]
        )
    }
    
    private func performTTSGeneration(text: String) async throws -> Data {
        guard let service = llmService else {
            throw NSError(domain: "ServiceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "LLM service not available"])
        }
        
        let baseURL = service.getTTSBaseURL()
        guard let url = URL(string: "\(baseURL)/v1/audio/speech") else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid TTS API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(service.getTTSAPIKey())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": service.getTTSVoice(),
            "response_format": "mp3"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🎵 Generating TTS for text: \(String(text.prefix(50)))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "TTS API Error (\(httpResponse.statusCode)): \(errorString)"])
        }
        
        print("✅ TTS generation successful, received \(data.count) bytes")
        return data
    }
    
    private func playTTSAudio(data: Data) {
        do {
            // Setup audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Remove previous observer
            if let observer = audioPlayerObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            
            // Create audio player
            audioPlayer = try AVAudioPlayer(data: data)
            
            // Observe when audio finishes playing
            audioPlayerObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateStatus(.idle)
                print("🔇 TTS playback finished")
            }
            
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            updateStatus(.playing)
            print("🔊 Started TTS playback")
            
            // Set up a timer to check if audio has finished (fallback)
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                await checkAudioPlaybackStatus()
            }
            
        } catch {
            updateStatus(.error("Failed to play TTS audio: \(error.localizedDescription)"))
            print("❌ Failed to play TTS audio: \(error.localizedDescription)")
        }
    }
    
    private func checkAudioPlaybackStatus() async {
        guard case .playing = currentStatus else { return }
        
        if let player = audioPlayer, !player.isPlaying {
            updateStatus(.idle)
            print("🔇 TTS playback finished (detected by status check)")
        } else if case .playing = currentStatus {
            // Check again after a short delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            await checkAudioPlaybackStatus()
        }
    }
    
    private func stopCurrentPlayback() {
        audioPlayer?.stop()
        
        // Remove observer
        if let observer = audioPlayerObserver {
            NotificationCenter.default.removeObserver(observer)
            audioPlayerObserver = nil
        }
        
        print("⏹️ Stopped TTS playback")
    }
    
    private func cancelTTSProcessing() {
        ttsProcessingTask?.cancel()
        ttsProcessingTask = nil
        ttsQueue.removeAll()
        ttsBuffer = ""
    }
    
    private func processTTSQueue() async {
        while !ttsQueue.isEmpty {
            let textToSpeak = ttsQueue.removeFirst()
            
            do {
                if !isGenerating && !isPlaying {
                    updateStatus(.generating)
                }
                
                let audioData = try await performTTSGeneration(text: textToSpeak)
                
                // Wait for current audio to finish before playing next
                while isPlaying {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                
                playTTSAudio(data: audioData)
                
                // Wait a bit before processing next item
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                
            } catch {
                updateStatus(.error("Streaming TTS generation failed: \(error.localizedDescription)"))
                print("❌ Streaming TTS generation failed: \(error.localizedDescription)")
            }
        }
        
        ttsProcessingTask = nil
    }
    
    private func cleanup() {
        stopCurrentPlayback()
        cancelTTSProcessing()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - TTS Manager Extensions
extension TTSManager {
    
    // Helper method to post response event
    static func postResponseEvent(text: String) {
        NotificationCenter.default.post(
            name: .ttsResponseReceived,
            object: nil,
            userInfo: ["text": text]
        )
    }
    
    // Helper method to request TTS playback
    static func playMessage(text: String) {
        NotificationCenter.default.post(
            name: .ttsPlayMessage,
            object: nil,
            userInfo: ["text": text]
        )
    }
} 
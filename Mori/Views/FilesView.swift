import SwiftUI
import AVFoundation

struct RecordingFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let modificationDate: Date
    let size: Int64
}

struct FilesView: View {
    @State private var recordingFiles: [RecordingFile] = []
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingFileID: UUID?
    @State private var isLoading = true
    @State private var audioDelegate: AudioPlayerDelegateImpl?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading recordings...")
                } else if recordingFiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No recordings found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Start recording in the chat to see files here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(recordingFiles) { file in
                        RecordingFileRow(
                            file: file,
                            isPlaying: playingFileID == file.id,
                            onPlayToggle: {
                                togglePlayback(for: file)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Recording Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadRecordingFiles()
                    }
                }
            }
        }
        .onAppear {
            loadRecordingFiles()
        }
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func loadRecordingFiles() {
        isLoading = true
        
        Task {
            let files = await getRecordingFiles()
            await MainActor.run {
                recordingFiles = files
                isLoading = false
            }
        }
    }
    
    private func getRecordingFiles() async -> [RecordingFile] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("recordings")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: recordingsPath,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            let files = fileURLs.compactMap { url -> RecordingFile? in
                guard url.pathExtension == "m4a" else { return nil }
                
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                    let modificationDate = resourceValues.contentModificationDate ?? Date()
                    let size = Int64(resourceValues.fileSize ?? 0)
                    
                    return RecordingFile(
                        url: url,
                        name: url.lastPathComponent,
                        modificationDate: modificationDate,
                        size: size
                    )
                } catch {
                    print("❌ Error getting file attributes for \(url): \(error)")
                    return nil
                }
            }
            
            // Sort by modification date descending (newest first)
            return files.sorted { $0.modificationDate > $1.modificationDate }
            
        } catch {
            print("❌ Error loading recording files: \(error)")
            return []
        }
    }
    
    private func togglePlayback(for file: RecordingFile) {
        if playingFileID == file.id {
            // Stop current playback
            stopPlayback()
        } else {
            // Start new playback
            playAudio(file: file)
        }
    }
    
    private func playAudio(file: RecordingFile) {
        stopPlayback() // Stop any current playback
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: file.url)
            
            // Create delegate that will reset playingFileID when playback finishes
            audioDelegate = AudioPlayerDelegateImpl { [fileID = file.id] in
                DispatchQueue.main.async {
                    if playingFileID == fileID {
                        playingFileID = nil
                    }
                }
            }
            audioPlayer?.delegate = audioDelegate
            audioPlayer?.play()
            playingFileID = file.id
            print("🎵 Started playing: \(file.name)")
        } catch {
            print("❌ Error playing audio file: \(error)")
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioDelegate = nil
        playingFileID = nil
    }
}

struct RecordingFileRow: View {
    let file: RecordingFile
    let isPlaying: Bool
    let onPlayToggle: () -> Void
    
    var body: some View {
        HStack {
            // Play/Pause button
            Button(action: onPlayToggle) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(formatFileSize(file.size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDate(file.modificationDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper class for audio player delegate
class AudioPlayerDelegateImpl: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

#Preview {
    FilesView()
} 
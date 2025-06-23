import SwiftUI
import AVFoundation

struct AudioRecordingButton: View {
    // MARK: - Properties
    @StateObject private var recordingManager = AudioRecordingManager()
    
    let llmService: LLMAIService?
    let onTranscriptionComplete: (String) -> Void
    let onError: (String) -> Void
    let isDisabled: Bool
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Main button
            Button(action: {
                // This is for tap action (currently unused)
            }) {
                Image(systemName: recordingManager.isRecording ? "mic.fill" : "mic")
                    .foregroundColor(buttonColor)
                    .font(.body)
                    .scaleEffect(recordingManager.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: recordingManager.isRecording)
            }
            .disabled(isDisabled || recordingManager.isTranscribing || !recordingManager.recordingPermissionGranted)
            .onLongPressGesture(
                minimumDuration: 0.5,
                maximumDistance: 50,
                perform: {
                    // Long press completed - but we handle stop in onPressingChanged
                },
                onPressingChanged: { pressing in
                    if pressing {
                        // Long press started - start recording
                        handleStartRecording()
                    } else {
                        // Long press ended - stop recording
                        handleStopRecording()
                    }
                }
            )
            .onAppear {
                recordingManager.checkRecordingPermission()
            }
            
            // Recording status overlay - positioned at screen center
            if recordingManager.isRecording || recordingManager.isTranscribing {
                recordingStatusOverlay
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                    .allowsHitTesting(false) // Allow touches to pass through
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonColor: Color {
        if isDisabled || recordingManager.isTranscribing {
            return .gray
        } else if recordingManager.isRecording {
            return .red
        } else if recordingManager.recordingPermissionGranted {
            return .white
        } else {
            return .gray
        }
    }
    
    // MARK: - Recording Status Overlay
    
    @ViewBuilder
    private var recordingStatusOverlay: some View {
        if recordingManager.isRecording {
            VStack(spacing: 8) {
                Text("Recording...")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Release to transcribe")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .transition(.scale.combined(with: .opacity))
        } else if recordingManager.isTranscribing {
            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("Transcribing...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - Private Methods
    
    private func handleStartRecording() {
        guard let service = llmService else {
            onError("LLM service not available")
            return
        }
        
        do {
            try recordingManager.startRecording()
        } catch {
            onError(error.localizedDescription)
        }
    }
    
    private func handleStopRecording() {
        guard let service = llmService else {
            recordingManager.cancelRecording()
            onError("LLM service not available")
            return
        }
        
        recordingManager.stopRecording()
        
        // Start transcription
        Task {
            do {
                let transcribedText = try await recordingManager.transcribeAudio(using: service)
                
                // Only fill input if transcription is not empty
                if !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onTranscriptionComplete(transcribedText)
                }
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    HStack {
        AudioRecordingButton(
            llmService: nil,
            onTranscriptionComplete: { text in
                print("Transcribed: \(text)")
            },
            onError: { error in
                print("Error: \(error)")
            },
            isDisabled: false
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
} 
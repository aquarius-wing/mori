import SwiftUI
import AVFoundation

struct AudioRecordingButton: View {
    // MARK: - Properties
    @StateObject private var recordingManager = AudioRecordingManager()
    
    let llmService: LLMAIService?
    let onTranscriptionComplete: (String) -> Void
    let onError: (String) -> Void
    let isDisabled: Bool
    
    // Recording states from parent
    @Binding var isRecording: Bool
    @Binding var isTranscribing: Bool
    @Binding var recordingPermissionGranted: Bool
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Main button
            Button(action: {
                // This is for tap action (currently unused)
            }) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .foregroundColor(buttonColor)
                    .font(.body)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isRecording)
            }
            .disabled(isDisabled || isTranscribing || !recordingPermissionGranted)
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
                // Sync initial permission state
                recordingPermissionGranted = recordingManager.recordingPermissionGranted
            }
            .onChange(of: recordingManager.isRecording) { _, newValue in
                isRecording = newValue
            }
            .onChange(of: recordingManager.isTranscribing) { _, newValue in
                isTranscribing = newValue
            }
            .onChange(of: recordingManager.recordingPermissionGranted) { _, newValue in
                recordingPermissionGranted = newValue
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonColor: Color {
        if isDisabled || isTranscribing {
            return .gray
        } else if isRecording {
            return .red
        } else if recordingPermissionGranted {
            return .white
        } else {
            return .gray
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
        
        // Check recording duration before transcription
        do {
            try recordingManager.checkRecordingDuration()
        } catch {
            // Duration error - clean up and report
            recordingManager.cancelRecording()
            onError(error.localizedDescription)
            return
        }
        
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
    VStack(spacing: 20) {
        Text("Normal State")
        AudioRecordingButton(
            llmService: nil,
            onTranscriptionComplete: { text in
                print("Transcribed: \(text)")
            },
            onError: { error in
                print("Error: \(error)")
            },
            isDisabled: false,
            isRecording: .constant(false),
            isTranscribing: .constant(false),
            recordingPermissionGranted: .constant(true)
        )
        
        Text("Recording State")
        AudioRecordingButton(
            llmService: nil,
            onTranscriptionComplete: { text in
                print("Transcribed: \(text)")
            },
            onError: { error in
                print("Error: \(error)")
            },
            isDisabled: false,
            isRecording: .constant(true),
            isTranscribing: .constant(false),
            recordingPermissionGranted: .constant(true)
        )
        
        Text("Transcribing State")
        AudioRecordingButton(
            llmService: nil,
            onTranscriptionComplete: { text in
                print("Transcribed: \(text)")
            },
            onError: { error in
                print("Error: \(error)")
            },
            isDisabled: false,
            isRecording: .constant(false),
            isTranscribing: .constant(true),
            recordingPermissionGranted: .constant(true)
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
} 
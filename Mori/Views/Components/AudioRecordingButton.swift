import SwiftUI
import AVFoundation

struct AudioRecordingButton: View {
    // MARK: - Properties
    @StateObject private var recordingManager = AudioRecordingManager()
    
    let llmService: LLMAIService?
    let onTranscriptionComplete: (String) -> Void
    let onError: (String) -> Void
    let isDisabled: Bool
    let cancelZoneFrame: CGRect
    
    // Recording states from parent
    @Binding var isRecording: Bool
    @Binding var isTranscribing: Bool
    @Binding var recordingPermissionGranted: Bool
    @Binding var isDraggedToCancel: Bool
    
    // MARK: - Internal State
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var dragGlobalPosition: CGPoint = .zero
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            // Main button
            Button(action: {
                // This is for tap action (currently unused)
            }) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .foregroundColor(buttonColor)
                    .font(.body)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isRecording)
                    .frame(width: 32, height: 32)
            }
            .disabled(isDisabled || isTranscribing || !recordingPermissionGranted)
            .onLongPressGesture(
                minimumDuration: 0.5,
                maximumDistance: .infinity, // Allow unlimited movement
                perform: {
                    // This will rarely be called because we handle in onPressingChanged
                },
                onPressingChanged: { pressing in
                    if pressing {
                        // Long press started - start recording
                        handleStartRecording()
                        dragOffset = .zero
                        isDraggedToCancel = false
                        isDragging = false
                    } else {
                        print("🛑 Long press ended")
                        // Only stop if we're not in a drag gesture
                        // if !isDragging {
                        //     handleStopRecording()
                        // }
                    }
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isRecording {
                            isDragging = true
                            dragOffset = value.translation
                            
                            // Convert local drag position to global coordinates
                            let buttonGlobalFrame = geometry.frame(in: .global)
                            let fingerGlobalPosition = CGPoint(
                                x: buttonGlobalFrame.midX + value.translation.width,
                                y: buttonGlobalFrame.midY + value.translation.height
                            )
                            dragGlobalPosition = fingerGlobalPosition
                            
                            // Check if finger is within cancel zone (circular area)
                            isDraggedToCancel = isFingerInCancelZone(fingerPosition: fingerGlobalPosition)
                            
                            print("🔍 Button center: \(CGPoint(x: buttonGlobalFrame.midX, y: buttonGlobalFrame.midY)), Finger: \(fingerGlobalPosition), In zone: \(isDraggedToCancel)")
                        }
                    }
                    .onEnded { value in
                    // will trigger better than
                        isDragging = false
                        dragOffset = .zero
                        print("🛑 DragGesture onEnded isRecording: \(isRecording) isDraggedToCancel: \(isDraggedToCancel)")
                        
                        if isRecording {
                            // Check final position to determine cancel vs stop
                            let buttonGlobalFrame = geometry.frame(in: .global)
                            let fingerGlobalPosition = CGPoint(
                                x: buttonGlobalFrame.midX + value.translation.width,
                                y: buttonGlobalFrame.midY + value.translation.height
                            )
                            
                            if isFingerInCancelZone(fingerPosition: fingerGlobalPosition) {
                                // Cancel recording
                                handleCancelRecording()
                            } else {
                                // Normal stop recording
                                handleStopRecording()
                            }
                        }
                        isDraggedToCancel = false
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
        .frame(width: 32, height: 32) // Set explicit frame to match the design
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
    
    private func handleCancelRecording() {
        recordingManager.cancelRecording()
        // Don't call onError for user-initiated cancellation
        print("🚫 Recording cancelled by user")
     }
    
    private func isFingerInCancelZone(fingerPosition: CGPoint) -> Bool {
        // Check if cancelZoneFrame is valid
        guard !cancelZoneFrame.isEmpty else {
            print("⚠️ Cancel zone frame is empty")
            return false
        }
        
        // Calculate the center of the cancel zone (which is a circle)
        let cancelZoneCenter = CGPoint(
            x: cancelZoneFrame.midX,
            y: cancelZoneFrame.midY
        )
        
        // The cancel zone is a circle with radius based on the frame size
        // We'll use a slightly larger radius to make it easier to hit
        let cancelZoneRadius = max(cancelZoneFrame.width, cancelZoneFrame.height) / 2 + 20
        
        // Calculate distance from finger to center of cancel zone
        let distance = sqrt(
            pow(fingerPosition.x - cancelZoneCenter.x, 2) + 
            pow(fingerPosition.y - cancelZoneCenter.y, 2)
        )
        
        let isInZone = distance <= cancelZoneRadius
        
        // Debug logging
        // print("🎯 Finger: \(fingerPosition), Center: \(cancelZoneCenter), Distance: \(distance), Radius: \(cancelZoneRadius), In zone: \(isInZone)")
        
        return isInZone
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
            cancelZoneFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            isRecording: .constant(false),
            isTranscribing: .constant(false),
            recordingPermissionGranted: .constant(true),
            isDraggedToCancel: .constant(false)
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
            cancelZoneFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            isRecording: .constant(true),
            isTranscribing: .constant(false),
            recordingPermissionGranted: .constant(true),
            isDraggedToCancel: .constant(false)
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
            cancelZoneFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            isRecording: .constant(false),
            isTranscribing: .constant(true),
            recordingPermissionGranted: .constant(true),
            isDraggedToCancel: .constant(false)
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
} 

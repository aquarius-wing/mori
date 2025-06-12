import SwiftUI
import Combine
import AVFoundation

// Protocol to allow mixed ChatMessage and WorkflowStep in array
protocol MessageListItem: Identifiable, Codable {
    var id: UUID { get }
    var timestamp: Date { get }
}

extension ChatMessage: MessageListItem {}
extension WorkflowStep: MessageListItem {}

struct ChatView: View {
    @AppStorage("currentProvider") private var currentProvider = LLMProviderType.openRouter.rawValue
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openaiBaseUrl") private var openaiBaseUrl = ""
    @AppStorage("openaiModel") private var openaiModel = ""
    @AppStorage("openrouterApiKey") private var openrouterApiKey = ""
    @AppStorage("openrouterBaseUrl") private var openrouterBaseUrl = ""
    @AppStorage("openrouterModel") private var openrouterModel = ""
    
    @State private var llmService: LLMAIService?
    
    @State private var messageList: [any MessageListItem] = []
    @State private var currentStatus = "Ready"
    @State private var statusType: WorkflowStepStatus = .finalStatus
    @State private var isStreaming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    // Text input related state
    @State private var inputText = ""
    @State private var isSending = false
    
    // Voice recording related state
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var recordingURL: URL?
    @State private var recordingPermissionGranted = false
    @State private var showingFilesView = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Message list display
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(messageList.enumerated()), id: \.element.id) { index, item in
                                if let chatMessage = item as? ChatMessage {
                                    MessageView(message: chatMessage)
                                        .id(chatMessage.id)
                                } else if let workflowStep = item as? WorkflowStep {
                                    WorkflowStepView(step: workflowStep)
                                        .id(workflowStep.id)
                                }
                            }
                            
                            // Display current streaming message
                            if isStreaming || isSending {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Status indicator
                                    StatusIndicator(status: currentStatus, stepStatus: statusType)
                                }
                                .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messageList.count) { _ in
                        withAnimation {
                            if let lastItem = messageList.last {
                                proxy.scrollTo(lastItem.id, anchor: .bottom)
                            }
                        }
                    }

                }
                
                Divider()
                
                // Text input area
                VStack(spacing: 12) {
                    // Text input field
                    HStack(spacing: 12) {
                        TextField("Ask something... (e.g., 'What files are in the root directory?')", text: $inputText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(1...6)
                            .disabled(isSending || isStreaming)
                        
                        // Voice recording button
                        Button(action: {}) {
                            Image(systemName: isRecording ? "mic.fill" : "mic")
                                .foregroundColor(isRecording ? .red : (recordingPermissionGranted ? .blue : .gray))
                                .font(.title2)
                                .scaleEffect(isRecording ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: isRecording)
                        }
                        .disabled(isSending || isStreaming || isTranscribing)
                        .onLongPressGesture(
                            minimumDuration: 0.1,
                            maximumDistance: 50,
                            perform: {
                                // Long press ended - stop recording
                                stopRecording()
                            },
                            onPressingChanged: { pressing in
                                if pressing {
                                    // Long press started - start recording
                                    startRecording()
                                } else {
                                    // Long press ended - stop recording
                                    stopRecording()
                                }
                            }
                        )
                        
                        // Send button
                        Button(action: sendMessage) {
                            Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isStreaming ? .gray : .blue)
                                .font(.title2)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isStreaming)
                    }
                    .padding(.horizontal)
                    
                    // Current status display
                    if isSending || isStreaming || isRecording || isTranscribing {
                        HStack {
                            Image(systemName: statusType == .error ? "exclamationmark.triangle" : 
                                  isRecording ? "waveform" : 
                                  isTranscribing ? "doc.text" : "gear")
                                .foregroundColor(statusType == .error ? .red : 
                                               isRecording ? .red :
                                               isTranscribing ? .orange : .blue)
                            Text(isRecording ? "Recording..." : 
                                 isTranscribing ? "Transcribing..." : currentStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Mori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Debug") {
                        // Single tap action (optional)
                    }
                    .contextMenu {
                        Button(action: {
                            // Print messages in view with all properties using JSONEncoder
                            let chatMessages = messageList.compactMap { $0 as? ChatMessage }
                            do {
                                let encoder = JSONEncoder()
                                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                                encoder.dateEncodingStrategy = .iso8601
                                
                                let jsonData = try encoder.encode(chatMessages)
                                if let jsonString = String(data: jsonData, encoding: .utf8) {
                                    print("📋 ChatMessages in View JSON:")
                                    print(jsonString)
                                }
                            } catch {
                                print("❌ Failed to serialize messages to JSON: \(error)")
                            }
                        }) {
                            Label("Print Messages in View", systemImage: "doc.text")
                        }
                        
                        Button(action: {
                            // Print request body
                            guard let service = llmService else {
                                print("❌ LLM service not available")
                                return
                            }
                            
                            let chatMessages = messageList.compactMap { $0 as? ChatMessage }
                            let requestBody = service.generateRequestBodyJSON(from: chatMessages)
                            
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [.prettyPrinted, .sortedKeys])
                                if let jsonString = String(data: jsonData, encoding: .utf8) {
                                    print("📤 Request Body JSON:")
                                    print(jsonString)
                                }
                            } catch {
                                print("❌ Failed to serialize request body to JSON: \(error)")
                            }
                        }) {
                            Label("Print Request Body", systemImage: "network")
                        }
                        
                        Button(action: {
                            showingFilesView = true
                        }) {
                            Label("View Recording Files", systemImage: "folder")
                        }
                    }
                }
                #endif
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        messageList.removeAll()
                        currentStatus = "Ready"
                        statusType = .finalStatus
                    }
                    .disabled(isStreaming || isSending)
                }
            }
        }
        .onAppear {
            setupLLMService()
            checkRecordingPermission()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $showingFilesView) {
            FilesView()
        }
    }
    
    private func sendMessage() {
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty, let service = llmService else { return }
        
        // Clear input field and reset state
        inputText = ""
        isSending = true
        updateStatus("Processing request...", type: .llmThinking)
        
        // Add user message
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messageList.append(userMessage)
        
        Task {
            do {
                await MainActor.run {
                    isSending = false
                    isStreaming = true
                }
                
                print("📨 Starting workflow with \(messageList.count) items in messageList")
                
                // Process real tool calling workflow
                await processRealToolWorkflow(for: messageText, using: service)
                
            } catch {
                            await MainActor.run {
                let errorStep = WorkflowStep(status: .error, toolName: "Send failed: \(error.localizedDescription)")
                messageList.append(errorStep)
                updateStatus("Error: \(error.localizedDescription)", type: .error)
                isSending = false
                isStreaming = false
            }
            }
        }
    }
    
    private func processRealToolWorkflow(for messageText: String, using service: LLMAIService) async {
        var toolCallCount = 0
        
        do {
            let chatMessages = messageList.compactMap { $0 as? ChatMessage }
            let stream = service.sendChatMessageWithTools(conversationHistory: chatMessages)
            
            for try await result in stream {
                let (status, content) = result
                await MainActor.run {
                    switch status {
                    case "status":
                        updateStatus(content, type: .llmThinking)
                    case "tool_call":
                        toolCallCount += 1
                        let toolCallStep = WorkflowStep(
                            status: .scheduled,
                            toolName: content,
                            details: ["tool_name": content, "arguments": "Pending..."]
                        )
                        messageList.append(toolCallStep)
                        updateStatus("⏰ Scheduling tool: \(content)", type: .scheduled)
                    case "tool_arguments":
                        // Update the most recent scheduled step with arguments
                        if let lastIndex = messageList.lastIndex(where: { ($0 as? WorkflowStep)?.status == .scheduled }) {
                            if let step = messageList[lastIndex] as? WorkflowStep {
                                let updatedStep = WorkflowStep(
                                    status: .scheduled,
                                    toolName: step.toolName,
                                    details: ["tool_name": step.details["tool_name"] ?? "", "arguments": content]
                                )
                                messageList[lastIndex] = updatedStep
                            }
                        }
                    case "tool_execution":
                        // Update the most recent scheduled step to executing
                        if let lastIndex = messageList.lastIndex(where: { ($0 as? WorkflowStep)?.status == .scheduled }) {
                            if let step = messageList[lastIndex] as? WorkflowStep {
                                let updatedStep = WorkflowStep(
                                    status: .executing,
                                    toolName: step.toolName,
                                    details: step.details
                                )
                                messageList[lastIndex] = updatedStep
                            }
                        }
                        updateStatus("⚡ Executing: \(content)", type: .executing)
                    case "tool_results":
                        // Update the most recent executing step to result
                        if let lastIndex = messageList.lastIndex(where: { ($0 as? WorkflowStep)?.status == .executing }) {
                            if let step = messageList[lastIndex] as? WorkflowStep {
                                let updatedStep = WorkflowStep(
                                    status: .result,
                                    toolName: step.toolName,
                                    details: ["result": content]
                                )
                                messageList[lastIndex] = updatedStep
                            }
                        }
                        updateStatus("📊 Processing results...", type: .result)
                    case "response":
                        // If last message is ChatMessage, append content to it; otherwise create new ChatMessage
                        if let lastMessage = messageList.last as? ChatMessage,
                           !lastMessage.isUser {
                            // Append content to existing assistant message
                            let lastIndex = messageList.count - 1
                            let updatedMessage = ChatMessage(
                                content: lastMessage.content + content,
                                isUser: false,
                                timestamp: lastMessage.timestamp,
                                isSystem: lastMessage.isSystem
                            )
                            messageList[lastIndex] = updatedMessage
                        } else {
                            // Create new assistant message
                            let newMessage = ChatMessage(content: content, isUser: false, timestamp: Date())
                            messageList.append(newMessage)
                        }
                    case "error":
                        let errorStep = WorkflowStep(status: .error, toolName: content)
                        messageList.append(errorStep)
                        updateStatus("❌ Error: \(content)", type: .error)
                    case "replace_response":
                        // Replace the last ChatMessage in messageList
                        if let lastIndex = messageList.lastIndex(where: { $0 is ChatMessage }) {
                            let replacementMessage = ChatMessage(content: content, isUser: false, timestamp: Date())
                            messageList[lastIndex] = replacementMessage
                            print("✅ Replaced assistant message: \(String(content.prefix(50)))...")
                        } else {
                            // If no ChatMessage found, add new one
                            let assistantMessage = ChatMessage(content: content, isUser: false, timestamp: Date())
                            messageList.append(assistantMessage)
                            print("✅ Added assistant message: \(String(content.prefix(50)))...")
                        }
                    default:
                        print("Unknown status: \(status)")
                    }
                }
            }
            
            await MainActor.run {
                // Add final status
                let finalStatusMessage = toolCallCount > 0 ? 
                    "Completed. Processed \(toolCallCount) tool call(s)." : "Completed."
                let finalStep = WorkflowStep(status: .finalStatus, toolName: finalStatusMessage)
                messageList.append(finalStep)
                
                updateStatus("✅ \(finalStatusMessage)", type: .finalStatus)
                
                // Reset streaming state
                isStreaming = false
                
                print("🏁 Workflow completed. Final messageList count: \(messageList.count)")
            }
        } catch {
            await MainActor.run {
                let errorStep = WorkflowStep(status: .error, toolName: "Error: \(error.localizedDescription)")
                messageList.append(errorStep)
                updateStatus("❌ Error: \(error.localizedDescription)", type: .error)
                isStreaming = false
            }
        }
    }
    
    private func updateStatus(_ status: String, type: WorkflowStepStatus) {
        currentStatus = status
        statusType = type
    }
    
    private func setupLLMService() {
        guard let providerType = LLMProviderType(rawValue: currentProvider) else {
            print("❌ Invalid provider type: \(currentProvider)")
            return
        }
        
        let config: LLMProviderConfig
        
        switch providerType {
        case .openai:
            config = LLMProviderConfig(
                type: .openai,
                apiKey: openaiApiKey,
                baseURL: openaiBaseUrl.isEmpty ? nil : openaiBaseUrl,
                model: openaiModel.isEmpty ? nil : openaiModel
            )
            print("🔧 OpenAI Configuration:")
            print("  API Key: \(openaiApiKey.isEmpty ? "❌ Not set" : "✅ Set (length: \(openaiApiKey.count))")")
            print("  Base URL: \(openaiBaseUrl.isEmpty ? "✅ Using default (https://api.openai.com)" : "🔧 Custom: \(openaiBaseUrl)")")
            print("  Model: \(openaiModel.isEmpty ? "✅ Using default (gpt-4o-2024-11-20)" : "🔧 Custom: \(openaiModel)")")
            
        case .openRouter:
            config = LLMProviderConfig(
                type: .openRouter,
                apiKey: openrouterApiKey,
                baseURL: openrouterBaseUrl.isEmpty ? nil : openrouterBaseUrl,
                model: openrouterModel.isEmpty ? nil : openrouterModel
            )
            print("🔧 OpenRouter Configuration:")
            print("  API Key: \(openrouterApiKey.isEmpty ? "❌ Not set" : "✅ Set (length: \(openrouterApiKey.count))")")
            print("  Base URL: \(openrouterBaseUrl.isEmpty ? "✅ Using default (https://openrouter.ai/api)" : "🔧 Custom: \(openrouterBaseUrl)")")
            print("  Model: \(openrouterModel.isEmpty ? "✅ Using default (deepseek/deepseek-chat-v3-0324)" : "🔧 Custom: \(openrouterModel)")")
        }
        
        llmService = LLMAIService(config: config)
        print("✅ LLM Service initialized with provider: \(providerType.displayName)")
    }
    
    // MARK: - Voice Recording Methods
    
    private func checkRecordingPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.recordingPermissionGranted = granted
                if granted {
                    print("✅ Recording permission granted")
                } else {
                    print("❌ Recording permission denied")
                }
            }
        }
    }
    
    private func startRecording() {
        guard recordingPermissionGranted else {
            print("❌ Recording permission not granted")
            return
        }
        
        guard !isRecording else { return }
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
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
            print("🎤 Started recording to: \(audioFilename)")
            
        } catch {
            print("❌ Failed to start recording: \(error)")
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        
        print("⏹️ Stopped recording")
        
        // Start transcription
        if let url = recordingURL {
            transcribeAudio(url: url)
        }
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func transcribeAudio(url: URL) {
        guard !openaiApiKey.isEmpty else {
            errorMessage = "OpenAI API key is required for transcription"
            showingError = true
            return
        }
        
        isTranscribing = true
        
        Task {
            do {
                let transcribedText = try await performWhisperTranscription(audioURL: url)
                
                await MainActor.run {
                    isTranscribing = false
                    
                    // Set the transcribed text in input field and send
                    if !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        inputText = transcribedText
                        sendMessage()
                    }
                    
                    // Keep the recording file in /recordings directory for later playback
                    print("✅ Recording saved to: \(url)")
                }
                
            } catch {
                await MainActor.run {
                    isTranscribing = false
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    showingError = true
                    
                    // Keep the recording file even if transcription fails
                    print("⚠️ Transcription failed but recording saved to: \(url)")
                }
            }
        }
    }
    
    private func performWhisperTranscription(audioURL: URL) async throws -> String {
        // Prepare the request
        let baseURL = openaiBaseUrl.isEmpty ? "https://api.openai.com" : openaiBaseUrl
        guard let url = URL(string: "\(baseURL)/v1/audio/transcriptions") else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openaiApiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResponse.statusCode)): \(errorString)"])
        }
        
        // Parse response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            print("✅ Transcription successful: \(String(text.prefix(50)))...")
            return text
        } else {
            throw NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse transcription response"])
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(16)
                    
                    HStack {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if isStreaming {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.secondary)
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ChatView()
} 

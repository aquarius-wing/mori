import SwiftUI
import Combine
import AVFoundation
import Foundation

// MARK: - Chat History Models



struct ChatView2: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("providerConfiguration") private var providerConfigData = Data()
    
    // Chat History Management
    @AppStorage("currentChatHistoryId") private var currentChatHistoryId: String?
    @State private var currentChatHistory: ChatHistory?
    @State private var shouldAutoSave = false
    
    // Legacy support
    @AppStorage("currentProvider") private var currentProvider = "mori-api"
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openaiBaseUrl") private var openaiBaseUrl = ""
    @AppStorage("openaiModel") private var openaiModel = ""
    @AppStorage("openrouterApiKey") private var openrouterApiKey = ""
    @AppStorage("openrouterBaseUrl") private var openrouterBaseUrl = ""
    @AppStorage("openrouterModel") private var openrouterModel = ""
    
    @State private var llmService: LLMAIService?
    
    @State private var messageList: [MessageListItemType] = []
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
    
    // Navigation callbacks
    var onShowMenu: (() -> Void)?
    
    var body: some View {
        VStack {
            // Message list display
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(messageList.enumerated()), id: \.element.id) { index, item in
                            switch item {
                            case .chatMessage(let chatMessage):
                                MessageView(message: chatMessage)
                                    .id(chatMessage.id)
                            case .workflowStep(let workflowStep):
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
                        minimumDuration: 0.5,
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
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Menu button
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    onShowMenu?()
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(isStreaming || isSending)
            }
            
            #if DEBUG
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Debug") {
                    // Single tap action (optional)
                }                
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 10)) // Customize context menu preview
                .contextMenu {
                    Button(action: {
                        // Print messages in view with all properties using JSONEncoder
                        let chatMessages = messageList.compactMap { 
                            if case .chatMessage(let message) = $0 {
                                return message
                            }
                            return nil
                        }
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
                        let requestBody = service.generateRequestBodyJSON(from: messageList)
                        
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
                    
                    Button(action: {
                        router.navigateToOnboarding()
                    }) {
                        Label("Go to Settings", systemImage: "gearshape")
                    }
                }
            }
            #endif
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    createNewChatHistory()
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(isStreaming || isSending)
            }
            
        }
        .onAppear {
            setupLLMService()
            checkRecordingPermission()
            loadCurrentChatHistory()
            
            // Listen for clear chat notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ClearChat"),
                object: nil,
                queue: .main
            ) { _ in
                clearChat()
            }
            
            // Listen for load chat history notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("LoadChatHistory"),
                object: nil,
                queue: .main
            ) { notification in
                if let chatHistory = notification.object as? ChatHistory {
                    loadChatHistory(chatHistory)
                }
            }
        }
        .onDisappear {
            // Remove notification observers
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ClearChat"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("LoadChatHistory"), object: nil)
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
    
    // MARK: - Public Methods
    
    func clearChat() {
        messageList.removeAll()
        currentStatus = "Ready"
        statusType = .finalStatus
    }
    
    func loadChatHistory(_ chatHistory: ChatHistory) {
        // Save current chat if it has messages
        if !messageList.isEmpty, let currentChat = currentChatHistory {
            saveChatHistory(currentChat)
        }
        
        // Load new chat
        currentChatHistory = chatHistory
        currentChatHistoryId = chatHistory.id
        messageList = chatHistory.messageList
        shouldAutoSave = true
        
        print("📚 Loaded chat history: \(chatHistory.title)")
    }
    
    // MARK: - Private Methods
    
    private func sendMessage() {
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty, let service = llmService else { return }
        
        // Clear input field and reset state
        inputText = ""
        isSending = true
        updateStatus("Processing request...", type: .llmThinking)
        
        // Add user message
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messageList.append(.chatMessage(userMessage))
        
        // Ensure we have a current chat history
        if currentChatHistory == nil {
            createNewChatHistoryFromCurrentMessages()
        }
        
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
                    messageList.append(.workflowStep(errorStep))
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
            let stream = service.sendChatMessageWithTools(conversationHistory: messageList)
            
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
                        messageList.append(.workflowStep(toolCallStep))
                        updateStatus("⏰ Scheduling tool: \(content)", type: .scheduled)
                    case "tool_arguments":
                        // Update the most recent scheduled step with arguments
                        if let lastIndex = messageList.lastIndex(where: { 
                            if case .workflowStep(let step) = $0 {
                                return step.status == .scheduled
                            }
                            return false
                        }) {
                            if case .workflowStep(let step) = messageList[lastIndex] {
                                let updatedStep = WorkflowStep(
                                    status: .scheduled,
                                    toolName: step.toolName,
                                    details: ["tool_name": step.details["tool_name"] ?? "", "arguments": content]
                                )
                                messageList[lastIndex] = .workflowStep(updatedStep)
                            }
                        }
                    case "tool_execution":
                        // Update the most recent scheduled step to executing
                        if let lastIndex = messageList.lastIndex(where: { 
                            if case .workflowStep(let step) = $0 {
                                return step.status == .scheduled
                            }
                            return false
                        }) {
                            if case .workflowStep(let step) = messageList[lastIndex] {
                                let updatedStep = WorkflowStep(
                                    status: .executing,
                                    toolName: step.toolName,
                                    details: step.details
                                )
                                messageList[lastIndex] = .workflowStep(updatedStep)
                            }
                        }
                        updateStatus("⚡ Executing: \(content)", type: .executing)
                    case "tool_results":
                        // Update the most recent executing step to result
                        if let lastIndex = messageList.lastIndex(where: { 
                            if case .workflowStep(let step) = $0 {
                                return step.status == .executing
                            }
                            return false
                        }) {
                            if case .workflowStep(let step) = messageList[lastIndex] {
                                let updatedStep = WorkflowStep(
                                    status: .result,
                                    toolName: step.toolName,
                                    details: ["result": content]
                                )
                                messageList[lastIndex] = .workflowStep(updatedStep)
                            }
                        }
                        updateStatus("📊 Processing results...", type: .result)
                    case "response":
                        // If last message is ChatMessage, append content to it; otherwise create new ChatMessage
                        if case .chatMessage(let lastMessage) = messageList.last,
                           !lastMessage.isUser {
                            // Append content to existing assistant message
                            let lastIndex = messageList.count - 1
                            let updatedMessage = ChatMessage(
                                content: lastMessage.content + content,
                                isUser: false,
                                timestamp: lastMessage.timestamp,
                                isSystem: lastMessage.isSystem
                            )
                            messageList[lastIndex] = .chatMessage(updatedMessage)
                        } else {
                            // Create new assistant message
                            let newMessage = ChatMessage(content: content, isUser: false, timestamp: Date())
                            messageList.append(.chatMessage(newMessage))
                        }
                    case "error":
                        let errorStep = WorkflowStep(status: .error, toolName: content)
                        messageList.append(.workflowStep(errorStep))
                        updateStatus("❌ Error: \(content)", type: .error)
                    case "replace_response":
                        // Replace the last ChatMessage in messageList
                        if let lastIndex = messageList.lastIndex(where: { 
                            if case .chatMessage(_) = $0 { return true }
                            return false
                        }) {
                            let replacementMessage = ChatMessage(content: content, isUser: false, timestamp: Date())
                            messageList[lastIndex] = .chatMessage(replacementMessage)
                            print("✅ Replaced assistant message: \(String(content.prefix(50)))...")
                        } else {
                            // If no ChatMessage found, add new one
                            let assistantMessage = ChatMessage(content: content, isUser: false, timestamp: Date())
                            messageList.append(.chatMessage(assistantMessage))
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
                messageList.append(.workflowStep(finalStep))
                
                updateStatus("✅ \(finalStatusMessage)", type: .finalStatus)
                
                // Reset streaming state
                isStreaming = false
                
                print("🏁 Workflow completed. Final messageList count: \(messageList.count)")
                
                // Auto-save current chat history
                if shouldAutoSave, let currentChat = currentChatHistory {
                    saveChatHistoryAsync(currentChat)
                }
            }
        } catch {
            await MainActor.run {
                let errorStep = WorkflowStep(status: .error, toolName: "Error: \(error.localizedDescription)")
                messageList.append(.workflowStep(errorStep))
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
        // Simple initialization - no configuration needed
        llmService = LLMAIService()
        print("✅ LLM Service initialized with fixed endpoints")
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
        guard let service = llmService else {
            errorMessage = "LLM service not available for transcription"
            showingError = true
            return
        }
        
        isTranscribing = true
        
        Task {
            do {
                let audioData = try Data(contentsOf: url)
                let transcribedText = try await service.transcribeAudio(data: audioData)
                
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
    

    // MARK: - Chat History Management Methods
    
    private func getChatHistoryDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("chatHistorys")
    }
    
    private func ensureChatHistoryDirectoryExists() {
        let chatHistoryDir = getChatHistoryDirectory()
        if !FileManager.default.fileExists(atPath: chatHistoryDir.path) {
            try? FileManager.default.createDirectory(at: chatHistoryDir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    private func loadCurrentChatHistory() {
        guard let historyId = currentChatHistoryId else {
            print("🆕 No current chat history ID - starting fresh")
            return
        }
        
        ensureChatHistoryDirectoryExists()
        let chatHistoryDir = getChatHistoryDirectory()
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(historyId).json")
        
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("⚠️ Chat history file not found for ID: \(historyId)")
            currentChatHistoryId = nil
            return
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let chatHistory = try decoder.decode(ChatHistory.self, from: data)
            currentChatHistory = chatHistory
            messageList = chatHistory.messageList
            shouldAutoSave = true
            print("📚 Loaded chat history: \(chatHistory.title)")
        } catch {
            print("❌ Failed to load chat history: \(error)")
            currentChatHistoryId = nil
        }
    }
    
    private func saveChatHistory(_ chatHistory: ChatHistory) {
        ensureChatHistoryDirectoryExists()
        let chatHistoryDir = getChatHistoryDirectory()
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(chatHistory.id).json")
        
        do {
            var updatedChatHistory = chatHistory
            updatedChatHistory.messageList = messageList
            updatedChatHistory.updateDate = Date()
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(updatedChatHistory)
            try data.write(to: filePath)
            
            // Update current chat history
            currentChatHistory = updatedChatHistory
            
            print("💾 Saved chat history: \(updatedChatHistory.title)")
        } catch {
            print("❌ Failed to save chat history: \(error)")
        }
    }
    
    private func saveChatHistoryAsync(_ chatHistory: ChatHistory) {
        Task.detached {
            await MainActor.run { [chatHistory] in
                // We need to call static method since we can't capture self in struct
                ChatView2.saveChatHistoryStatic(chatHistory)
            }
        }
    }
    
    private static func saveChatHistoryStatic(_ chatHistory: ChatHistory) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chatHistoryDir = documentsPath.appendingPathComponent("chatHistorys")
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: chatHistoryDir.path) {
            try? FileManager.default.createDirectory(at: chatHistoryDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(chatHistory.id).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(chatHistory)
            try data.write(to: filePath)
            
            print("💾 Saved chat history: \(chatHistory.title)")
        } catch {
            print("❌ Failed to save chat history: \(error)")
        }
    }
    
    private func createNewChatHistory() {
        // Save current chat if it has messages
        if !messageList.isEmpty, let currentChat = currentChatHistory {
            saveChatHistory(currentChat)
        }
        
        // Create new chat
        let newChatHistory = ChatHistory()
        currentChatHistory = newChatHistory
        currentChatHistoryId = newChatHistory.id
        messageList.removeAll()
        currentStatus = "Ready"
        statusType = .finalStatus
        shouldAutoSave = true
        
        print("🆕 Created new chat history: \(newChatHistory.title)")
    }
    
    private func createNewChatHistoryFromCurrentMessages() {
        let newChatHistory = ChatHistory(messageList: messageList)
        currentChatHistory = newChatHistory
        currentChatHistoryId = newChatHistory.id
        shouldAutoSave = true
        
        print("🆕 Created new chat history from current messages: \(newChatHistory.title)")
    }
    
    static func loadAllChatHistories() -> [ChatHistory] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chatHistoryDir = documentsPath.appendingPathComponent("chatHistorys")
        
        guard FileManager.default.fileExists(atPath: chatHistoryDir.path) else {
            return []
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: chatHistoryDir, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("chatHistory_") }
            
            var chatHistories: [ChatHistory] = []
            
            for fileURL in jsonFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let chatHistory = try decoder.decode(ChatHistory.self, from: data)
                    chatHistories.append(chatHistory)
                } catch {
                    print("❌ Failed to load chat history from \(fileURL.lastPathComponent): \(error)")
                }
            }
            
            // Sort by update date descending
            return chatHistories.sorted { $0.updateDate > $1.updateDate }
        } catch {
            print("❌ Failed to read chat history directory: \(error)")
            return []
        }
    }
    
    static func deleteChatHistory(_ chatHistory: ChatHistory) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chatHistoryDir = documentsPath.appendingPathComponent("chatHistorys")
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(chatHistory.id).json")
        
        do {
            try FileManager.default.removeItem(at: filePath)
            print("🗑️ Deleted chat history: \(chatHistory.title)")
        } catch {
            print("❌ Failed to delete chat history: \(error)")
        }
    }
    
    static func renameChatHistory(_ chatHistory: ChatHistory, newTitle: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let chatHistoryDir = documentsPath.appendingPathComponent("chatHistorys")
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(chatHistory.id).json")
        
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var updatedChatHistory = try decoder.decode(ChatHistory.self, from: data)
            updatedChatHistory.title = newTitle
            updatedChatHistory.updateDate = Date()
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let updatedData = try encoder.encode(updatedChatHistory)
            try updatedData.write(to: filePath)
            
            print("✏️ Renamed chat history to: \(newTitle)")
        } catch {
            print("❌ Failed to rename chat history: \(error)")
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(AppRouter())
} 

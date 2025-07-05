import Combine
import Foundation
import SwiftUI
import AVFoundation

struct ChatView: View {
    // LLM Service and chat management
    @State private var llmService: LLMAIService?
    @State private var messageList: [MessageListItemType]
    @State private var currentStatus = "Ready"
    @State private var statusType: WorkflowStepStatus = .finalStatus
    @State private var isStreaming = false
    @State private var isSending = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingErrorDetail = false
    @State private var errorDetail = ""
    @State private var showingFilesView = false
    @State private var debugActionSheet = false

    // Recording states for AudioRecordingButton
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var recordingPermissionGranted = true
    @State private var recordingError: String?
    @State private var showRecordingError = false
    @State private var isDraggedToCancel = false

    // Chat History Management
    private let chatHistoryManager = ChatHistoryManager()
    @State private var currentChatId: String?
    @AppStorage("currentChatHistoryId") private var savedChatHistoryId: String?

    // Legacy ChatItem support for UI compatibility
    private var chatItems: [ChatItem] {
        return messageList.map { item in
            switch item {
            case .chatMessage(let chatMessage):
                return .message(chatMessage)
            case .workflowStep(let workflowStep):
                return .workflowStep(workflowStep)
            }
        }
    }

    @State private var inputText = ""
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool

    // Navigation callbacks
    var onShowMenu: (() -> Void)?

    // MARK: - Properties for Cancel Zone Detection
    @State private var cancelZoneFrame: CGRect = .zero
    @State private var screenSize: CGSize = .zero

    // MARK: - Initializer
    init(
        initialMessages: [MessageListItemType] = [],
        onShowMenu: (() -> Void)? = nil
    ) {
        self._messageList = State(initialValue: initialMessages)
        self.onShowMenu = onShowMenu
    }
    
    // Convenience initializer for preview with recording states
    init(
        initialMessages: [MessageListItemType] = [],
        onShowMenu: (() -> Void)? = nil,
        isRecording: Bool = false,
        isTranscribing: Bool = false,
        recordingPermissionGranted: Bool = true,
        recordingError: String? = nil,
        showRecordingError: Bool = false,
        isDraggedToCancel: Bool = false
    ) {
        self._messageList = State(initialValue: initialMessages)
        self.onShowMenu = onShowMenu
        // Set initial recording states
        self._isRecording = State(initialValue: isRecording)
        self._isTranscribing = State(initialValue: isTranscribing)
        self._recordingPermissionGranted = State(initialValue: recordingPermissionGranted)
        self._recordingError = State(initialValue: recordingError)
        self._showRecordingError = State(initialValue: showRecordingError)
        self._isDraggedToCancel = State(initialValue: isDraggedToCancel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Chat messages area
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(chatItems) { item in
                                        let copyAction = {
                                            if case .message(let message) = item {
                                                copyMessage(message.content)
                                            } else {
                                                copyLastMessage()
                                            }
                                        }
                                        
                                                                let retryAction = {
                            // Find the corresponding MessageListItemType to retry from
                            if let messageListItem = messageList.first(where: { listItem in
                                listItem.id == item.id
                            }) {
                                retryFromItem(messageListItem)
                            }
                        }
                                        
                                        let showErrorAction = {
                                            showingErrorDetail = true
                                        }
                                        
                                        ChatItemView(
                                            item: item,
                                            onCopy: copyAction,
                                            onLike: likeMessage,
                                            onDislike: dislikeMessage,
                                            onRetry: retryAction,
                                            onShowErrorDetail: showErrorAction,
                                            errorDetail: errorDetail
                                        )
                                        .id(item.id)
                                    }

                                    if isStreaming || isSending {
                                        HStack {
                                            ProgressView()
                                                .progressViewStyle(
                                                    CircularProgressViewStyle(
                                                        tint: .white
                                                    )
                                                )
                                                .scaleEffect(0.8)
                                            Text(currentStatus)
                                                .font(.caption)
                                                .foregroundColor(
                                                    .white.opacity(0.7)
                                                )
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                .padding(.vertical, 20)
                                .padding(.bottom, 0)
                            }
                            .onChange(of: chatItems.count) { _, _ in
                                if let lastItem = chatItems.last {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo(lastItem.id, anchor: .bottom)
                                    }
                                }
                            }
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        // Dismiss keyboard when tapping on chat area
                                        isTextFieldFocused = false
                                    }
                            )
                        }

                        // Input area
                        VStack(spacing: 0) {
                            // Input field
                            VStack(spacing: 16) {
                                TextField(
                                    "Input message...",
                                    text: $inputText,
                                    axis: .vertical
                                )
                                .textFieldStyle(.plain)
                                .lineLimit(1...5)
                                .foregroundColor(.white)
                                .accentColor(.white)
                                .focused($isTextFieldFocused)
                                .disabled(isSending || isStreaming)

                                HStack(spacing: 12) {
                                    Spacer()
                                    
                                    // Audio Recording Button
                                    HStack(spacing: 12) {
                                        AudioRecordingButton(
                                            llmService: llmService,
                                            onTranscriptionComplete: { transcribedText in
                                                inputText += transcribedText
                                            },
                                            onError: { error in
                                                // Check if this is a recording-specific error
                                                if error.contains("too short") || error.contains("duration") {
                                                    recordingError = error
                                                    showRecordingError = true
                                                } else {
                                                    errorMessage = error
                                                    showingError = true
                                                }
                                            },
                                            isDisabled: isSending || isStreaming,
                                            cancelZoneFrame: cancelZoneFrame,
                                            isRecording: $isRecording,
                                            isTranscribing: $isTranscribing,
                                            recordingPermissionGranted: $recordingPermissionGranted,
                                            isDraggedToCancel: $isDraggedToCancel
                                        )
                                    }
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(16)
                                    .contentShape(Rectangle())
                                    
                                    // Send/Stop Button
                                    Button(action: isStreaming ? stopStreaming : handleSendMessage) {
                                        Image(
                                            systemName: isStreaming ? "stop.fill" : (isSending ? "hourglass" : "arrow.up")
                                        )
                                        .foregroundColor(.white)
                                    }
                                    .frame(width: 32, height: 32)
                                    .background(
                                        isStreaming ? Color.red : (
                                            inputText.trimmingCharacters(
                                                in: .whitespacesAndNewlines
                                            ).isEmpty || isSending
                                                ? Color.gray : Color.blue
                                        )
                                    )
                                    .cornerRadius(16)
                                    .contentShape(Rectangle())
                                    .disabled(
                                        !isStreaming && (
                                            inputText.trimmingCharacters(
                                                in: .whitespacesAndNewlines
                                            ).isEmpty || isSending
                                        )
                                    )
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Focus on TextField when tapping on the VStack area
                                isTextFieldFocused = true
                            }
                            .overlay(
                                // Floating gray rectangle
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: geometry.safeAreaInsets.bottom)
                                    .frame(width: geometry.size.width)
                                    .offset(y: geometry.safeAreaInsets.bottom + 12),
                                alignment: .bottom
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 20,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 20
                                )
                                .fill(Color.white.opacity(0.1))
                            )
                        }
                    }
                }
                
                // Recording Status Overlay - centered on screen
                if isRecording || isTranscribing {
                    recordingStatusOverlay
                        .zIndex(1000)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isRecording)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTranscribing)
                }
                
                // Recording Error Overlay - centered on screen
                if showRecordingError {
                    recordingErrorOverlay
                        .zIndex(1001)
                        .allowsHitTesting(true)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showRecordingError)
                }
            }
            .navigationTitle("Mori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            isTextFieldFocused = false
                            onShowMenu?()
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.body)
                                .foregroundColor(.white)
                        }
                        .disabled(isStreaming || isSending)
                    }
                }

#if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Debug") {
                        debugActionSheet = true
                    }
                    .disabled(isStreaming || isSending)
                }
#endif

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        createNewChat()
                    }) {
                        Image(systemName: "message")
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .disabled(isStreaming || isSending)
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            setupLLMService()
            loadCurrentChatHistory()

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

            // Listen for clear chat notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ClearChat"),
                object: nil,
                queue: .main
            ) { _ in
                clearChat()
            }
        }
        .onDisappear {
            // Remove notification observers
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("LoadChatHistory"),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("ClearChat"),
                object: nil
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingErrorDetail) {
            ErrorDetailView(errorDetail: errorDetail)
        }
        .sheet(isPresented: $showingFilesView) {
            FilesView()
        }
        .confirmationDialog("Debug Options", isPresented: $debugActionSheet) {
            Button("Print Messages in View") {
                printMessagesInView()
            }
            
            Button("Print Request Body") {
                printRequestBody()
            }
            
            Button("View Recording Files") {
                showingFilesView = true
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Recording Status Overlay
    
    @ViewBuilder
    private var recordingStatusOverlay: some View {
        if isRecording {
            // Cancel zone
            VStack(spacing: 12) {
                // Recording animation with cancel icon overlay
                ZStack {
                    Circle()
                        .fill((isDraggedToCancel ? Color.orange : Color.red).opacity(0.2))
                        .frame(width: 60, height: 60)
                        .scaleEffect(isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                        .animation(.easeInOut(duration: 0.2), value: isDraggedToCancel)
                    
                    Image(systemName: isDraggedToCancel ? "xmark" : "mic.fill")
                        .font(.title2)
                        .foregroundColor(isDraggedToCancel ? .orange : .red)
                        .animation(.easeInOut(duration: 0.2), value: isDraggedToCancel)
                }
                
                VStack(spacing: 4) {
                    Text("Recording...")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(isDraggedToCancel ? Color.orange : Color.white)
                        .animation(.easeInOut(duration: 0.2), value: isDraggedToCancel)
                    
                    Text("Drag here to cancel")
                        .font(.caption)
                        .foregroundColor((isDraggedToCancel ? Color.orange : Color.white).opacity(0.7))
                        .animation(.easeInOut(duration: 0.2), value: isDraggedToCancel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke((isDraggedToCancel ? Color.orange : Color.white).opacity(isDraggedToCancel ? 0.6 : 0.3), lineWidth: isDraggedToCancel ? 3 : 2)
                                .animation(.easeInOut(duration: 0.2), value: isDraggedToCancel)
                        )
                        .onAppear {
                            // Calculate cancel zone frame in global coordinates
                            let localFrame = geo.frame(in: .local)
                            let globalFrame = geo.frame(in: .global)
                            cancelZoneFrame = globalFrame
                            print("📍 Cancel zone frame: \(globalFrame)")
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            cancelZoneFrame = newFrame
                        }
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .scaleEffect(isDraggedToCancel ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isDraggedToCancel)
            
        } else if isTranscribing {
            VStack(spacing: 12) {
                // Transcribing animation
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)
                
                VStack(spacing: 4) {
                    Text("Transcribing...")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Processing audio...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
    
    // MARK: - Recording Error Overlay
    
    @ViewBuilder
    private var recordingErrorOverlay: some View {
        if let error = recordingError {
            VStack(spacing: 12) {
                // Error icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(spacing: 4) {
                    Text("Recording Error")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                // Dismiss button
                Button("OK") {
                    recordingError = nil
                    showRecordingError = false
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }

    // MARK: - Private Methods

    private func printMessagesInView() {
        let messageListCloned = messageList
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(messageListCloned)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📋 ChatMessages in View JSON:")
                print(jsonString)
            }
        } catch {
            print("❌ Failed to serialize messages to JSON: \(error)")
        }
    }
    
    private func printRequestBody() {
        guard let service = llmService else {
            print("❌ LLM service not available")
            return
        }
        let messageListCloned = messageList
        
        let requestBody = service.generateRequestBodyJSON(from: messageListCloned)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [.prettyPrinted, .sortedKeys])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 Request Body JSON:")
                print(jsonString)
            }
        } catch {
            print("❌ Failed to serialize request body to JSON: \(error)")
        }
    }

    private func setupLLMService() {
        // Simple initialization - no configuration needed
        llmService = LLMAIService()
        print("✅ LLM Service initialized")
    }

    private func appendChatMessage() -> Bool {
        let messageText = inputText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !messageText.isEmpty, llmService != nil else { return false }
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messageList.append(.chatMessage(userMessage))
        inputText = ""
        return true
    }

    private func handleSendMessage() {
        if appendChatMessage() {
            sendMessage()
        }
    }

    private func sendMessage() {
        guard let service = llmService else { return }
        
        isSending = true
        updateStatus("Processing request...", type: .llmThinking)

        // Ensure we have a chat ID for this session
        if currentChatId == nil {
            currentChatId = chatHistoryManager.createNewChat()
            savedChatHistoryId = currentChatId
            print(
                "🆕 Created new chat for user message with ID: \(currentChatId ?? "unknown")"
            )
        }

        Task {
            do {
                await MainActor.run {
                    isSending = false
                    isStreaming = true
                }

                print(
                    "📨 Starting workflow with \(messageList.count) items in messageList"
                )

                // Process real tool calling workflow
                await processRealToolWorkflow(using: service)

            } catch is CancellationError {
                await MainActor.run {
                    print("🛑 Send message was cancelled by user")
                    isSending = false
                    isStreaming = false
                    updateStatus("Cancelled by user", type: .finalStatus)
                }
            } catch {
                await MainActor.run {
                    // Create detailed error information
                    let fullErrorDetail = "\(error)"
                    let shortErrorMessage = error.localizedDescription
                    
                    let errorStep = WorkflowStep(
                        status: .error,
                        toolName: "API Error",
                        details: [
                            "error_type": "API Request Failed",
                            "short_message": shortErrorMessage,
                            "full_details": fullErrorDetail
                        ]
                    )
                    messageList.append(.workflowStep(errorStep))
                    updateStatus(
                        "Error: \(shortErrorMessage)",
                        type: .error
                    )
                    isSending = false
                    isStreaming = false
                    // Save complete error detail
                    errorDetail = fullErrorDetail
                }
            }
        }
    }
    
    private func stopStreaming() {
        print("🛑 User requested to stop streaming")
        llmService?.cancelStreaming()
        
        // Reset streaming state
        isStreaming = false
        isSending = false
        updateStatus("Stopped by user", type: .finalStatus)
        
        // Save current chat history
        saveCurrentChatHistory()
    }

    private func processRealToolWorkflow(
        using service: LLMAIService
    ) async {
        var toolCallCount = 0

        do {
            // Simple shallow clone of the message list
            let messageListCloned = messageList
            let stream = service.sendChatMessageWithTools(
                conversationHistory: messageListCloned
            )

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
                            details: [
                                "tool_name": content, "arguments": "Pending...",
                            ]
                        )
                        messageList.append(.workflowStep(toolCallStep))
                        updateStatus(
                            "⏰ Scheduling tool: \(content)",
                            type: .scheduled
                        )
                    case "tool_arguments":
                        // Update the most recent scheduled step with arguments
                        if let lastIndex = messageList.lastIndex(where: {
                            if case .workflowStep(let step) = $0 {
                                return step.status == .scheduled
                            }
                            return false
                        }) {
                            if case .workflowStep(let step) = messageList[
                                lastIndex
                            ] {
                                let updatedStep = WorkflowStep(
                                    status: .scheduled,
                                    toolName: step.toolName,
                                    details: [
                                        "tool_name": step.details["tool_name"]
                                            ?? "", "arguments": content,
                                    ]
                                )
                                messageList[lastIndex] = .workflowStep(
                                    updatedStep
                                )
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
                            if case .workflowStep(let step) = messageList[
                                lastIndex
                            ] {
                                let updatedStep = WorkflowStep(
                                    status: .executing,
                                    toolName: step.toolName,
                                    details: step.details
                                )
                                messageList[lastIndex] = .workflowStep(
                                    updatedStep
                                )
                            }
                        }
                        updateStatus(
                            "⚡ Executing: \(content)",
                            type: .executing
                        )
                    case "tool_results":
                        // Update the most recent executing step to result
                        if let lastIndex = messageList.lastIndex(where: {
                            if case .workflowStep(let step) = $0 {
                                return step.status == .executing
                            }
                            return false
                        }) {
                            if case .workflowStep(let step) = messageList[
                                lastIndex
                            ] {
                                let updatedStep = WorkflowStep(
                                    status: .result,
                                    toolName: step.toolName,
                                    details: ["result": content]
                                )
                                messageList[lastIndex] = .workflowStep(
                                    updatedStep
                                )
                            }
                        }
                        updateStatus("📊 Processing results...", type: .result)
                    case "response":
                        // If last message is ChatMessage, append content to it; otherwise create new ChatMessage
                        if case .chatMessage(let lastMessage) = messageList.last,
                            !lastMessage.isUser
                        {
                            // Append content to existing assistant message
                            let lastIndex = messageList.count - 1
                            let updatedMessage = ChatMessage(
                                content: lastMessage.content + content,
                                isUser: false,
                                timestamp: lastMessage.timestamp,
                                isSystem: lastMessage.isSystem
                            )
                            messageList[lastIndex] = .chatMessage(
                                updatedMessage
                            )
                        } else {
                            // Create new assistant message
                            let newMessage = ChatMessage(
                                content: content,
                                isUser: false,
                                timestamp: Date()
                            )
                            messageList.append(.chatMessage(newMessage))
                        }
                    case "error":
                        let errorStep = WorkflowStep(
                            status: .error,
                            toolName: "Stream Error",
                            details: [
                                "error_type": "Streaming Error",
                                "short_message": content,
                                "full_details": content
                            ]
                        )
                        messageList.append(.workflowStep(errorStep))
                        updateStatus("❌ Error: \(content)", type: .error)
                        // Save error detail for sheet display
                        errorDetail = content
                    case "replace_response":
                        // Replace the last ChatMessage in messageList
                        if let lastIndex = messageList.lastIndex(where: {
                            if case .chatMessage(let chatMessage) = $0 { 
                                return !chatMessage.isUser // Only replace assistant messages
                            }
                            return false
                        }) {
                            // Check if content is empty after trimming
                            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmedContent.isEmpty {
                                // Remove the message if content is empty
                                messageList.remove(at: lastIndex)
                                print("🗑️ Removed empty assistant message")
                            } else {
                                // Replace with new content
                                let replacementMessage = ChatMessage(
                                    content: content,
                                    isUser: false,
                                    timestamp: Date()
                                )
                                messageList[lastIndex] = .chatMessage(
                                    replacementMessage
                                )
                                print(
                                    "✅ Replaced assistant message: \(String(content.prefix(50)))..."
                                )
                            }
                        } else {
                            // If no assistant ChatMessage found, add new one (only if content is not empty)
                            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedContent.isEmpty {
                                let assistantMessage = ChatMessage(
                                    content: content,
                                    isUser: false,
                                    timestamp: Date()
                                )
                                messageList.append(.chatMessage(assistantMessage))
                                print(
                                    "✅ Added assistant message: \(String(content.prefix(50)))..."
                                )
                            } else {
                                print("⚠️ Skipped adding empty assistant message")
                            }
                        }
                    default:
                        print("Unknown status: \(status)")
                    }
                }
            }

            await MainActor.run {
                // Add final status
                let finalStatusMessage =
                    toolCallCount > 0
                    ? "Completed. Processed \(toolCallCount) tool call(s)."
                    : "Completed."
                // let finalStep = WorkflowStep(
                //     status: .finalStatus,
                //     toolName: finalStatusMessage
                // )
                // messageList.append(.workflowStep(finalStep))

                updateStatus("✅ \(finalStatusMessage)", type: .finalStatus)

                // Reset streaming state
                isStreaming = false
                isSending = false

                print(
                    "🏁 Workflow completed. Final messageList count: \(messageList.count)"
                )

                // Auto-save current chat history
                saveCurrentChatHistory()
            }
        } catch is CancellationError {
            await MainActor.run {
                print("🛑 Workflow was cancelled by user")
                isStreaming = false
                isSending = false
                updateStatus("Cancelled by user", type: .finalStatus)
                saveCurrentChatHistory()
            }
        } catch {
            await MainActor.run {
                // Create detailed error information
                let fullErrorDetail = "\(error)"
                let shortErrorMessage = error.localizedDescription
                
                let errorStep = WorkflowStep(
                    status: .error,
                    toolName: "Workflow Error",
                    details: [
                        "error_type": "Workflow Execution Failed",
                        "short_message": shortErrorMessage,
                        "full_details": fullErrorDetail
                    ]
                )
                messageList.append(.workflowStep(errorStep))
                updateStatus(
                    "❌ Error: \(shortErrorMessage)",
                    type: .error
                )
                isStreaming = false
                isSending = false
                showingError = true
                errorMessage = shortErrorMessage
                // Save complete error detail
                errorDetail = fullErrorDetail
                saveCurrentChatHistory()
            }
        }
    }

    private func updateStatus(_ status: String, type: WorkflowStepStatus) {
        currentStatus = status
        statusType = type
    }

    private func copyMessage(_ content: String) {
        UIPasteboard.general.string = content
    }

    private func copyLastMessage() {
        // Find the last assistant message and copy it
        for item in messageList.reversed() {
            if case .chatMessage(let message) = item, !message.isUser {
                copyMessage(message.content)
                break
            }
        }
    }

    private func likeMessage() {
        // Implement like functionality
        print("👍 Message liked")
    }

    private func dislikeMessage() {
        // Implement dislike functionality
        print("👎 Message disliked")
    }

    // MARK: - Chat History Management Methods

    private func loadCurrentChatHistory() {
        guard let historyId = savedChatHistoryId else {
            print("🆕 No saved chat history ID - starting fresh")
            return
        }

        if let loadedMessages = chatHistoryManager.loadChat(id: historyId) {
            currentChatId = historyId
            messageList = loadedMessages
            print("📚 Loaded chat history with ID: \(historyId)")
        } else {
            print("⚠️ Chat history not found for ID: \(historyId)")
            savedChatHistoryId = nil
        }
    }

    private func saveCurrentChatHistory() {
        // Create new chat if needed
        if currentChatId == nil && !messageList.isEmpty {
            currentChatId = chatHistoryManager.createNewChat()
        }

        // Save if we have messages
        if !messageList.isEmpty {
            let savedId = chatHistoryManager.saveCurrentChat(
                messageList,
                existingId: currentChatId
            )
            currentChatId = savedId
            savedChatHistoryId = savedId
            print("💾 Saved chat history with ID: \(savedId)")
        }
    }

    private func loadChatHistory(_ chatHistory: ChatHistory) {
        // No need saveCurrentChatHistory here
        // because already saved after response

        // Load new chat
        currentChatId = chatHistory.id
        savedChatHistoryId = chatHistory.id
        messageList = chatHistory.messageList

        print("📚 Loaded chat history: \(chatHistory.title)")
    }

    private func clearChat() {
        messageList.removeAll()
        currentStatus = "Ready"
        statusType = .finalStatus
        inputText = ""

        print("🧹 Cleared current chat")
    }

    private func createNewChat() {
        // Save current chat if it has messages
        if !messageList.isEmpty {
            saveCurrentChatHistory()
        }

        // Create new chat
        currentChatId = chatHistoryManager.createNewChat()
        savedChatHistoryId = currentChatId

        // Clear current chat
        messageList.removeAll()
        currentStatus = "Ready"
        statusType = .finalStatus
        inputText = ""

        print("🆕 Created new chat with ID: \(currentChatId ?? "unknown")")
    }

    private func retryFromItem(_ item: MessageListItemType) {
        // Find the index of the item to retry from
        guard let itemIndex = messageList.firstIndex(where: { listItem in
            listItem.id == item.id
        }) else {
            print("⚠️ Item not found for retry")
            return
        }

        // Determine removal strategy and find content to retry
        let removalStartIndex: Int
        switch item {
        case .chatMessage(_):
            // For chat messages, remove items after this message (> index)
            removalStartIndex = itemIndex + 1
        case .workflowStep(_):
            // For workflow steps, find the preceding user message first
            removalStartIndex = itemIndex
        }

        if removalStartIndex < messageList.count {
            let removedCount = messageList.count - removalStartIndex
            messageList.removeSubrange(removalStartIndex...)

            print("🔄 Retrying from chat message, will remove items after index \(removalStartIndex)")
            print("🔄 Removed \(removedCount) items for retry")
        }

        // Reset state
        currentStatus = "Ready"
        statusType = .finalStatus
        isStreaming = false
        isSending = false

        // Trigger send
        sendMessage()
    }
}

#Preview {
    ChatView()
        .preferredColorScheme(.dark)
}

#Preview("Chat with Sample Data") {
    ChatView(initialMessages: [
        // User asks about calendar
        .chatMessage(
            ChatMessage(content: "What's on my calendar today?", isUser: true)
        ),

        // Calendar workflow
        .workflowStep(
            WorkflowStep(
                status: .scheduled,
                toolName: "read-calendar",
                details: [
                    "tool_name": "read-calendar",
                    "arguments": "Searching today's events...",
                ]
            )
        ),
        .workflowStep(
            WorkflowStep(
                status: .executing,
                toolName: "read-calendar",
                details: [
                    "tool_name": "read-calendar"
                ]
            )
        ),
        .workflowStep(
            WorkflowStep(
                status: .result,
                toolName: "read-calendar",
                details: [
                    "result": """
                    {
                        "success": true,
                        "count": 2,
                        "date_range": {
                            "startDate": "2024-01-15T00:00:00+08:00",
                            "endDate": "2024-01-15T23:59:59+08:00"
                        },
                        "events": [
                            {
                                "id": "1",
                                "title": "Team Meeting",
                                "start_date": "2024-01-15T10:00:00+08:00",
                                "end_date": "2024-01-15T11:00:00+08:00",
                                "location": "Conference Room A",
                                "notes": "Weekly sync meeting",
                                "is_all_day": false
                            },
                            {
                                "id": "2",
                                "title": "Project Review",
                                "start_date": "2024-01-15T15:00:00+08:00",
                                "end_date": "2024-01-15T16:30:00+08:00",
                                "location": "Online",
                                "notes": "Q1 progress review",
                                "is_all_day": false
                            }
                        ]
                    }
                    """
                ]
            )
        ),

        // AI response
        .chatMessage(
            ChatMessage(
                content:
                    "I found 2 events on your calendar today:\n\n• **Team Meeting** at 10:00 AM\n  📍 Conference Room A\n  Weekly sync meeting\n\n• **Project Review** at 3:00 PM\n  📍 Online\n  Q1 progress review\n\nWould you like me to help with anything else?",
                isUser: false
            )
        ),

        // User asks to add reminder
        .chatMessage(
            ChatMessage(
                content: "Add a 15-minute reminder for the team meeting",
                isUser: true
            )
        ),

        // Update calendar workflow
        .workflowStep(
            WorkflowStep(
                status: .result,
                toolName: "update-calendar",
                details: [
                    "result": """
                    {
                        "success" : true,
                        "message" : "Event created successfully",
                        "event" : {
                            "location" : "",
                            "start_date" : "2025-06-24T02:15:00+08:00",
                            "notes" : "核心升级点：\n• 🏠 智能家居中枢\n• 🧘 身心健康教练\n• 🎯 生活目标管理系统\n• 🛒 消费决策参谋\nSlogan候选：\n1. 「你的数字生活另一半」\n2. 「从起床到入睡的全域AI伴侣」\n3. 「Mori：让理想生活自动运行」",
                            "title" : "🔄 项目升级：Mori-AI生活合伙人",
                            "id" : "FE8FFBDB-EBB4-4C97-AE03-298352BBD38C:7F1D1AC3-D693-4AE8-B1BA-D8D8D7212F80",
                            "is_all_day" : false,
                            "end_date" : "2025-06-24T02:30:00+08:00"
                        }
                    }
                    """
                ]
            )
        ),

        .workflowStep(
            WorkflowStep(
                status: .result,
                toolName: "add-calendar",
                details: [
                    "result": """
                    {
                        "success" : true,
                        "message" : "Add Event created successfully",
                        "event" : {
                            "location" : "",
                            "start_date" : "2025-06-24T02:15:00+08:00",
                            "notes" : "核心升级点：\n• 🏠 智能家居中枢\n• 🧘 身心健康教练\n• 🎯 生活目标管理系统\n• 🛒 消费决策参谋\nSlogan候选：\n1. 「你的数字生活另一半」\n2. 「从起床到入睡的全域AI伴侣」\n3. 「Mori：让理想生活自动运行」",
                            "title" : "🔄 项目升级：Mori-AI生活合伙人",
                            "id" : "FE8FFBDB-EBB4-4C97-AE03-298352BBD38C:7F1D1AC3-D693-4AE8-B1BA-D8D8D7212F80",
                            "is_all_day" : false,
                            "end_date" : "2025-06-24T02:30:00+08:00"
                        }
                    }
                    """
                ]
            )
        ),

        .chatMessage(
            ChatMessage(
                content:
                    "✅ Perfect! I've added a 15-minute reminder for your Team Meeting. You'll be notified at 9:45 AM.",
                isUser: false
            )
        ),

        // Error example
        .chatMessage(
            ChatMessage(content: "What's the weather like?", isUser: true)
        ),
        .workflowStep(
            WorkflowStep(
                status: .error,
                toolName: "Weather API Error: Service temporarily unavailable"
            )
        ),
        .chatMessage(
            ChatMessage(
                content:
                    "I'm sorry, but I can't get the weather information right now. The weather service is temporarily unavailable. Please try again later.",
                isUser: false
            )
        ),

        // Final status
        .workflowStep(
            WorkflowStep(
                status: .finalStatus,
                toolName: "Completed. Processed 2 tool calls."
            )
        ),
    ])
    .preferredColorScheme(.dark)
}

#Preview("Recording State") {
    ChatView(
        initialMessages: [
            .chatMessage(ChatMessage(content: "Hello", isUser: true)),
            .chatMessage(ChatMessage(content: "Hi! How can I help you today?", isUser: false))
        ],
        isRecording: true
    )
    .preferredColorScheme(.dark)
}

#Preview("Transcribing State") {
    ChatView(
        initialMessages: [
            .chatMessage(ChatMessage(content: "Hello", isUser: true)),
            .chatMessage(ChatMessage(content: "Hi! How can I help you today?", isUser: false))
        ],
        isTranscribing: true
    )
    .preferredColorScheme(.dark)
}

#Preview("Recording Error") {
    ChatView(
        initialMessages: [
            .chatMessage(ChatMessage(content: "Hello", isUser: true)),
            .chatMessage(ChatMessage(content: "Hi! How can I help you today?", isUser: false))
        ],
        recordingError: "Recording too short! Please record for at least 1 second(s). Your recording was only 0.5 second(s).",
        showRecordingError: true
    )
    .preferredColorScheme(.dark)
}

#Preview("Permission Error") {
    ChatView(
        initialMessages: [
            .chatMessage(ChatMessage(content: "What's the weather like?", isUser: true))
        ],
        recordingError: "Recording permission denied. Please allow microphone access in Settings.",
        showRecordingError: true
    )
    .preferredColorScheme(.dark)
}

#Preview("Transcription Error") {
    ChatView(
        initialMessages: [
            .chatMessage(ChatMessage(content: "Can you hear me?", isUser: true))
        ],
        recordingError: "Transcription failed: Network connection error. Please check your internet connection and try again.",
        showRecordingError: true
    )
    .preferredColorScheme(.dark)
}

#Preview("Drag to Cancel") {
    ChatView(
        initialMessages: [
            .chatMessage(ChatMessage(content: "Testing voice message...", isUser: true))
        ],
        isRecording: true,
        isDraggedToCancel: true
    )
    .preferredColorScheme(.dark)
}
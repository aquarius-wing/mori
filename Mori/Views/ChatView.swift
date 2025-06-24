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
        recordingPermissionGranted: Bool = true
    ) {
        self._messageList = State(initialValue: initialMessages)
        self.onShowMenu = onShowMenu
        // Set initial recording states
        self._isRecording = State(initialValue: isRecording)
        self._isTranscribing = State(initialValue: isTranscribing)
        self._recordingPermissionGranted = State(initialValue: recordingPermissionGranted)
    }

    var body: some View {
        NavigationStack {
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
                                        if case .message(let message) = item {
                                            retryFromMessage(message)
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
                                AudioRecordingButton(
                                    llmService: llmService,
                                    onTranscriptionComplete: { transcribedText in
                                        inputText += transcribedText
                                    },
                                    onError: { error in
                                        errorMessage = error
                                        showingError = true
                                    },
                                    isDisabled: isSending || isStreaming,
                                    isRecording: $isRecording,
                                    isTranscribing: $isTranscribing,
                                    recordingPermissionGranted: $recordingPermissionGranted
                                )
                                
                                // Send Button
                                Button(action: sendMessage) {
                                    Image(
                                        systemName: isSending
                                            ? "hourglass" : "arrow.up"
                                    )
                                    .foregroundColor(.white)
                                }
                                .frame(width: 32, height: 32)
                                .background(
                                    inputText.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ).isEmpty || isSending || isStreaming
                                        ? Color.gray : Color.blue
                                )
                                .cornerRadius(16)
                                .contentShape(Rectangle())
                                .disabled(
                                    inputText.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ).isEmpty || isSending || isStreaming
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
            .navigationTitle("Mori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    private func sendMessage() {
        let messageText = inputText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !messageText.isEmpty, let service = llmService else { return }

        // Clear input field and reset state
        inputText = ""
        isSending = true
        updateStatus("Processing request...", type: .llmThinking)

        // Add user message
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messageList.append(.chatMessage(userMessage))

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
                await processRealToolWorkflow(for: messageText, using: service)

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

    private func processRealToolWorkflow(
        for messageText: String,
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
                            if case .chatMessage(_) = $0 { return true }
                            return false
                        }) {
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
                        } else {
                            // If no ChatMessage found, add new one
                            let assistantMessage = ChatMessage(
                                content: content,
                                isUser: false,
                                timestamp: Date()
                            )
                            messageList.append(.chatMessage(assistantMessage))
                            print(
                                "✅ Added assistant message: \(String(content.prefix(50)))..."
                            )
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

                print(
                    "🏁 Workflow completed. Final messageList count: \(messageList.count)"
                )

                // Auto-save current chat history
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

    private func retryFromMessage(_ message: ChatMessage) {
        // Find the index of the message to retry from
        guard let messageIndex = messageList.firstIndex(where: { item in
            if case .chatMessage(let chatMessage) = item {
                return chatMessage.id == message.id
            }
            return false
        }) else {
            print("⚠️ Message not found for retry")
            return
        }

        // Store the message content before removal
        let messageContent = message.content

        // Remove the message and all messages after it
        messageList.removeSubrange(messageIndex...)
        print("🔄 Removed \(messageList.count - messageIndex) messages for retry")

        // Reset state
        currentStatus = "Ready"
        statusType = .finalStatus
        isStreaming = false
        isSending = false

        // Set the input text and trigger send
        inputText = messageContent
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
                        "success": true,
                        "message": "Event updated successfully",
                        "event": {
                            "id": "1",
                            "title": "Team Meeting",
                            "start_date": "2024-01-15T10:00:00+08:00",
                            "end_date": "2024-01-15T11:00:00+08:00",
                            "location": "Conference Room A",
                            "notes": "Weekly sync meeting",
                            "is_all_day": false
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

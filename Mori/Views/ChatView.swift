import Combine
import Foundation
import SwiftUI

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

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Chat messages area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(chatItems) { item in
                                    ChatItemView(
                                        item: item,
                                        onCopy: {
                                            if case .message(let message) = item
                                            {
                                                copyMessage(message.content)
                                            } else {
                                                copyLastMessage()
                                            }
                                        },
                                        onLike: likeMessage,
                                        onDislike: dislikeMessage,
                                        onRegenerate: regenerateResponse,
                                        onShowErrorDetail: {
                                            showingErrorDetail = true
                                        },
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
    }

    // MARK: - Private Methods

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
                    let errorStep = WorkflowStep(
                        status: .error,
                        toolName: "Send failed: \(error.localizedDescription)"
                    )
                    messageList.append(.workflowStep(errorStep))
                    updateStatus(
                        "Error: \(error.localizedDescription)",
                        type: .error
                    )
                    isSending = false
                    isStreaming = false
                    // Save complete error detail
                    errorDetail = "\(error)"
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
            let chatMessages = messageList.compactMap { item in
                if case .chatMessage(let chatMessage) = item {
                    return chatMessage
                }
                return nil
            }
            let stream = service.sendChatMessageWithTools(
                conversationHistory: chatMessages
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
                            toolName: content
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
                let finalStep = WorkflowStep(
                    status: .finalStatus,
                    toolName: finalStatusMessage
                )
                messageList.append(.workflowStep(finalStep))

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
                let errorStep = WorkflowStep(
                    status: .error,
                    toolName: "Error: \(error.localizedDescription)"
                )
                messageList.append(.workflowStep(errorStep))
                updateStatus(
                    "❌ Error: \(error.localizedDescription)",
                    type: .error
                )
                isStreaming = false
                showingError = true
                errorMessage = error.localizedDescription
                // Save complete error detail
                errorDetail = "\(error)"
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

    private func regenerateResponse() {
        // Implement regenerate functionality
        print("🔄 Regenerating response")
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
        // Save current chat if it has messages
        if !messageList.isEmpty {
            saveCurrentChatHistory()
        }

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
}

// MARK: - UI Components (keeping original design)

struct ChatItemView: View {
    let item: ChatItem
    let onCopy: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    let onRegenerate: () -> Void
    let onShowErrorDetail: () -> Void
    let errorDetail: String

    var body: some View {
        switch item {
        case .message(let chatMessage):
            MessageItemView(
                message: chatMessage,
                onCopy: {
                    // Copy the specific message content
                    UIPasteboard.general.string = chatMessage.content
                },
                onLike: onLike,
                onDislike: onDislike,
                onRegenerate: onRegenerate,
                onShowErrorDetail: onShowErrorDetail,
                errorDetail: errorDetail
            )
        case .workflowStep(let workflowStep):
            WorkflowStepItemView(step: workflowStep)
        }
    }
}

struct MessageItemView: View {
    let message: ChatMessage
    let onCopy: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    let onRegenerate: () -> Void
    let onShowErrorDetail: () -> Void
    let errorDetail: String

    // Check if this is an error message
    private var isErrorMessage: Bool {
        return message.content.contains("Invalid API response")
            || message.content.contains("Error:")
            || message.content.contains("Failed")
            || message.content.lowercased().contains("error")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(truncateContent(message.content))
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                        .foregroundColor(.white)
                        .contextMenu {
                            Button(action: onCopy) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }

                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(
                    maxWidth: UIScreen.main.bounds.width * 0.75,
                    alignment: .trailing
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(truncateContent(message.content))
                        .font(.body)
                        .foregroundColor(isErrorMessage ? .red : .white)
                        .multilineTextAlignment(.leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isErrorMessage {
                                onShowErrorDetail()
                            }
                        }

                    if isErrorMessage {
                        Text("Tap for details")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))

                    // Action buttons row
                    HStack(spacing: 16) {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Button(action: onLike) {
                            Image(systemName: "hand.thumbsup")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Button(action: onDislike) {
                            Image(systemName: "hand.thumbsdown")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Button(action: onRegenerate) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()
                    }
                }
                .frame(
                    maxWidth: UIScreen.main.bounds.width * 0.85,
                    alignment: .leading
                )

                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Truncate content before ```json and trim whitespace
    private func truncateContent(_ content: String) -> String {
        if let range = content.range(of: "```json") {
            return String(content[..<range.lowerBound]).trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WorkflowStepItemView: View {
    let step: WorkflowStep
    @State private var showingCalendarDetail = false
    @State private var showingErrorDetail = false

    var body: some View {
        // Dynamic rendering based on toolName and status
        if step.toolName == "read-calendar" && step.status == .result {
            renderCalendarReadResult()
        } else if step.toolName == "update-calendar" && step.status == .result {
            renderCalendarUpdateResult()
        } else {
            renderDefaultWorkflowStep()
        }
    }

    // MARK: - Calendar Read Result
    @ViewBuilder
    private func renderCalendarReadResult() -> some View {
        if let resultValue = step.details["result"],
            let jsonData = resultValue.data(using: .utf8),
            let calendarResponse = try? JSONDecoder().decode(
                CalendarReadResponse.self,
                from: jsonData
            )
        {
            // Simplified view showing only summary
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Founded \(calendarResponse.count) events in Calendar")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text("Tap for details")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.2))
            )
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                showingCalendarDetail = true
            }
            .sheet(isPresented: $showingCalendarDetail) {
                CalendarEventsDetailView(calendarResponse: calendarResponse)
            }

        } else {
            renderDefaultWorkflowStep()
        }
    }

    // MARK: - Calendar Update Result
    @ViewBuilder
    private func renderCalendarUpdateResult() -> some View {
        if let resultValue = step.details["result"],
            let jsonData = resultValue.data(using: .utf8),
            let updateResponse = try? JSONDecoder().decode(
                CalendarUpdateResponse.self,
                from: jsonData
            )
        {

            HStack(spacing: 16) {
                Image(
                    systemName: updateResponse.success
                        ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.title2)
                .foregroundColor(updateResponse.success ? .green : .red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        updateResponse.success
                            ? "Calendar updated successfully"
                            : "Calendar update failed"
                    )
                    .font(.headline)
                    .foregroundColor(.white)

                    Text(updateResponse.message)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))

                    if !updateResponse.event.title.isEmpty {
                        Text("Events: \(updateResponse.event.title)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        (updateResponse.success ? Color.green : Color.red)
                            .opacity(0.2)
                    )
            )
            .padding(.horizontal, 20)

        } else {
            renderDefaultWorkflowStep()
        }
    }

    // MARK: - Default Workflow Step
    @ViewBuilder
    private func renderDefaultWorkflowStep() -> some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: iconForStatus)
                .font(.title2)
                .foregroundColor(step.status == .error ? .red : .white)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !step.toolName.isEmpty {
                        Text(step.toolName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Add "Tap for details" hint for error status
                    if step.status == .error {
                        Text("Tap for details")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                if !step.details.isEmpty {
                    ForEach(Array(step.details.keys.sorted()), id: \.self) {
                        key in
                        if let value = step.details[key], !value.isEmpty {
                            Text(value)
                                .font(.body)
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    step.status == .error
                        ? Color.red.opacity(0.2) : Color.white.opacity(0.1)
                )
        )
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture {
            if step.status == .error {
                showingErrorDetail = true
            }
        }
        .sheet(isPresented: $showingErrorDetail) {
            ErrorDetailView(errorDetail: step.toolName)
        }
    }

    private var iconForStatus: String {
        // Check the step details to determine the appropriate icon
        if let action = step.details["action"], action.contains("Searching") {
            return "magnifyingglass"
        } else if let result = step.details["result"] {
            if result.contains("Founded") || result.contains("Found") {
                return "magnifyingglass"
            } else if result.contains("Updated") {
                return "pencil"
            }
        }

        // Default icons based on status
        switch step.status {
        case .scheduled:
            return "clock"
        case .executing:
            return "magnifyingglass"
        case .result:
            return "checkmark"
        case .error:
            return "xmark"
        case .finalStatus:
            return "checkmark.circle"
        case .llmThinking:
            return "brain"
        }
    }
}

// MARK: - Calendar Event Row Component
struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(event.startDate))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                if !event.isAllDay {
                    Text(formatTime(event.endDate))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 45)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !event.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(event.location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func formatTime(_ dateString: String) -> String {
        // Try ISO8601DateFormatter first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        // Fallback to manual DateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = TimeZone.current

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        return "Time"
    }
}

// MARK: - Error Detail View
struct ErrorDetailView: View {
    let errorDetail: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Error Details")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Complete error information")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Divider()
                        .background(Color.white.opacity(0.2))
                }

                // Error content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Error details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Error Information:")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(errorDetail)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .multilineTextAlignment(.leading)
                        }

                        // Copy button
                        HStack {
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = errorDetail
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                    Text("Copy Error")
                                        .font(.body)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.2))
                                )
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
        }
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
                        "message": "Reminder added successfully",
                        "event": {
                            "title": "Team Meeting",
                            "reminder": "15 minutes before"
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

// MARK: - Calendar Events Detail View
struct CalendarEventsDetailView: View {
    let calendarResponse: CalendarReadResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar events")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Found \(calendarResponse.count) events")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Divider()
                        .background(Color.white.opacity(0.2))
                }

                // Events list
                if !calendarResponse.events.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(calendarResponse.events, id: \.id) {
                                event in
                                CalendarEventDetailRow(event: event)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No events found")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 16)
                        Spacer()
                    }
                }
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Calendar Event Detail Row Component
struct CalendarEventDetailRow: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and time
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        if event.isAllDay {
                            Text("All day")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text(
                                "\(formatDateTime(event.startDate)) - \(formatTime(event.endDate))"
                            )
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }

                Spacer()
            }

            // Location (if available)
            if !event.location.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(event.location)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
            }

            // Notes (if available)
            if !event.notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(event.notes)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func formatDateTime(_ dateString: String) -> String {
        // Try ISO8601DateFormatter first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        // Fallback to manual DateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = TimeZone.current

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        return dateString
    }

    private func formatTime(_ dateString: String) -> String {
        // Try ISO8601DateFormatter first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current

        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        // Fallback to manual DateFormatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.timeZone = TimeZone.current

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }

        return "Time"
    }
}

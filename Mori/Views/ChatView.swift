import SwiftUI
import Combine

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
    @State private var statusType: WorkflowStepType = .finalStatus
    @State private var isStreaming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    // Text input related state
    @State private var inputText = ""
    @State private var isSending = false
    
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
                                    StatusIndicator(status: currentStatus, type: statusType)
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
                    if isSending || isStreaming {
                        HStack {
                            Image(systemName: statusType == .error ? "exclamationmark.triangle" : "gear")
                                .foregroundColor(statusType == .error ? .red : .blue)
                            Text(currentStatus)
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
                    }
                }
                
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
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
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
                    let errorStep = WorkflowStep(type: .error, title: "Send failed: \(error.localizedDescription)")
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
                            type: .scheduled,
                            title: content,
                            details: ["tool_name": content, "arguments": "Pending..."]
                        )
                        messageList.append(toolCallStep)
                        updateStatus("⏰ Scheduling tool: \(content)", type: .scheduled)
                    case "tool_arguments":
                        // Update the most recent scheduled step with arguments
                        if let lastIndex = messageList.lastIndex(where: { ($0 as? WorkflowStep)?.type == .scheduled }) {
                            if let step = messageList[lastIndex] as? WorkflowStep {
                                let updatedStep = WorkflowStep(
                                    type: .scheduled,
                                    title: step.title,
                                    details: ["tool_name": step.details["tool_name"] ?? "", "arguments": content]
                                )
                                messageList[lastIndex] = updatedStep
                            }
                        }
                    case "tool_execution":
                        // Update the most recent scheduled step to executing
                        if let lastIndex = messageList.lastIndex(where: { ($0 as? WorkflowStep)?.type == .scheduled }) {
                            if let step = messageList[lastIndex] as? WorkflowStep {
                                let updatedStep = WorkflowStep(
                                    type: .executing,
                                    title: step.title,
                                    details: step.details
                                )
                                messageList[lastIndex] = updatedStep
                            }
                        }
                        updateStatus("⚡ Executing: \(content)", type: .executing)
                    case "tool_results":
                        // Update the most recent executing step to result
                        if let lastIndex = messageList.lastIndex(where: { ($0 as? WorkflowStep)?.type == .executing }) {
                            if let step = messageList[lastIndex] as? WorkflowStep {
                                let updatedStep = WorkflowStep(
                                    type: .result,
                                    title: step.title,
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
                        let errorStep = WorkflowStep(type: .error, title: content)
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
                let finalStep = WorkflowStep(type: .finalStatus, title: finalStatusMessage)
                messageList.append(finalStep)
                
                updateStatus("✅ \(finalStatusMessage)", type: .finalStatus)
                
                // Reset streaming state
                isStreaming = false
                
                print("🏁 Workflow completed. Final messageList count: \(messageList.count)")
            }
        } catch {
            await MainActor.run {
                let errorStep = WorkflowStep(type: .error, title: "Error: \(error.localizedDescription)")
                messageList.append(errorStep)
                updateStatus("❌ Error: \(error.localizedDescription)", type: .error)
                isStreaming = false
            }
        }
    }
    
    private func updateStatus(_ status: String, type: WorkflowStepType) {
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
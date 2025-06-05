import SwiftUI
import Combine

struct ChatView: View {
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("customApiBaseUrl") private var customApiBaseUrl = ""
    
    @State private var openAIService: OpenAIService?
    
    @State private var messages: [ChatMessage] = []
    @State private var currentStreamingMessage = ""
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
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Display streaming message
                            if isStreaming && !currentStreamingMessage.isEmpty {
                                MessageBubble(
                                    message: ChatMessage(content: currentStreamingMessage, isUser: false),
                                    isStreaming: true
                                )
                                .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: currentStreamingMessage) { _ in
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Text input area
                VStack(spacing: 12) {
                    // Text input field
                    HStack(spacing: 12) {
                        TextField("Enter message...", text: $inputText, axis: .vertical)
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
                    
                    // Status indicator
                    if isSending {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Sending...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if isStreaming {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI is responding...")
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        messages.removeAll()
                    }
                    .disabled(isStreaming || isSending)
                }
            }
        }
        .onAppear {
            openAIService = OpenAIService(apiKey: openaiApiKey, customBaseURL: customApiBaseUrl.isEmpty ? nil : customApiBaseUrl)
            // Add debug information
            print("🔧 API Configuration:")
            print("  API Key: \(openaiApiKey.isEmpty ? "❌ Not set" : "✅ Set (length: \(openaiApiKey.count))")")
            print("  Base URL: \(customApiBaseUrl.isEmpty ? "✅ Using default" : "🔧 Custom: \(customApiBaseUrl)")")
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
        guard !messageText.isEmpty, let service = openAIService else { return }
        
        // Clear input field and set sending state
        inputText = ""
        isSending = true
        
        // Add user message
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)
        
        Task {
            do {
                await MainActor.run {
                    isSending = false
                    isStreaming = true
                    currentStreamingMessage = ""
                }
                
                // Get AI response with tools (streaming)
                let stream = service.sendChatMessageWithTools(messageText, conversationHistory: messages)
                
                var fullResponse = ""
                for try await chunk in stream {
                    fullResponse += chunk
                    await MainActor.run {
                        currentStreamingMessage = fullResponse
                    }
                }
                
                await MainActor.run {
                    // Complete streaming response, add complete AI message
                    let aiMessage = ChatMessage(content: fullResponse, isUser: false)
                    messages.append(aiMessage)
                    
                    // Reset streaming state
                    isStreaming = false
                    currentStreamingMessage = ""
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Send failed: \(error.localizedDescription)"
                    showingError = true
                    isSending = false
                    isStreaming = false
                    currentStreamingMessage = ""
                }
            }
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
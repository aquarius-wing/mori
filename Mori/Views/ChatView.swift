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
    
    // 文本输入相关状态
    @State private var inputText = ""
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // 显示正在流式输入的消息
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
                
                // 文本输入区域
                VStack(spacing: 12) {
                    // 文本输入框
                    HStack(spacing: 12) {
                        TextField("输入消息...", text: $inputText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(1...6)
                            .disabled(isSending || isStreaming)
                        
                        // 发送按钮
                        Button(action: sendMessage) {
                            Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isStreaming ? .gray : .blue)
                                .font(.title2)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isStreaming)
                    }
                    .padding(.horizontal)
                    
                    // 状态提示
                    if isSending {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("发送中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if isStreaming {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI正在回复...")
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
            // 添加调试信息
            print("🔧 API配置:")
            print("  API Key: \(openaiApiKey.isEmpty ? "❌ 未设置" : "✅ 已设置 (长度: \(openaiApiKey.count))")")
            print("  Base URL: \(customApiBaseUrl.isEmpty ? "✅ 使用默认" : "🔧 自定义: \(customApiBaseUrl)")")
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
        
        // 清空输入框并设置发送状态
        inputText = ""
        isSending = true
        
        // 添加用户消息
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)
        
        Task {
            do {
                await MainActor.run {
                    isSending = false
                    isStreaming = true
                    currentStreamingMessage = ""
                }
                
                // 获取AI回复（流式）
                let stream = service.sendChatMessage(messageText, conversationHistory: messages)
                
                var fullResponse = ""
                for try await chunk in stream {
                    fullResponse += chunk
                    await MainActor.run {
                        currentStreamingMessage = fullResponse
                    }
                }
                
                await MainActor.run {
                    // 完成流式响应，添加完整的AI消息
                    let aiMessage = ChatMessage(content: fullResponse, isUser: false)
                    messages.append(aiMessage)
                    
                    // 重置流式状态
                    isStreaming = false
                    currentStreamingMessage = ""
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "发送失败: \(error.localizedDescription)"
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
        // 无需更新
    }
}

#Preview {
    ChatView()
} 
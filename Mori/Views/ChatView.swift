import SwiftUI

struct ChatView: View {
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("customApiBaseUrl") private var customApiBaseUrl = ""
    
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var openAIService: OpenAIService?
    
    @State private var messages: [ChatMessage] = []
    @State private var currentStreamingMessage = ""
    @State private var isStreaming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
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
                
                // 录音按钮区域
                VStack(spacing: 16) {
                    if audioRecorder.isRecording {
                        VStack(spacing: 8) {
                            Text("Recording...")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("Release to send")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Hold to record")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 录音按钮
                    Button(action: {}) {
                        Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(audioRecorder.isRecording ? .red : .blue)
                    }
                    .scaleEffect(audioRecorder.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: audioRecorder.isRecording)
                    .onLongPressGesture(
                        minimumDuration: 0,
                        maximumDistance: .infinity,
                        pressing: { pressing in
                            if pressing {
                                startRecording()
                            } else {
                                stopRecording()
                            }
                        },
                        perform: {}
                    )
                }
                .padding()
            }
            .navigationTitle("Mori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        messages.removeAll()
                    }
                    .disabled(isStreaming)
                }
            }
        }
        .onAppear {
            openAIService = OpenAIService(apiKey: openaiApiKey, customBaseURL: customApiBaseUrl.isEmpty ? nil : customApiBaseUrl)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startRecording() {
        Task {
            let hasPermission = await audioRecorder.requestPermission()
            
            if hasPermission {
                audioRecorder.startRecording()
            } else {
                await MainActor.run {
                    errorMessage = "Microphone access is required for voice recording"
                    showingError = true
                }
            }
        }
    }
    
    private func stopRecording() {
        audioRecorder.stopRecording()
        
        // 处理录音文件
        guard let recordingURL = audioRecorder.recordingURL,
              let service = openAIService else {
            return
        }
        
        Task {
            do {
                // 语音转文字
                let transcription = try await service.transcribeAudio(from: recordingURL)
                
                await MainActor.run {
                    // 添加用户消息
                    let userMessage = ChatMessage(content: transcription, isUser: true)
                    messages.append(userMessage)
                    
                    // 开始流式获取AI回复
                    isStreaming = true
                    currentStreamingMessage = ""
                }
                
                // 获取AI回复（流式）
                let stream = service.sendChatMessage(transcription, conversationHistory: messages)
                
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
                
                // 清理录音文件
                audioRecorder.deleteRecording()
                
            } catch {
                await MainActor.run {
                    errorMessage = "Voice processing failed: \(error.localizedDescription)"
                    showingError = true
                    isStreaming = false
                    currentStreamingMessage = ""
                }
                
                audioRecorder.deleteRecording()
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

#Preview {
    ChatView()
} 
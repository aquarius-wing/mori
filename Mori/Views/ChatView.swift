import SwiftUI
import Foundation
import UIKit

struct ChatView: View {
    @State private var chatItems: [ChatItem] = [
        .message("Move all my events today to tomorrow", isUser: true),
        .message("I'll help you move all your events today to tomorrow:", isUser: false),
        .workflowStep(.executing, toolName: "Calendar", details: ["action": "Searching in Calendar..."]),
        .workflowStep(.result, toolName: "Calendar", details: ["result": "Founded 4 events in Calendar"]),
        .workflowStep(.result, toolName: "Calendar", details: ["result": "Updated 4 events in Calendar"])
    ]
    
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                // Dark background
                
                VStack(spacing: 0) {
                    // Chat messages area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(chatItems) { item in
                                    ChatItemView(item: item)
                                        .id(item.id)
                                }
                                
                                if isProcessing {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("正在处理...")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 20)
                            .padding(.bottom, 0) // Adjust spacing when keyboard is shown
                        }
                        .onChange(of: chatItems.count) { _, _ in
                            if let lastItem = chatItems.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastItem.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input area with action buttons
                    VStack(spacing: 0) {
                        // Action buttons
                        if !chatItems.isEmpty {
                            HStack(spacing: 20) {
                                Button(action: copyLastMessage) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Button(action: likeMessage) {
                                    Image(systemName: "hand.thumbsup")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Button(action: dislikeMessage) {
                                    Image(systemName: "hand.thumbsdown")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Button(action: regenerateResponse) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        
                        // Input field
                        VStack(spacing: 12) {
                            TextField("输入消息...", text: $inputText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...5)
                                .foregroundColor(.white)
                                .accentColor(.white)
                                .focused($isTextFieldFocused)
                            HStack(spacing: 12) {
                                Spacer()
                                
                                Button(action: sendMessage) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(
                                            Circle()
                                                .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                                        )
                                }
                                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)//max(keyboardHeight > 0 ? 16 : 40, geometry.safeAreaInsets.bottom + 16))
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20)
                                .fill(Color.white.opacity(0.1))
                                
                        )
                    }
                    
                }
                
            }
            .navigationTitle("聊天")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
    
    private func sendMessage() {
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        // Add user message
        chatItems.append(ChatItem.message(message, isUser: true))
        inputText = ""
        isProcessing = true
        
        // Simulate AI processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Add workflow step
            chatItems.append(ChatItem.workflowStep(.executing, toolName: "AI Processing", details: ["action": "analyzing message"]))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Add result
                chatItems.append(ChatItem.workflowStep(.result, toolName: "AI Processing", details: ["result": "completed analysis"]))
                
                // Add AI response
                chatItems.append(ChatItem.message("I understand your message: \"\(message)\". How can I help you further?", isUser: false))
                isProcessing = false
            }
        }
    }
    
    private func copyLastMessage() {
        // Implement copy functionality
    }
    
    private func likeMessage() {
        // Implement like functionality
    }
    
    private func dislikeMessage() {
        // Implement dislike functionality
    }
    
    private func regenerateResponse() {
        // Implement regenerate functionality
    }
}

struct ChatItemView: View {
    let item: ChatItem
    
    var body: some View {
        switch item {
        case .message(let chatMessage):
            MessageItemView(message: chatMessage)
        case .workflowStep(let workflowStep):
            WorkflowStepItemView(step: workflowStep)
        }
    }
}

struct MessageItemView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(message.content)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                        .foregroundColor(.white)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
                
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
}

struct WorkflowStepItemView: View {
    let step: WorkflowStep
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: iconForStatus)
                .font(.title2)
                .foregroundColor(.white)
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
                }
                
                if !step.details.isEmpty {
                    ForEach(Array(step.details.keys.sorted()), id: \.self) { key in
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
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 20)
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

#Preview {
    ChatView()
        .preferredColorScheme(.dark)
}

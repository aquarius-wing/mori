import Foundation
import SwiftUI

struct ChatView: View {
    @State private var chatItems: [ChatItem] = [
        .message("Move all my events today to tomorrow", isUser: true),
        .message(
            "I'll help you move all your events today to tomorrow:",
            isUser: false
        ),
        .workflowStep(
            .executing,
            toolName: "Calendar",
            details: ["action": "Searching in Calendar..."]
        ),
        .workflowStep(
            .result,
            toolName: "Calendar",
            details: ["result": "Founded 4 events in Calendar"]
        ),
        .workflowStep(
            .result,
            toolName: "Calendar",
            details: ["result": "Updated 4 events in Calendar"]
        ),
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
                                    ChatItemView(
                                        item: item,
                                        onCopy: {
                                            if case .message(let message) = item {
                                                copyMessage(message.content)
                                            } else {
                                                copyLastMessage()
                                            }
                                        },
                                        onLike: likeMessage,
                                        onDislike: dislikeMessage,
                                        onRegenerate: regenerateResponse
                                    )
                                    .id(item.id)
                                }

                                if isProcessing {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(
                                                CircularProgressViewStyle(
                                                    tint: .white
                                                )
                                            )
                                            .scaleEffect(0.8)
                                        Text("Processing...")
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
                            .padding(.bottom, 0)  // Adjust spacing when keyboard is shown
                        }
                        .onChange(of: chatItems.count) { _, _ in
                            if let lastItem = chatItems.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastItem.id, anchor: .bottom)
                                }
                            }
                        }
                        .onTapGesture {
                            // Dismiss keyboard when tapping on chat area
                            isTextFieldFocused = false
                        }
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
                            HStack(spacing: 12) {
                                Spacer()
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up")
                                        .foregroundColor(.white)
                                        
                                }
                                .frame(width: 32, height: 32)
                                .background(Color.blue)
                                .cornerRadius(16)
                                .contentShape(Rectangle())

                                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing {
                                    
                                }
                            }
                        }
                        .contentShape(Rectangle()) // Make the entire VStack tappable
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
                                .offset(y: geometry.safeAreaInsets.bottom + 12), // Adjust this value to position the rectangle
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
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere outside input area
                isTextFieldFocused = false
            }
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
            chatItems.append(
                ChatItem.workflowStep(
                    .executing,
                    toolName: "AI Processing",
                    details: ["action": "analyzing message"]
                )
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Add result
                chatItems.append(
                    ChatItem.workflowStep(
                        .result,
                        toolName: "AI Processing",
                        details: ["result": "completed analysis"]
                    )
                )

                // Add AI response
                chatItems.append(
                    ChatItem.message(
                        "I understand your message: \"\(message)\". How can I help you further?",
                        isUser: false
                    )
                )
                isProcessing = false
            }
        }
    }

    private func copyMessage(_ content: String) {
        UIPasteboard.general.string = content
    }
    
    private func copyLastMessage() {
        // Implement copy functionality - this is for backward compatibility
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
    let onCopy: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        switch item {
        case .message(let chatMessage):
            MessageItemView(
                message: chatMessage,
                onCopy: onCopy,
                onLike: onLike,
                onDislike: onDislike,
                onRegenerate: onRegenerate
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
                .frame(
                    maxWidth: UIScreen.main.bounds.width * 0.75,
                    alignment: .trailing
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

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

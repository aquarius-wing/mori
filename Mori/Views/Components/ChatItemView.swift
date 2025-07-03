import SwiftUI
import Foundation
import MarkdownUI

// MARK: - Chat Item Components

struct ChatItemView: View {
    let item: ChatItem
    let onCopy: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    let onRetry: () -> Void
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
                onRetry: onRetry,
                onShowErrorDetail: onShowErrorDetail,
                errorDetail: errorDetail
            )
        case .workflowStep(let workflowStep):
            WorkflowStepItemView(step: workflowStep, onRetry: onRetry)
        }
    }
}

struct MessageItemView: View {
    let message: ChatMessage
    let onCopy: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    let onRetry: () -> Void
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
                    Markdown(truncateContent(message.content))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                        .foregroundColor(.white)
                        .contextMenu {
                            Button(action: onCopy) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            if message.isUser {
                                Button(action: onRetry) {
                                    Label("Retry", systemImage: "arrow.clockwise")
                                }
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
                    Markdown(truncateContent(message.content))

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
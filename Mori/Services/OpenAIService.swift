import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Whisper Speech-to-Text
    func transcribeAudio(from url: URL) async throws -> String {
        let transcriptionURL = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: url)
        var body = Data()
        
        // 添加模型参数
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // 添加音频文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return transcriptionResponse.text
    }
    
    // MARK: - GPT-4o Chat Completion with Streaming
    func sendChatMessage(_ message: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let chatURL = URL(string: "\(baseURL)/chat/completions")!
                    var request = URLRequest(url: chatURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // 构建消息历史
                    var messages: [[String: Any]] = []
                    
                    // 添加系统消息
                    messages.append([
                        "role": "system",
                        "content": "You are Mori, a helpful AI assistant. Please respond in a friendly and helpful manner."
                    ])
                    
                    // 添加历史消息（只保留最近的10条消息以控制token数量）
                    let recentHistory = Array(conversationHistory.suffix(10))
                    for msg in recentHistory {
                        messages.append([
                            "role": msg.isUser ? "user" : "assistant",
                            "content": msg.content
                        ])
                    }
                    
                    // 添加当前消息
                    messages.append([
                        "role": "user",
                        "content": message
                    ])
                    
                    let requestBody: [String: Any] = [
                        "model": "gpt-4o",
                        "messages": messages,
                        "stream": true,
                        "max_tokens": 2000,
                        "temperature": 0.7
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    // 使用流式请求
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw OpenAIError.invalidResponse
                    }
                    
                    // 处理流式响应
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let jsonData = jsonString.data(using: .utf8),
                               let streamResponse = try? JSONDecoder().decode(ChatStreamResponse.self, from: jsonData),
                               let choice = streamResponse.choices.first,
                               let content = choice.delta.content {
                                continuation.yield(content)
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Response Models
struct TranscriptionResponse: Codable {
    let text: String
}

struct ChatStreamResponse: Codable {
    let choices: [StreamChoice]
}

struct StreamChoice: Codable {
    let delta: StreamDelta
}

struct StreamDelta: Codable {
    let content: String?
}

// MARK: - Errors
enum OpenAIError: Error, LocalizedError {
    case invalidResponse
    case noAudioData
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response"
        case .noAudioData:
            return "No audio data"
        case .transcriptionFailed:
            return "Speech-to-text failed"
        }
    }
} 
import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL: String
    
    init(apiKey: String, customBaseURL: String? = nil) {
        self.apiKey = apiKey
        if let customURL = customBaseURL, !customURL.isEmpty {
            // 移除末尾的斜杠，保持baseURL为纯基础URL
            self.baseURL = customURL.hasSuffix("/") ? String(customURL.dropLast()) : customURL
        } else {
            self.baseURL = "https://api.openai.com"
        }
    }
    
    // MARK: - Whisper Speech-to-Text
    func transcribeAudio(from url: URL) async throws -> String {
        print("🎤 开始语音转文字...")
        print("  文件路径: \(url.path)")
        print("  目标URL: \(baseURL)/v1/audio/transcriptions")
        
        let transcriptionURL = URL(string: "\(baseURL)/v1/audio/transcriptions")!
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0 // 增加超时时间
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 检查音频文件是否存在和可读
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 音频文件不存在: \(url.path)")
            throw OpenAIError.noAudioData
        }
        
        let audioData = try Data(contentsOf: url)
        print("  音频文件大小: \(audioData.count) bytes")
        
        // 检查音频数据是否为空
        guard !audioData.isEmpty else {
            print("❌ 音频文件为空")
            throw OpenAIError.noAudioData
        }
        var body = Data()
        
        // 添加模型参数
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // 添加音频文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // 添加详细的请求日志
        print("🔧 请求详情:")
        print("  Method: \(request.httpMethod ?? "未知")")
        print("  URL: \(request.url?.absoluteString ?? "未知")")
        print("  Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key.lowercased().contains("authorization") {
                    print("    \(key): Bearer ****** (已隐藏)")
                } else {
                    print("    \(key): \(value)")
                }
            }
        }
        print("  Body size: \(body.count) bytes")
        print("  Boundary: \(boundary)")
        
        // 保存请求体到文件以供调试
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let requestBodyURL = documentsPath.appendingPathComponent("debug_request_body.txt")
        do {
            // 创建请求体的可读格式
            let requestBodyString = """
            === HTTP请求详情 ===
            Method: \(request.httpMethod ?? "未知")
            URL: \(request.url?.absoluteString ?? "未知")
            
            Headers:
            \(request.allHTTPHeaderFields?.map { "\($0.key): \($0.value)" }.joined(separator: "\n") ?? "无")
            
            Body (Multipart Form Data):
            Boundary: \(boundary)
            Content-Length: \(body.count) bytes
            
            === 原始录音文件路径 ===
            \(url.path)
            
            === 音频文件信息 ===
            文件大小: \(audioData.count) bytes
            文件格式: WAV
            采样率: 16000 Hz
            声道: 1 (单声道)
            位深度: 16 bit
            
            === 时间戳 ===
            \(Date())
            """
            
            try requestBodyString.write(to: requestBodyURL, atomically: true, encoding: .utf8)
            print("📝 请求详情已保存到: \(requestBodyURL.path)")
            
            // 复制录音文件到更容易访问的位置
            let debugAudioURL = documentsPath.appendingPathComponent("debug_recording.wav")
            try? FileManager.default.removeItem(at: debugAudioURL) // 删除旧文件
            try FileManager.default.copyItem(at: url, to: debugAudioURL)
            print("🎵 录音文件已复制到: \(debugAudioURL.path)")
            
        } catch {
            print("❌ 保存调试文件失败: \(error)")
        }
        
        do {
            print("🌐 发送请求到 Whisper API...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的HTTP响应")
                throw OpenAIError.invalidResponse
            }
            
            print("📡 API响应状态: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                // 尝试解析错误信息
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API错误 (\(httpResponse.statusCode)): \(errorString)")
                }
                throw OpenAIError.invalidResponse
            }
            
            // 添加响应内容调试
            print("📄 响应数据大小: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 响应内容: \(responseString)")
            } else {
                print("❌ 无法将响应数据转换为字符串")
            }
            
            do {
                let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                print("✅ 语音转文字成功: \(transcriptionResponse.text)")
                return transcriptionResponse.text
            } catch {
                print("❌ JSON解析失败: \(error)")
                
                // 尝试解析可能的错误响应格式
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 尝试解析错误响应: \(responseString)")
                    
                    // 检查是否是HTML错误页面
                    if responseString.lowercased().contains("<html") {
                        print("🚨 检测到HTML响应，这通常意味着：")
                        print("  1. API端点路径不正确")
                        print("  2. 需要正确的认证")
                        print("  3. API服务配置问题")
                        
                        if responseString.contains("One API") {
                            print("💡 检测到One API管理界面，建议：")
                            print("  - 检查API端点是否应该是: /v1/audio/transcriptions")
                            print("  - 确认API密钥是否正确")
                            print("  - 确认One API服务中是否配置了Whisper模型")
                        }
                        
                        throw OpenAIError.htmlErrorResponse
                    }
                    
                    // 尝试解析其他错误格式
                    if let errorData = responseString.data(using: .utf8),
                       let errorJSON = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                       let errorMessage = errorJSON["error"] as? String {
                        throw OpenAIError.customError(errorMessage)
                    }
                }
                
                throw error
            }
        } catch {
            print("❌ 网络请求失败: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("  错误代码: \(urlError.code.rawValue)")
                print("  错误描述: \(urlError.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - GPT-4o Chat Completion with Streaming
    func sendChatMessage(_ message: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    print("💬 开始发送聊天消息...")
                    print("  目标URL: \(baseURL)/v1/chat/completions")
                    print("  消息内容: \(message)")
                    
                    guard let chatURL = URL(string: "\(baseURL)/v1/chat/completions") else {
                        print("❌ 无效的API URL: \(baseURL)/v1/chat/completions")
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }
                    
                    var request = URLRequest(url: chatURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
                    request.timeoutInterval = 60.0 // 设置超时时间
                    
                    // 构建消息历史
                    var messages: [[String: Any]] = []
                    
                    // 添加系统消息
                    messages.append([
                        "role": "system",
                        "content": "You are Mori, a helpful AI assistant. Please respond in a friendly and helpful manner. Always respond in 简体中文."
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
                    
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    } catch {
                        print("❌ JSON序列化失败: \(error)")
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    print("🔧 请求详情:")
                    print("  Method: \(request.httpMethod ?? "未知")")
                    print("  URL: \(request.url?.absoluteString ?? "未知")")
                    print("  Headers:")
                    if let headers = request.allHTTPHeaderFields {
                        for (key, value) in headers {
                            if key.lowercased().contains("authorization") {
                                print("    \(key): Bearer ****** (已隐藏)")
                            } else {
                                print("    \(key): \(value)")
                            }
                        }
                    }
                    
                    // 配置URLSession
                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 60.0
                    config.timeoutIntervalForResource = 120.0
                    config.waitsForConnectivity = true
                    config.allowsCellularAccess = true
                    config.networkServiceType = .default
                    
                    let session = URLSession(configuration: config)
                    
                    // 使用流式请求
                    print("🌐 发送流式请求...")
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("❌ 无效的HTTP响应")
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }
                    
                    print("📡 API响应状态: \(httpResponse.statusCode)")
                    print("📡 响应头:")
                    for (key, value) in httpResponse.allHeaderFields {
                        print("    \(key): \(value)")
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        print("❌ API错误状态码: \(httpResponse.statusCode)")
                        
                        // 尝试读取错误信息
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            errorData.append(byte)
                        }
                        
                        if let errorString = String(data: errorData, encoding: .utf8) {
                            print("❌ 错误详情: \(errorString)")
                        }
                        
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }
                    
                    // 处理流式响应
                    print("📡 开始处理流式响应...")
                    var hasReceivedData = false
                    
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                print("✅ 流式响应完成")
                                continuation.finish()
                                return
                            }
                            
                            if let jsonData = jsonString.data(using: .utf8) {
                                do {
                                    let streamResponse = try JSONDecoder().decode(ChatStreamResponse.self, from: jsonData)
                                    if let choice = streamResponse.choices.first,
                                       let content = choice.delta.content {
                                        hasReceivedData = true
                                        continuation.yield(content)
                                    }
                                } catch {
                                    print("⚠️ 解析流式响应失败: \(error)")
                                    print("  原始数据: \(jsonString)")
                                    // 继续处理下一行，不中断整个流
                                }
                            }
                        }
                    }
                    
                    if !hasReceivedData {
                        print("⚠️ 没有接收到任何有效数据")
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                    } else {
                        print("✅ 流式响应正常结束")
                        continuation.finish()
                    }
                    
                } catch {
                    print("❌ 聊天请求失败: \(error.localizedDescription)")
                    if let urlError = error as? URLError {
                        print("  错误代码: \(urlError.code.rawValue)")
                        print("  错误描述: \(urlError.localizedDescription)")
                        
                        // 提供具体的错误建议
                        switch urlError.code {
                        case .notConnectedToInternet:
                            print("💡 建议: 检查网络连接")
                        case .timedOut:
                            print("💡 建议: 请求超时，请重试")
                        case .cannotFindHost:
                            print("💡 建议: 检查API端点URL是否正确")
                        case .cannotConnectToHost:
                            print("💡 建议: 检查API服务是否可用")
                        default:
                            print("💡 建议: 检查网络设置和API配置")
                        }
                    }
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
    case htmlErrorResponse
    case customError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response"
        case .noAudioData:
            return "No audio data"
        case .transcriptionFailed:
            return "Speech-to-text failed"
        case .htmlErrorResponse:
            return "HTML error response"
        case .customError(let message):
            return "Custom error: \(message)"
        }
    }
} 
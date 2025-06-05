import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL: String
    
    init(apiKey: String, customBaseURL: String? = nil) {
        self.apiKey = apiKey
        if let customURL = customBaseURL, !customURL.isEmpty {
            // Remove trailing slash, keep baseURL as pure base URL
            self.baseURL = customURL.hasSuffix("/") ? String(customURL.dropLast()) : customURL
        } else {
            self.baseURL = "https://api.openai.com"
        }
    }
    
    // MARK: - Whisper Speech-to-Text
    func transcribeAudio(from url: URL) async throws -> String {
        print("🎤 Starting speech-to-text transcription...")
        print("  File path: \(url.path)")
        print("  Target URL: \(baseURL)/v1/audio/transcriptions")
        
        let transcriptionURL = URL(string: "\(baseURL)/v1/audio/transcriptions")!
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0 // Increase timeout duration
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Check if audio file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Audio file does not exist: \(url.path)")
            throw OpenAIError.noAudioData
        }
        
        let audioData = try Data(contentsOf: url)
        print("  Audio file size: \(audioData.count) bytes")
        
        // Check if audio data is empty
        guard !audioData.isEmpty else {
            print("❌ Audio file is empty")
            throw OpenAIError.noAudioData
        }
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Add detailed request logging
        print("🔧 Request details:")
        print("  Method: \(request.httpMethod ?? "Unknown")")
        print("  URL: \(request.url?.absoluteString ?? "Unknown")")
        print("  Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key.lowercased().contains("authorization") {
                    print("    \(key): Bearer ****** (Hidden)")
                } else {
                    print("    \(key): \(value)")
                }
            }
        }
        print("  Body size: \(body.count) bytes")
        print("  Boundary: \(boundary)")
        
        // Save request body to file for debugging
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let requestBodyURL = documentsPath.appendingPathComponent("debug_request_body.txt")
        do {
            // Create readable format of request body
            let requestBodyString = """
            === HTTP Request Details ===
            Method: \(request.httpMethod ?? "Unknown")
            URL: \(request.url?.absoluteString ?? "Unknown")
            
            Headers:
            \(request.allHTTPHeaderFields?.map { "\($0.key): \($0.value)" }.joined(separator: "\n") ?? "None")
            
            Body (Multipart Form Data):
            Boundary: \(boundary)
            Content-Length: \(body.count) bytes
            
            === Original Recording File Path ===
            \(url.path)
            
            === Audio File Information ===
            File size: \(audioData.count) bytes
            File format: WAV
            Sample rate: 16000 Hz
            Channels: 1 (Mono)
            Bit depth: 16 bit
            
            === Timestamp ===
            \(Date())
            """
            
            try requestBodyString.write(to: requestBodyURL, atomically: true, encoding: .utf8)
            print("📝 Request details saved to: \(requestBodyURL.path)")
            
            // Copy recording file to more accessible location
            let debugAudioURL = documentsPath.appendingPathComponent("debug_recording.wav")
            try? FileManager.default.removeItem(at: debugAudioURL) // Remove old file
            try FileManager.default.copyItem(at: url, to: debugAudioURL)
            print("🎵 Recording file copied to: \(debugAudioURL.path)")
            
        } catch {
            print("❌ Failed to save debug files: \(error)")
        }
        
        do {
            print("🌐 Sending request to Whisper API...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw OpenAIError.invalidResponse
            }
            
            print("📡 API response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                // Try to parse error information
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API error (\(httpResponse.statusCode)): \(errorString)")
                }
                throw OpenAIError.invalidResponse
            }
            
            // Add response content debugging
            print("📄 Response data size: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response content: \(responseString)")
            } else {
                print("❌ Unable to convert response data to string")
            }
            
            do {
                let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                print("✅ Speech-to-text successful: \(transcriptionResponse.text)")
                return transcriptionResponse.text
            } catch {
                print("❌ JSON parsing failed: \(error)")
                
                // Try to parse possible error response format
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 Attempting to parse error response: \(responseString)")
                    
                    // Check if it's an HTML error page
                    if responseString.lowercased().contains("<html") {
                        print("🚨 HTML response detected, this usually means:")
                        print("  1. API endpoint path is incorrect")
                        print("  2. Proper authentication is required")
                        print("  3. API service configuration issue")
                        
                        if responseString.contains("One API") {
                            print("💡 One API management interface detected, suggestions:")
                            print("  - Check if API endpoint should be: /v1/audio/transcriptions")
                            print("  - Verify API key is correct")
                            print("  - Confirm Whisper model is configured in One API service")
                        }
                        
                        throw OpenAIError.htmlErrorResponse
                    }
                    
                    // Try to parse other error formats
                    if let errorData = responseString.data(using: .utf8),
                       let errorJSON = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                       let errorMessage = errorJSON["error"] as? String {
                        throw OpenAIError.customError(errorMessage)
                    }
                }
                
                throw error
            }
        } catch {
            print("❌ Network request failed: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("  Error code: \(urlError.code.rawValue)")
                print("  Error description: \(urlError.localizedDescription)")
            }
            throw error
        }
    }
    
    // MARK: - GPT-4o Chat Completion with Streaming
    func sendChatMessage(_ message: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    print("💬 Starting chat message sending...")
                    print("  Target URL: \(baseURL)/v1/chat/completions")
                    print("  Message content: \(message)")
                    
                    guard let chatURL = URL(string: "\(baseURL)/v1/chat/completions") else {
                        print("❌ Invalid API URL: \(baseURL)/v1/chat/completions")
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }
                    
                    var request = URLRequest(url: chatURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
                    request.timeoutInterval = 60.0 // Set timeout duration
                    
                    // Build message history
                    var messages: [[String: Any]] = []
                    
                    // Add system message
                    messages.append([
                        "role": "system",
                        "content": "You are Mori, a helpful AI assistant. Please respond in a friendly and helpful manner. Always respond in Simplified Chinese."
                    ])
                    
                    // Add history messages (keep only recent 10 messages to control token count)
                    let recentHistory = Array(conversationHistory.suffix(10))
                    for msg in recentHistory {
                        messages.append([
                            "role": msg.isUser ? "user" : "assistant",
                            "content": msg.content
                        ])
                    }
                    
                    // Add current message
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
                        print("❌ JSON serialization failed: \(error)")
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    print("🔧 Request details:")
                    print("  Method: \(request.httpMethod ?? "Unknown")")
                    print("  URL: \(request.url?.absoluteString ?? "Unknown")")
                    print("  Headers:")
                    if let headers = request.allHTTPHeaderFields {
                        for (key, value) in headers {
                            if key.lowercased().contains("authorization") {
                                print("    \(key): Bearer ****** (Hidden)")
                            } else {
                                print("    \(key): \(value)")
                            }
                        }
                    }
                    
                    // Configure URLSession
                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 60.0
                    config.timeoutIntervalForResource = 120.0
                    config.waitsForConnectivity = true
                    config.allowsCellularAccess = true
                    config.networkServiceType = .default
                    
                    let session = URLSession(configuration: config)
                    
                    // Use streaming request
                    print("🌐 Sending streaming request...")
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("❌ Invalid HTTP response")
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }
                    
                    print("📡 API response status: \(httpResponse.statusCode)")
                    print("📡 Response headers:")
                    for (key, value) in httpResponse.allHeaderFields {
                        print("    \(key): \(value)")
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        print("❌ API error status code: \(httpResponse.statusCode)")
                        
                        // Try to read error information
                        var errorData = Data()
                        for try await byte in asyncBytes {
                            errorData.append(byte)
                        }
                        
                        if let errorString = String(data: errorData, encoding: .utf8) {
                            print("❌ Error details: \(errorString)")
                        }
                        
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }
                    
                    // Handle streaming response
                    print("📡 Starting to process streaming response...")
                    var hasReceivedData = false
                    
                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                print("✅ Streaming response completed")
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
                                    print("⚠️ Failed to parse streaming response: \(error)")
                                    print("  Raw data: \(jsonString)")
                                    // Continue processing next line, don't interrupt entire stream
                                }
                            }
                        }
                    }
                    
                    if !hasReceivedData {
                        print("⚠️ No valid data received")
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                    } else {
                        print("✅ Streaming response ended normally")
                        continuation.finish()
                    }
                    
                } catch {
                    print("❌ Chat request failed: \(error.localizedDescription)")
                    if let urlError = error as? URLError {
                        print("  Error code: \(urlError.code.rawValue)")
                        print("  Error description: \(urlError.localizedDescription)")
                        
                        // Provide specific error suggestions
                        switch urlError.code {
                        case .notConnectedToInternet:
                            print("💡 Suggestion: Check network connection")
                        case .timedOut:
                            print("💡 Suggestion: Request timed out, please retry")
                        case .cannotFindHost:
                            print("💡 Suggestion: Check if API endpoint URL is correct")
                        case .cannotConnectToHost:
                            print("💡 Suggestion: Check if API service is available")
                        default:
                            print("💡 Suggestion: Check network settings and API configuration")
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
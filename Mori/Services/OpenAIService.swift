import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL: String
    private let calendarMCP = CalendarMCP()
    
    private func generateSystemMessage() -> String {
        let toolsDescription = CalendarMCP.getToolDescription()
        
        // Format current date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let currentDate = dateFormatter.string(from: Date())
        
        let systemMessage = """
        You are a helpful assistant with access to these tools:

        \(toolsDescription)

        Current date: \(currentDate)

        Choose the appropriate tool based on the user's question. If no tool is needed, reply directly.

        IMPORTANT: When you need to use a tool, you must respond with the exact JSON object format below:
        {
            "tool": "tool-name",
            "arguments": {
                "argument-name": "value"
            }
        }

        After receiving tool responses:
        1. Transform the raw data into a natural, conversational response
        2. Keep responses concise but informative
        3. Focus on the most relevant information
        4. Use appropriate context from the user's question
        5. Avoid simply repeating the raw data

        Please use only the tools that are explicitly defined above.
        """
        
        print("🤖 Generated system message:")
        print("===========================================")
        print(systemMessage)
        print("===========================================")
        
        return systemMessage
    }
    
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
                    
                    // Add system message with tool capabilities
                    messages.append([
                        "role": "system",
                        "content": generateSystemMessage()
                    ])
                    
                    // Add history messages (keep only recent 10 messages to control token count)
                    let recentHistory = Array(conversationHistory.suffix(10))
                    for msg in recentHistory {
                        let role = msg.isSystem ? "system" : (msg.isUser ? "user" : "assistant")
                        messages.append([
                            "role": role,
                            "content": msg.content
                        ])
                    }
                    
                    // Add current message
                    messages.append([
                        "role": "user",
                        "content": message
                    ])
                    
                    // Print all messages being sent
                    print("📨 Messages being sent to OpenAI:")
                    for (index, msg) in messages.enumerated() {
                        let role = msg["role"] as? String ?? "unknown"
                        let content = msg["content"] as? String ?? "unknown"
                        print("  [\(index)] \(role.uppercased()): \(content)")
                        print("    ─────────────────────────────────────")
                    }
                    
                    let requestBody: [String: Any] = [
                        "model": "google/gemini-2.5-flash-preview-05-20",
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
    
    // MARK: - Tool Processing
    internal func extractToolCalls(from response: String) -> [ToolCall] {
        print("🔧 Extracting tool calls from response: \(response)")
        
        var toolCalls: [ToolCall] = []
        
        // Find potential JSON objects by looking for balanced braces
        let characters = Array(response)
        var i = 0
        
        while i < characters.count {
            if characters[i] == "{" {
                // Found opening brace, try to find the matching closing brace
                var braceCount = 1
                var j = i + 1
                
                while j < characters.count && braceCount > 0 {
                    if characters[j] == "{" {
                        braceCount += 1
                    } else if characters[j] == "}" {
                        braceCount -= 1
                    }
                    j += 1
                }
                
                if braceCount == 0 {
                    // Found balanced braces, extract the JSON string
                    let startIndex = response.index(response.startIndex, offsetBy: i)
                    let endIndex = response.index(response.startIndex, offsetBy: j)
                    let jsonString = String(response[startIndex..<endIndex])
                    
                    print("🔍 Found potential JSON: \(jsonString)")
                    
                    // Check if this JSON contains "tool" field
                    if jsonString.contains("\"tool\"") {
                        if let jsonData = jsonString.data(using: .utf8) {
                            do {
                                let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                                if let tool = json?["tool"] as? String,
                                   let arguments = json?["arguments"] as? [String: Any] {
                                    let toolCall = ToolCall(tool: tool, arguments: arguments)
                                    toolCalls.append(toolCall)
                                    print("🔧 Found tool call: \(tool) with arguments: \(arguments)")
                                } else {
                                    print("⚠️ JSON doesn't have required tool/arguments fields: \(json ?? [:])")
                                }
                            } catch {
                                print("⚠️ Failed to parse JSON: \(jsonString), error: \(error)")
                            }
                        }
                    }
                    
                    i = j
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }
        
        return toolCalls
    }
    
    private func executeTool(_ toolCall: ToolCall) async throws -> [String: Any] {
        print("🔧 Executing tool: \(toolCall.tool)")
        
        switch toolCall.tool {
        case "read_calendar", "read-calendar":
            return try await calendarMCP.readCalendar(arguments: toolCall.arguments)
        default:
            throw OpenAIError.customError("Unknown tool: \(toolCall.tool)")
        }
    }
    
    // MARK: - Enhanced Chat with Tools
    func sendChatMessageWithTools(_ message: String, conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var currentMessages = conversationHistory
                    var accumulatedResponse = ""
                    var toolExecutionCount = 0
                    let maxToolExecutions = 3 // Prevent infinite loops
                    
                    // Add user message
                    let userMessage = ChatMessage(content: message, isUser: true, timestamp: Date())
                    currentMessages.append(userMessage)
                    
                    while toolExecutionCount < maxToolExecutions {
                        // Print current conversation state
                        print("🔄 Tool execution cycle: \(toolExecutionCount + 1), Current messages count: \(currentMessages.count)")
                        if toolExecutionCount == 0 {
                            print("📨 User message: \(message)")
                        }
                        print("📋 Current conversation history:")
                        for (index, msg) in currentMessages.enumerated() {
                            let role = msg.isSystem ? "SYSTEM" : (msg.isUser ? "USER" : "ASSISTANT")
                            print("  [\(index)] \(role): \(msg.content)")
                            print("    ─────────────────────────────────────")
                        }
                        
                        // Get response from LLM
                        var llmResponse = ""
                        let messageToSend = toolExecutionCount == 0 ? message : ""
                        for try await chunk in sendChatMessage(messageToSend, conversationHistory: currentMessages) {
                            llmResponse += chunk
                            if toolExecutionCount == 0 {
                                // Only yield chunks on first iteration
                                continuation.yield(chunk)
                            }
                        }
                        
                        accumulatedResponse += llmResponse
                        print("🤖 LLM Response: \(llmResponse)")
                        
                        // Extract tool calls
                        let toolCalls = extractToolCalls(from: llmResponse)
                        
                        if toolCalls.isEmpty {
                            // No tools to execute, we're done
                            print("✅ No tools found, conversation complete")
                            if toolExecutionCount > 0 {
                                // If this is a subsequent iteration, yield the final response
                                continuation.yield(llmResponse)
                            }
                            break
                        }
                        
                        print("🔧 Found \(toolCalls.count) tool calls to execute")
                        
                        // Execute tools and collect responses
                        var toolResponses: [String] = []
                        for toolCall in toolCalls {
                            print("🔧 Executing tool: \(toolCall.tool) with arguments: \(toolCall.arguments)")
                            do {
                                let toolResult = try await executeTool(toolCall)
                                let toolResponseText = "Tool \(toolCall.tool) executed successfully: \(toolResult)"
                                toolResponses.append(toolResponseText)
                                print("✅ Tool \(toolCall.tool) response: \(toolResult)")
                            } catch {
                                let errorText = "Tool \(toolCall.tool) failed: \(error.localizedDescription)"
                                toolResponses.append(errorText)
                                print("❌ Tool \(toolCall.tool) error: \(error)")
                            }
                        }
                        
                        // Add LLM response as assistant message
                        let assistantMessage = ChatMessage(content: llmResponse, isUser: false, timestamp: Date())
                        currentMessages.append(assistantMessage)
                        
                        // Add tool responses as system messages
                        for toolResponse in toolResponses {
                            let systemMessage = ChatMessage(content: toolResponse, isUser: false, timestamp: Date(), isSystem: true)
                            currentMessages.append(systemMessage)
                        }
                        
                        toolExecutionCount += 1
                        
                        // If this isn't the first iteration, clear accumulated response for next cycle
                        if toolExecutionCount > 1 {
                            accumulatedResponse = ""
                        }
                    }
                    
                    if toolExecutionCount >= maxToolExecutions {
                        print("⚠️ Maximum tool execution cycles reached")
                    }
                    
                    continuation.finish()
                    
                } catch {
                    print("❌ Chat with tools failed: \(error.localizedDescription)")
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

// MARK: - Tool Models
struct ToolCall {
    let tool: String
    let arguments: [String: Any]
    
    init(tool: String, arguments: [String: Any]) {
        self.tool = tool
        self.arguments = arguments
    }
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
import Foundation

// MARK: - Simplified LLM Service
class LLMAIService: ObservableObject {
    private let calendarMCP = CalendarMCP()
    
    // Task management for streaming cancellation
    private var currentStreamingTask: Task<Void, Never>?
    
    // Fixed API endpoints
    private let textCompletionURL = "https://mori-api-test.meogic.com/text"
    private let speechToTextURL = "https://mori-api-test.meogic.com/stt"

    private let model = "deepseek-chat"
    
    init() {
        // Simple initialization - no configuration needed
    }
    
    // MARK: - Streaming Control
    func cancelStreaming() {
        print("🛑 Cancelling streaming request...")
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
    }
    
    // Check if currently streaming
    var isStreamingActive: Bool {
        return currentStreamingTask != nil && !(currentStreamingTask?.isCancelled ?? true)
    }
    
    internal func generateSystemMessage() -> String {
        // Read system message template from bundle
        guard let templatePath = Bundle.main.path(forResource: "SystemMessage", ofType: "md"),
              let template = try? String(contentsOfFile: templatePath) else {
            print("⚠️ Failed to load SystemMessage.md, using fallback")
            return getFallbackSystemMessage()
        }
        
        let toolsDescription = CalendarMCP.getToolDescription()
        
        // Format current date by iso
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        let currentDate = dateFormatter.string(from: Date())
        
        // Get user's preferred language
        let userLanguage = Locale.preferredLanguages.first ?? "en"
        let languageDisplayName = Locale.current.localizedString(forLanguageCode: userLanguage) ?? userLanguage
        
        // Replace placeholders in template
        let systemMessage = template
            .replacingOccurrences(of: "{{CURRENT_DATE}}", with: currentDate)
            .replacingOccurrences(of: "{{USER_LANGUAGE}}", with: userLanguage)
            .replacingOccurrences(of: "{{LANGUAGE_DISPLAY_NAME}}", with: languageDisplayName)
            .replacingOccurrences(of: "{{TOOLS_DESCRIPTION}}", with: toolsDescription)
        
        return systemMessage
    }
    
    // Fallback system message in case template file cannot be loaded
    internal func getFallbackSystemMessage() -> String {
        let toolsDescription = CalendarMCP.getToolDescription()
        
        // Format current date by iso
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        let currentDate = dateFormatter.string(from: Date())
        
        // Get user's preferred language
        let userLanguage = Locale.preferredLanguages.first ?? "en"
        let languageDisplayName = Locale.current.localizedString(forLanguageCode: userLanguage) ?? userLanguage
        
        return """
        You are Mori, a helpful AI assistant with access to calendar management tools.

        Current date and time: \(currentDate)
        User's preferred language: \(userLanguage) (\(languageDisplayName))

        Available Tools:
        \(toolsDescription)

        ## Language Instructions:
        - Always respond in the user's preferred language: \(languageDisplayName)
        - If the user's language is not supported, respond in English
        - Keep technical terms and tool names in English when necessary

        ## Tool Usage Instructions:
        1. Analyze the user's request to determine if tools are needed
        2. When using tools, first say something nicely, then respond with valid JSON format (no comments):
        
        Single tool:
        ```json
        {
            "tool": "tool-name",
            "arguments": {
                "param": "value"
            }
        }
        ```

        Multiple tools:
        ```json
        [{
            "tool": "tool-name-1",
            "arguments": {
                "param": "value"
            }
        },
        {
            "tool": "tool-name-2", 
            "arguments": {
                "param": "value"
            }
        }]
        ```
        
        ## Response Guidelines:
        - After tool execution, provide natural, conversational responses
        - Focus on the most relevant information from tool results
        - Be concise but informative
        - Use context from the user's original question
        - Don't repeat raw data - transform it into useful insights
        - Take action when requested (don't ask for confirmation unless critical)

        Always prioritize helping the user accomplish their calendar management tasks efficiently.
        """
    }
    
    // MARK: - Generate Request Body
    func generateRequestBodyJSON(from conversationHistory: [MessageListItemType]) -> [String: Any] {
        // Build message history
        var messages: [[String: Any]] = []
        
        // Add system message with tool capabilities
        messages.append([
            "role": "system",
            "content": generateSystemMessage()
        ])

        // Format current date by iso
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        let currentDate = dateFormatter.string(from: Date())
        
        // Add history messages (keep only recent 10 messages to control token count)
        let recentHistory = Array(conversationHistory.suffix(10))
        for item in recentHistory {
            switch item {
            case .chatMessage(let msg):
                // Determine role based on message properties
                let role: String = msg.isSystem ? "system" : (msg.isUser ? "user" : "assistant")
                if role == "user" {
                    messages.append([
                        "role": role,
                        "content": msg.content + "\n\nCurrent Time: \(currentDate)"
                    ])
                } else {
                    messages.append([
                        "role": role,
                        "content": msg.content
                    ])
                }
                
            case .workflowStep(let step):
                // Convert workflow step to system message for LLM context
                let stepContent = "Tool \(step.toolName) executed successfully: \(step.details)"
                messages.append([
                    "role": "user",
                    "content": stepContent
                ])
            }
        }
        
        let requestBody: [String: Any] = [
            "messages": messages,
            "model": model,
            "stream": true,
            "temperature": 0
        ]
        
        return requestBody
    }
    
    // MARK: - Chat Completion with Streaming
    func sendChatMessage(conversationHistory: [MessageListItemType]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    print("💬 Starting chat message sending...")
                    print("  Target URL: \(textCompletionURL)")
                    
                    guard let chatURL = URL(string: textCompletionURL) else {
                        print("❌ Invalid API URL: \(textCompletionURL)")
                        continuation.finish(throwing: LLMError.invalidResponse)
                        return
                    }
                    
                    var request = URLRequest(url: chatURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue("keep-alive", forHTTPHeaderField: "Connection")
                    request.timeoutInterval = 60.0 // Set timeout duration
                    
                    // Generate request body using the dedicated method
                    let requestBody = generateRequestBodyJSON(from: conversationHistory)
                    
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    } catch {
                        print("❌ JSON serialization failed: \(error)")
                        continuation.finish(throwing: error)
                        return
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
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("❌ Invalid HTTP response")
                        continuation.finish(throwing: LLMError.invalidResponse)
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        print("❌ API error status code: \(httpResponse.statusCode)")
                        
                                            // Try to read error information
                    var errorData = Data()
                    for try await byte in asyncBytes {
                        errorData.append(byte)
                    }
                    
                    let errorString = String(data: errorData, encoding: .utf8)
                    if let errorString = errorString {
                        print("❌ Error details: \(errorString)")
                    }
                    
                    // Throw specific error based on status code with error details
                    if httpResponse.statusCode >= 500 {
                        continuation.finish(throwing: LLMError.serverUnavailable(httpResponse.statusCode, errorString))
                    } else if httpResponse.statusCode >= 400 {
                        continuation.finish(throwing: LLMError.clientError(httpResponse.statusCode, errorString))
                    } else {
                        continuation.finish(throwing: LLMError.invalidResponse)
                    }
                        return
                    }
                    
                    // Handle streaming response
                    print("📡 Starting to process streaming response...")
                    var hasReceivedData = false
                    
                    for try await line in asyncBytes.lines {
                        // Check for cancellation during streaming
                        try Task.checkCancellation()
                        
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
                        continuation.finish(throwing: LLMError.invalidResponse)
                    } else {
                        print("✅ Streaming response ended normally")
                        continuation.finish()
                    }
                    
                } catch is CancellationError {
                    print("🛑 Chat request was cancelled by user")
                    continuation.finish()
                } catch {
                    print("❌ Chat request failed: \(error.localizedDescription)")
                    
                    // Handle specific network errors
                    if let urlError = error as? URLError {
                        print("  Error code: \(urlError.code.rawValue)")
                        print("  Error description: \(urlError.localizedDescription)")
                        
                        // Provide specific error suggestions and throw appropriate LLMError
                        switch urlError.code {
                        case .notConnectedToInternet:
                            print("💡 Suggestion: Check network connection")
                            continuation.finish(throwing: LLMError.networkError(urlError))
                        case .timedOut:
                            print("💡 Suggestion: Request timed out, please retry")
                            continuation.finish(throwing: LLMError.connectionTimeout)
                        case .cannotFindHost, .cannotConnectToHost:
                            print("💡 Suggestion: Check if API endpoint URL is correct and service is available")
                            continuation.finish(throwing: LLMError.networkError(urlError))
                        default:
                            print("💡 Suggestion: Check network settings and API configuration")
                            continuation.finish(throwing: LLMError.networkError(urlError))
                        }
                    } else {
                        // For other types of errors, pass them through
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Speech to Text
    func transcribeAudio(data: Data) async throws -> String {
        print("🎤 Starting speech-to-text transcription...")
        
        guard let sttURL = URL(string: speechToTextURL) else {
            print("❌ Invalid STT URL: \(speechToTextURL)")
            throw LLMError.invalidResponse
        }
        
        var request = URLRequest(url: sttURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Get user's preferred language and create prompt
        let userLanguage = Locale.preferredLanguages.first ?? "en"
        // Extract ISO-639-1 language code (first 2 characters)
        let iso639Code = String(userLanguage.prefix(2))
        // Use the user's language locale to get localized language name
        let userLocale = Locale(identifier: userLanguage)
        let languageDisplayName = userLocale.localizedString(forIdentifier: userLanguage) ?? "English"
        let promptText = "This is an audio recording in \(languageDisplayName)."
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add language parameter (ISO-639-1 format)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(iso639Code)\r\n".data(using: .utf8)!)
        
        // Add prompt parameter to guide language recognition
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(promptText)\r\n".data(using: .utf8)!)
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response for STT")
                throw LLMError.invalidResponse
            }
            
            print("🎤 STT response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ STT API error: \(errorString)")
                throw LLMError.transcriptionFailed
            }
            
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            print("✅ STT transcription completed: \(transcriptionResponse.text)")
            return transcriptionResponse.text
            
        } catch {
            print("❌ STT request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Tool Processing
    internal func extractToolCalls(from response: String) -> ([ToolCall], String) {
        print("🔧 Extracting tool calls from response: \(response.prefix(50))...")
        
        var toolCalls: [ToolCall] = []
        var cleanedText = response
        var extractedRanges: [Range<String.Index>] = []
        
        // Extract JSON code blocks (```json...```)
        let codeBlockPattern = "```json\\s*([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(location: 0, length: response.utf16.count)
            let matches = regex.matches(in: response, options: [], range: nsRange)
            
            for match in matches.reversed() { // Process in reverse to maintain string indices
                if match.numberOfRanges >= 2 {
                    let jsonRange = match.range(at: 1)
                    let fullRange = match.range(at: 0)
                    
                    if let jsonSwiftRange = Range(jsonRange, in: response),
                       let fullSwiftRange = Range(fullRange, in: response) {
                        let jsonString = String(response[jsonSwiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        print("🔍 Found JSON code block: \(jsonString.prefix(100))...")
                        
                        // Try to parse the JSON
                        if let jsonData = jsonString.data(using: .utf8) {
                            do {
                                let data = try JSONSerialization.jsonObject(with: jsonData)
                                
                                // Handle single tool call object
                                if let objectData = data as? [String: Any] {
                                    if let tool = objectData["tool"] as? String,
                                       let arguments = objectData["arguments"] as? [String: Any] {
                                        let toolCall = ToolCall(tool: tool, arguments: arguments)
                                        toolCalls.append(toolCall)
                                        extractedRanges.append(fullSwiftRange)
                                        print("🔧 Found tool call from code block: \(tool)")
                                    }
                                }
                                // Handle array of tool calls
                                else if let arrayData = data as? [[String: Any]] {
                                    var validTools = true
                                    var tempToolCalls: [ToolCall] = []
                                    
                                    for item in arrayData {
                                        if let tool = item["tool"] as? String,
                                           let arguments = item["arguments"] as? [String: Any] {
                                            tempToolCalls.append(ToolCall(tool: tool, arguments: arguments))
                                        } else {
                                            validTools = false
                                            break
                                        }
                                    }
                                    
                                    if validTools {
                                        toolCalls.append(contentsOf: tempToolCalls)
                                        extractedRanges.append(fullSwiftRange)
                                        print("🔧 Found \(tempToolCalls.count) tool calls from code block array")
                                    }
                                }
                            } catch {
                                print("⚠️ Failed to parse JSON from code block: \(error)")
                            }
                        }
                    }
                }
            }
        }
        
        // Build the cleaned text by removing the extracted JSON code blocks
        if !extractedRanges.isEmpty {
            var cleanedParts: [String] = []
            var lastEndIndex = response.startIndex
            
            // Sort ranges to process them in order
            let sortedRanges = extractedRanges.sorted { $0.lowerBound < $1.lowerBound }
            
            for range in sortedRanges {
                // Add text before this JSON code block
                cleanedParts.append(String(response[lastEndIndex..<range.lowerBound]))
                lastEndIndex = range.upperBound
            }
            
            // Add remaining text after the last JSON code block
            cleanedParts.append(String(response[lastEndIndex..<response.endIndex]))
            
            cleanedText = cleanedParts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            print("🧹 Cleaned text after removing JSON code blocks: \(cleanedText)")
        }
        
        return (toolCalls, cleanedText)
    }
    
    private func executeTool(_ toolCall: ToolCall) async throws -> [String: Any] {
        switch toolCall.tool {
        case "read-calendar":
            return try await calendarMCP.readCalendar(arguments: toolCall.arguments)
        case "update-calendar":
            return try await calendarMCP.updateCalendar(arguments: toolCall.arguments)
        case "add-calendar":
            return try await calendarMCP.addCalendar(arguments: toolCall.arguments)
        case "remove-calendar":
            return try await calendarMCP.removeCalendar(arguments: toolCall.arguments)
        default:
            throw LLMError.customError("Unknown tool: \(toolCall.tool)")
        }
    }
    
    // MARK: - Enhanced Chat with Tools
    func sendChatMessageWithTools(conversationHistory: [MessageListItemType]) -> AsyncThrowingStream<(String, String), Error> {
        return AsyncThrowingStream { continuation in
            let streamingTask = Task {
                do {
                    var currentMessages = conversationHistory
                    var accumulatedResponse = ""
                    var toolExecutionCount = 0
                    let maxToolExecutions = 3 // Prevent infinite loops
                    
                    // Emit initial status
                    if toolExecutionCount == 0 {
                        continuation.yield(("status", "🧠 Processing request..."))
                    }
                    
                    // Check for cancellation
                    try Task.checkCancellation()
                    
                    while toolExecutionCount < maxToolExecutions {
                        // Check for cancellation
                        try Task.checkCancellation()
                        
                        // Emit thinking status
                        continuation.yield(("status", "💬 Streaming response..."))
                        
                        // Get response from LLM
                        var llmResponse = ""
                        for try await chunk in sendChatMessage(conversationHistory: currentMessages) {
                            // Check for cancellation during streaming
                            try Task.checkCancellation()
                            llmResponse += chunk
                            continuation.yield(("response", chunk))
                        }
                        
                        accumulatedResponse += llmResponse
                        print("🤖 LLM Response: \(llmResponse)")
                        
                        // Extract tool calls and get cleaned text
                        let (toolCalls, cleanedResponse) = extractToolCalls(from: llmResponse)
                        
                        if toolCalls.isEmpty {
                            // No tools to execute, we're done
                            print("✅ No tools found, conversation complete")
                            if toolExecutionCount > 0 {
                                // If this is a subsequent iteration, yield the final response
                                let responseToYield = cleanedResponse.isEmpty ? llmResponse : cleanedResponse
                                continuation.yield(("response", responseToYield))
                            }
                            // Send the final cleaned response
                            let finalResponse = cleanedResponse.isEmpty ? llmResponse : cleanedResponse
                            continuation.yield(("replace_response", finalResponse))
                            break
                        }
                        
                        print("🔧 Found \(toolCalls.count) tool calls to execute")
                        
                        // Execute tools and collect responses
                        var toolResponses: [String] = []
                        for toolCall in toolCalls {
                            // Check for cancellation before each tool execution
                            try Task.checkCancellation()
                            
                            print("🔧 Executing tool: \(toolCall.tool) with arguments: \(toolCall.arguments)")
                            
                            // Emit tool call status
                            continuation.yield(("tool_call", toolCall.tool))
                            
                            // Emit tool arguments
                            do {
                                let argumentsData = try JSONSerialization.data(withJSONObject: toolCall.arguments, options: [])
                                if let argumentsString = String(data: argumentsData, encoding: .utf8) {
                                    continuation.yield(("tool_arguments", argumentsString))
                                }
                            } catch {
                                print("⚠️ Failed to serialize tool arguments: \(error)")
                            }
                            
                            // Emit tool execution status
                            continuation.yield(("tool_execution", "Executing \(toolCall.tool)..."))
                            
                            do {
                                let toolResult = try await executeTool(toolCall)
                                let toolResponseText = "Tool \(toolCall.tool) executed successfully: \(toolResult)"
                                toolResponses.append(toolResponseText)
                                
                                // Emit tool result
                                do {
                                    let resultData = try JSONSerialization.data(withJSONObject: toolResult, options: .prettyPrinted)
                                    if let resultString = String(data: resultData, encoding: .utf8) {
                                        continuation.yield(("tool_results", resultString))
                                        print("✅ Tool \(toolCall.tool) response: \(resultString.prefix(50))...")
                                    }
                                } catch {
                                    continuation.yield(("tool_results", "\(toolResult)"))
                                }
                                
                            } catch {
                                let errorText = "Tool \(toolCall.tool) failed: \(error.localizedDescription)"
                                toolResponses.append(errorText)
                                
                                // Emit tool error
                                continuation.yield(("error", "Tool \(toolCall.tool) failed: \(error.localizedDescription)"))
                                
                                print("❌ Tool \(toolCall.tool) error: \(error)")
                            }
                        }
                        
                        // Update local currentMessages for next iteration
                        let assistantContent = cleanedResponse.isEmpty ? llmResponse : cleanedResponse
                        let assistantMessage = ChatMessage(content: assistantContent, isUser: false, timestamp: Date())
                        currentMessages.append(.chatMessage(assistantMessage))
                        
                        for toolResponse in toolResponses {
                            // This must be role as system, otherwise assistant will return tool call next time!
                            let systemMessage = ChatMessage(content: toolResponse, isUser: true, timestamp: Date(), isSystem: false)
                            currentMessages.append(.chatMessage(systemMessage))
                            print("📦 Added tool result to message history: \(toolResponse.prefix(50))...")
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
                    
                } catch is CancellationError {
                    print("🛑 Streaming was cancelled by user")
                    continuation.yield(("status", "Cancelled by user"))
                    continuation.finish()
                } catch {
                    print("❌ Chat with tools failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
            
            // Store the streaming task for cancellation support
            currentStreamingTask = streamingTask
            
            // Clean up when stream ends
            Task.detached { [weak self] in
                _ = await streamingTask.result
                await MainActor.run {
                    self?.currentStreamingTask = nil
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
enum LLMError: Error, LocalizedError {
    case invalidResponse
    case noAudioData
    case transcriptionFailed
    case htmlErrorResponse
    case networkError(URLError)
    case connectionTimeout
    case serverUnavailable(Int, String?) // HTTP status code and error details
    case clientError(Int, String?) // HTTP 4xx errors with details
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
        case .networkError(let urlError):
            return "Network error: \(urlError.localizedDescription)"
        case .connectionTimeout:
            return "Connection timeout - please check your network"
        case .serverUnavailable(let statusCode, let details):
            if let details = details, !details.isEmpty {
                return "Server unavailable (HTTP \(statusCode)): \(details)"
            } else {
                return "Server unavailable (HTTP \(statusCode))"
            }
        case .clientError(let statusCode, let details):
            if let details = details, !details.isEmpty {
                return "Client error (HTTP \(statusCode)): \(details)"
            } else {
                return "Client error (HTTP \(statusCode))"
            }
        case .customError(let message):
            return "Custom error: \(message)"
        }
    }
} 
import Foundation

// MARK: - Provider Types
enum LLMProviderType: String, CaseIterable {
    case openRouter = "openRouter"
    case openai = "openai"
    
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .openRouter:
            return "OpenRouter"
        }
    }
}

// MARK: - Provider Configuration
struct LLMProviderConfig {
    let type: LLMProviderType
    let apiKey: String
    let baseURL: String
    let model: String
    
    init(type: LLMProviderType, apiKey: String, baseURL: String? = nil, model: String? = nil) {
        self.type = type
        self.apiKey = apiKey
        
        // Set default baseURL based on provider type
        switch type {
        case .openai:
            self.baseURL = baseURL ?? "https://api.openai.com"
        case .openRouter:
            self.baseURL = baseURL ?? "https://openrouter.ai/api"
        }
        
        // Set default model based on provider type
        switch type {
        case .openai:
            self.model = model ?? "gpt-4o-2024-11-20"
        case .openRouter:
            self.model = model ?? "deepseek/deepseek-chat-v3-0324"
        }
    }
}

class LLMAIService: ObservableObject {
    private let config: LLMProviderConfig
    private let calendarMCP = CalendarMCP()
    
    private func generateSystemMessage() -> String {
        let toolsDescription = CalendarMCP.getToolDescription()
        
        // Format current date by iso
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        let currentDate = dateFormatter.string(from: Date())
        
        let systemMessage = """
        You are Mori, a helpful AI assistant with access to calendar management tools.

        Available Tools:
        \(toolsDescription)

        Current date and time: \(currentDate)

        ## Tool Usage Instructions:
        1. Analyze the user's request to determine if tools are needed
        2. When using tools, respond with valid JSON format (no comments):
        
        Single tool:
        {
            "tool": "tool-name",
            "arguments": {
                "param": "value"
            }
        }
        
        Multiple tools:
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

        ## Response Guidelines:
        - After tool execution, provide natural, conversational responses
        - Focus on the most relevant information from tool results
        - Be concise but informative
        - Use context from the user's original question
        - Don't repeat raw data - transform it into useful insights
        - Take action when requested (don't ask for confirmation unless critical)

        Always prioritize helping the user accomplish their calendar management tasks efficiently.
        """
        return systemMessage
    }
    
    init(config: LLMProviderConfig) {
        self.config = config
    }
    
    // Convenience initializer for backward compatibility
    init(apiKey: String, customBaseURL: String? = nil) {
        // Default to OpenRouter for backward compatibility
        let baseURL = customBaseURL?.isEmpty == false ? customBaseURL! : "https://openrouter.ai/api"
        self.config = LLMProviderConfig(
            type: .openRouter,
            apiKey: apiKey,
            baseURL: baseURL,
            model: "deepseek/deepseek-chat-v3-0324"
        )
    }
    
    // MARK: - Generate Request Body
    func generateRequestBodyJSON(from conversationHistory: [ChatMessage]) -> [String: Any] {
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
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "stream": true,
            "temperature": 0
        ]
        
        return requestBody
    }
    
    // MARK: - Chat Completion with Streaming
    func sendChatMessage(conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    print("💬 Starting chat message sending...")
                    print("  Provider: \(config.type.displayName)")
                    print("  Model: \(config.model)")
                    print("  Target URL: \(config.baseURL)/v1/chat/completions")
                    
                    guard let chatURL = URL(string: "\(config.baseURL)/v1/chat/completions") else {
                        print("❌ Invalid API URL: \(config.baseURL)/v1/chat/completions")
                        continuation.finish(throwing: LLMError.invalidResponse)
                        return
                    }
                    
                    var request = URLRequest(url: chatURL)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
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
                        
                        if let errorString = String(data: errorData, encoding: .utf8) {
                            print("❌ Error details: \(errorString)")
                        }
                        
                        continuation.finish(throwing: LLMError.invalidResponse)
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
                        continuation.finish(throwing: LLMError.invalidResponse)
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
    internal func extractToolCalls(from response: String) -> ([ToolCall], String) {
        print("🔧 Extracting tool calls from response: \(response.prefix(50))...")
        
        var toolCalls: [ToolCall] = []
        var cleanedText = response
        var extractedRanges: [Range<String.Index>] = []
        
        // First try to parse the entire text as a single JSON array or object
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if let jsonData = trimmedResponse.data(using: .utf8) {
            do {
                let data = try JSONSerialization.jsonObject(with: jsonData)
                var isValidToolCall = false
                
                if let arrayData = data as? [[String: Any]] {
                    // Check if it's a list of tool calls
                    var validTools = true
                    for item in arrayData {
                        if !(item["tool"] is String && item["arguments"] is [String: Any]) {
                            validTools = false
                            break
                        }
                    }
                    if validTools {
                        for item in arrayData {
                            if let tool = item["tool"] as? String,
                               let arguments = item["arguments"] as? [String: Any] {
                                let toolCall = ToolCall(tool: tool, arguments: arguments)
                                toolCalls.append(toolCall)
                            }
                        }
                        isValidToolCall = true
                    }
                } else if let objectData = data as? [String: Any] {
                    // Check if it's a single tool call
                    if let tool = objectData["tool"] as? String,
                       let arguments = objectData["arguments"] as? [String: Any] {
                        let toolCall = ToolCall(tool: tool, arguments: arguments)
                        toolCalls.append(toolCall)
                        isValidToolCall = true
                    }
                }
                
                if isValidToolCall {
                    print("🔧 Successfully parsed entire response as tool call(s)")
                    return (toolCalls, "") // Return empty string as cleaned text
                }
            } catch {
                // Continue to regex matching if direct parsing fails
                print("🔍 Direct JSON parsing failed, trying regex approach: \(error)")
            }
        }
        
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
                                    
                                    // Record the range for removal
                                    extractedRanges.append(startIndex..<endIndex)
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
        
        // Build the cleaned text by removing the extracted JSON parts
        if !extractedRanges.isEmpty {
            var cleanedParts: [String] = []
            var lastEndIndex = response.startIndex
            
            // Sort ranges to process them in order
            let sortedRanges = extractedRanges.sorted { $0.lowerBound < $1.lowerBound }
            
            for range in sortedRanges {
                // Add text before this JSON range
                cleanedParts.append(String(response[lastEndIndex..<range.lowerBound]))
                lastEndIndex = range.upperBound
            }
            
            // Add remaining text after the last JSON range
            cleanedParts.append(String(response[lastEndIndex..<response.endIndex]))
            
            cleanedText = cleanedParts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            print("🧹 Cleaned text after removing JSON: \(cleanedText)")
        }
        
        return (toolCalls, cleanedText)
    }
    
    private func executeTool(_ toolCall: ToolCall) async throws -> [String: Any] {
        print("🔧 Executing tool: \(toolCall.tool)")
        
        switch toolCall.tool {
        case "read-calendar":
            return try await calendarMCP.readCalendar(arguments: toolCall.arguments)
        case "update-calendar":
            return try await calendarMCP.updateCalendar(arguments: toolCall.arguments)
        default:
            throw LLMError.customError("Unknown tool: \(toolCall.tool)")
        }
    }
    
    // MARK: - Enhanced Chat with Tools
    func sendChatMessageWithTools(conversationHistory: [ChatMessage]) -> AsyncThrowingStream<(String, String), Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var currentMessages = conversationHistory
                    var accumulatedResponse = ""
                    var toolExecutionCount = 0
                    let maxToolExecutions = 3 // Prevent infinite loops
                    
                    // Emit initial status
                    if toolExecutionCount == 0 {
                        continuation.yield(("status", "🧠 Processing request..."))
                    }
                    
                    while toolExecutionCount < maxToolExecutions {
                        // Emit thinking status
                        continuation.yield(("status", "💬 Streaming response..."))
                        
                        // Get response from LLM
                        var llmResponse = ""
                        for try await chunk in sendChatMessage(conversationHistory: currentMessages) {
                            llmResponse += chunk
                            if toolExecutionCount == 0 {
                                // Only yield chunks on first iteration
                                continuation.yield(("response", chunk))
                            }
                        }
                        
                        accumulatedResponse += llmResponse
                        print("🤖 LLM Response: \(llmResponse.prefix(50))...")
                        
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
                        currentMessages.append(assistantMessage)
                        
                        for toolResponse in toolResponses {
                            let systemMessage = ChatMessage(content: toolResponse, isUser: true, timestamp: Date(), isSystem: false)
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
enum LLMError: Error, LocalizedError {
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
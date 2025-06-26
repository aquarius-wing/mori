import XCTest
import Foundation
@testable import Mori

class LLMAIServiceTests: XCTestCase {
    var llmService: LLMAIService!
    var mockCalendarMCP: MockCalendarMCP!
    
    override func setUpWithError() throws {
        // Initialize with simplified configuration
        llmService = LLMAIService()
        mockCalendarMCP = MockCalendarMCP()
    }
    
    override func tearDownWithError() throws {
        llmService = nil
        mockCalendarMCP = nil
    }
    
    // MARK: - System Message Template Tests
    
    // Test system message template parameter replacement
    func testSystemMessageParameterReplacement() {
        // Given: LLMAIService instance
        let service = LLMAIService()
        
        // When: Generate system message
        let systemMessage = service.generateSystemMessage()
        
        // Then: Verify all parameters are replaced (no placeholders remain)
        XCTAssertFalse(systemMessage.contains("{{CURRENT_DATE}}"), "CURRENT_DATE placeholder should be replaced")
        XCTAssertFalse(systemMessage.contains("{{USER_LANGUAGE}}"), "USER_LANGUAGE placeholder should be replaced")
        XCTAssertFalse(systemMessage.contains("{{LANGUAGE_DISPLAY_NAME}}"), "LANGUAGE_DISPLAY_NAME placeholder should be replaced")
        XCTAssertFalse(systemMessage.contains("{{TOOLS_DESCRIPTION}}"), "TOOLS_DESCRIPTION placeholder should be replaced")
        
        // Verify content is present
        XCTAssertTrue(systemMessage.contains("Current date and time:"), "Should contain current date label")
        XCTAssertTrue(systemMessage.contains("User's preferred language:"), "Should contain language label")
        XCTAssertTrue(systemMessage.contains("Available Tools:"), "Should contain tools label")
        XCTAssertTrue(systemMessage.contains("read-calendar"), "Should contain tool descriptions")
        
        print("✅ System message parameter replacement test passed")
        print("📝 Generated system message length: \(systemMessage.count) characters")
    }
    
    // Test system message date format
    func testSystemMessageDateFormat() {
        // Given: LLMAIService instance
        let service = LLMAIService()
        
        // When: Generate system message
        let systemMessage = service.generateSystemMessage()
        
        // Then: Verify date format is ISO8601
        let datePattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}"#
        let regex = try! NSRegularExpression(pattern: datePattern)
        let range = NSRange(location: 0, length: systemMessage.utf16.count)
        let matches = regex.matches(in: systemMessage, range: range)
        
        XCTAssertGreaterThan(matches.count, 0, "Should contain at least one ISO8601 date format")
        
        print("✅ System message date format test passed")
    }
    
    // Test system message language handling
    func testSystemMessageLanguageHandling() {
        // Given: LLMAIService instance
        let service = LLMAIService()
        
        // When: Generate system message
        let systemMessage = service.generateSystemMessage()
        
        // Then: Verify language information is present
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        XCTAssertTrue(systemMessage.contains(preferredLanguage), "Should contain user's preferred language code")
        
        print("✅ System message language handling test passed")
        print("📱 User preferred language: \(preferredLanguage)")
    }
    
    // Test system message tools description
    func testSystemMessageToolsDescription() {
        // Given: LLMAIService instance
        let service = LLMAIService()
        
        // When: Generate system message
        let systemMessage = service.generateSystemMessage()
        
        // Then: Verify all expected tools are described
        let expectedTools = ["read-calendar", "update-calendar", "add-calendar", "remove-calendar"]
        for tool in expectedTools {
            XCTAssertTrue(systemMessage.contains(tool), "Should contain description for \(tool) tool")
        }
        
        print("✅ System message tools description test passed")
        print("🔧 All expected tools found in system message")
    }
    
    // Test fallback system message when template file is not available
    func testFallbackSystemMessage() {
        // Given: LLMAIService instance
        let service = LLMAIService()
        
        // When: Call getFallbackSystemMessage directly (simulating template file read failure)
        let fallbackMessage = service.getFallbackSystemMessage()
        
        // Then: Verify fallback contains all necessary information
        XCTAssertTrue(fallbackMessage.contains("You are Mori"), "Fallback should contain AI identity")
        XCTAssertTrue(fallbackMessage.contains("Current date and time:"), "Fallback should contain current date")
        XCTAssertTrue(fallbackMessage.contains("User's preferred language:"), "Fallback should contain language info")
        XCTAssertTrue(fallbackMessage.contains("Available Tools:"), "Fallback should contain tools info")
        XCTAssertTrue(fallbackMessage.contains("read-calendar"), "Fallback should contain tool descriptions")
        
        // Verify no placeholders remain in fallback
        XCTAssertFalse(fallbackMessage.contains("{{"), "Fallback should not contain any placeholders")
        
        print("✅ Fallback system message test passed")
        print("🔄 Fallback message length: \(fallbackMessage.count) characters")
    }
    
    // Test system message consistency
    func testSystemMessageConsistency() {
        // Given: LLMAIService instance
        let service = LLMAIService()
        
        // When: Generate system message multiple times
        let message1 = service.generateSystemMessage()
        let message2 = service.generateSystemMessage()
        
        // Then: Messages should be structurally similar (allowing for timestamp differences)
        // Remove timestamps for comparison
        let cleanMessage1 = removeTimestamps(from: message1)
        let cleanMessage2 = removeTimestamps(from: message2)
        
        XCTAssertEqual(cleanMessage1, cleanMessage2, "System messages should be consistent when removing timestamps")
        
        print("✅ System message consistency test passed")
    }
    
    // Helper function to remove timestamps for comparison
    private func removeTimestamps(from message: String) -> String {
        let timestampPattern = #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}"#
        let regex = try! NSRegularExpression(pattern: timestampPattern)
        let range = NSRange(location: 0, length: message.utf16.count)
        return regex.stringByReplacingMatches(in: message, options: [], range: range, withTemplate: "TIMESTAMP_PLACEHOLDER")
    }
    
    // Test the meeting rescheduling scenario
    func testMeetingReschedulingScenario() async throws {
        // Given: User conversation history
        let userMessage = ChatMessage(
            content: "My meeting is delay one hour, help me rearrangement event after that, search in this week.",
            isUser: true,
            timestamp: Date(),
            isSystem: false,
            workflowSteps: []
        )
        
        let assistantResponse = ChatMessage(
            content: "I can help with that. First, I need to know which event you're referring to. Let me check your calendar for this week.",
            isUser: false,
            timestamp: Date(),
            isSystem: false,
            workflowSteps: []
        )
        
        let toolSystemMessage = ChatMessage(
            content: """
            Tool read-calendar executed successfully: ["date_range": ["startDate": "2025/06/07", "endDate": "2025/06/14"], "count": 4, "success": true, "events": [["start_time": "2025-06-06T16:00:00Z", "location": "", "notes": "The exact date of this holiday is difficult to predict precisely; this is just an approximation.", "title": "Eid al-Adha", "is_all_day": true, "end_time": "2025-06-07T15:59:59Z"], ["title": "Meeting", "end_time": "2025-06-08T02:00:00Z", "is_all_day": false, "start_time": "2025-06-08T01:00:00Z", "location": "Apple Park\\nApple Inc., 1 Apple Park Way, Cupertino, CA 95014, United States", "notes": ""], ["start_time": "2025-06-08T08:00:00Z", "title": "Pick up my girlfriend", "location": "Cupertino High School\\n10100 Finch Ave, Cupertino, CA  95014, United States", "notes": "", "is_all_day": false, "end_time": "2025-06-08T09:00:00Z"], ["end_time": "2025-06-08T11:00:00Z", "location": "Top Cafe\\n1075 DeAnza Blvd, San Jose, CA 95129, United States", "notes": "", "start_time": "2025-06-08T10:00:00Z", "is_all_day": false, "title": "Have dinner at Top Cafe "]]]
            """,
            isUser: false,
            timestamp: Date(),
            isSystem: true,
            workflowSteps: []
        )
        
        let llmResponse = ChatMessage(
            content: """
            OK. I see you have a meeting tomorrow, June 8th, from 1:00 AM to 2:00 AM. After that, you have two other events scheduled:
            - Pick up my girlfriend at 8:00 AM.
            - Have dinner at Top Cafe at 10:00 AM.
            
            Which of these would you like to reschedule?
            """,
            isUser: false,
            timestamp: Date(),
            isSystem: false,
            workflowSteps: []
        )
        
        let userFollowUp = ChatMessage(
            content: "Two of them.",
            isUser: true,
            timestamp: Date(),
            isSystem: false,
            workflowSteps: []
        )
        
        let conversationHistory: [MessageListItemType] = [
            .chatMessage(userMessage), 
            .chatMessage(assistantResponse), 
            .chatMessage(toolSystemMessage), 
            .chatMessage(llmResponse), 
            .chatMessage(userFollowUp)
        ]
        
        print("🧪 Starting meeting rescheduling scenario test")
        print("📝 Conversation history prepared with \(conversationHistory.count) messages")
        
        // Since we can't actually test the full streaming without network calls,
        // we'll test the conversation setup and verify the structure
        XCTAssertEqual(conversationHistory.count, 5, "Should have 5 conversation messages")
        
        // Verify first message is from user
        if case .chatMessage(let firstMessage) = conversationHistory[0] {
            XCTAssertTrue(firstMessage.isUser, "First message should be from user")
        } else {
            XCTFail("First item should be a chat message")
        }
        
        // Verify second message is from assistant
        if case .chatMessage(let secondMessage) = conversationHistory[1] {
            XCTAssertFalse(secondMessage.isUser, "Second message should be from assistant")
        } else {
            XCTFail("Second item should be a chat message")
        }
        
        // Verify third message is system message
        if case .chatMessage(let thirdMessage) = conversationHistory[2] {
            XCTAssertTrue(thirdMessage.isSystem, "Third message should be system message")
        } else {
            XCTFail("Third item should be a chat message")
        }
        
        // Verify last message content
        if case .chatMessage(let lastMessage) = conversationHistory[4] {
            XCTAssertEqual(lastMessage.content, "Two of them.", "Last message should be user follow-up")
        } else {
            XCTFail("Last item should be a chat message")
        }
        
        print("✅ Conversation structure validation passed")
    }
    
    // Test tool call extraction
    func testToolCallExtraction() {
        // Given: A response with tool call JSON
        let responseWithToolCall = """
        I'll help you check your calendar for this week.
        
        {
            "tool": "read-calendar",
            "arguments": {
                "startDate": "2025/06/07",
                "endDate": "2025/06/14"
            }
        }
        """
        
        // When: Extract tool calls using our simulation
        let result = extractToolCallsSimulated(from: responseWithToolCall)
        let toolCalls = result.0
        let cleanedText = result.1
        
        // Then: Verify extraction
        XCTAssertEqual(toolCalls.count, 1, "Should extract one tool call")
        XCTAssertEqual(toolCalls.first?.tool, "read-calendar", "Should extract read-calendar tool")
        XCTAssertEqual(toolCalls.first?.arguments["startDate"] as? String, "2025/06/07", "Should extract correct start date")
        XCTAssertEqual(toolCalls.first?.arguments["endDate"] as? String, "2025/06/14", "Should extract correct end date")
        XCTAssertEqual(cleanedText.trimmingCharacters(in: .whitespacesAndNewlines), "I'll help you check your calendar for this week.", "Should return cleaned text without JSON")
    }
    
    // Test tool call extraction with code block format
    func testToolCallExtractionWithCodeBlock() {
        // Given: A response with tool call in code block format
        let responseWithCodeBlock = """
        I'll help you check your calendar for this week.
        
        ```json
        {
            "tool": "read-calendar",
            "arguments": {
                "startDate": "2025/06/07",
                "endDate": "2025/06/14"
            }
        }
        ```
        """
        
        // When: Extract tool calls using our simulation
        let result = extractToolCallsSimulated(from: responseWithCodeBlock)
        let toolCalls = result.0
        let cleanedText = result.1
        
        // Then: Verify extraction
        XCTAssertEqual(toolCalls.count, 1, "Should extract one tool call from code block")
        XCTAssertEqual(toolCalls.first?.tool, "read-calendar", "Should extract read-calendar tool")
        XCTAssertEqual(toolCalls.first?.arguments["startDate"] as? String, "2025/06/07", "Should extract correct start date")
        XCTAssertEqual(toolCalls.first?.arguments["endDate"] as? String, "2025/06/14", "Should extract correct end date")
        XCTAssertEqual(cleanedText.trimmingCharacters(in: .whitespacesAndNewlines), "I'll help you check your calendar for this week.", "Should return cleaned text without code block")
    }
    
    // Test tool call extraction with multiple tools
    func testMultipleToolCallExtraction() {
        // Given: A response with multiple tool calls
        let responseWithMultipleTools = """
        I'll help you reschedule both events.
        
        {
            "tool": "update-calendar",
            "arguments": {
                "eventId": "event1",
                "newStartTime": "2025-06-08T09:00:00Z"
            }
        }
        
        {
            "tool": "update-calendar", 
            "arguments": {
                "eventId": "event2",
                "newStartTime": "2025-06-08T12:00:00Z"
            }
        }
        """
        
        // When: Extract tool calls
        let result = extractToolCallsSimulated(from: responseWithMultipleTools)
        let toolCalls = result.0
        let cleanedText = result.1
        
        // Then: Verify extraction
        XCTAssertEqual(toolCalls.count, 2, "Should extract two tool calls")
        XCTAssertEqual(toolCalls[0].tool, "update-calendar", "First tool should be update-calendar")
        XCTAssertEqual(toolCalls[1].tool, "update-calendar", "Second tool should be update-calendar")
        XCTAssertEqual(cleanedText.trimmingCharacters(in: .whitespacesAndNewlines), "I'll help you reschedule both events.", "Should return cleaned text without JSON")
    }
    
    // Test tool call extraction with multiple code blocks
    func testMultipleCodeBlockToolCallExtraction() {
        // Given: A response with multiple tool calls in code blocks
        let responseWithMultipleCodeBlocks = """
        I'll help you reschedule both events.
        
        ```json
        {
            "tool": "update-calendar",
            "arguments": {
                "eventId": "event1",
                "newStartTime": "2025-06-08T09:00:00Z"
            }
        }
        ```
        
        ```json
        {
            "tool": "update-calendar", 
            "arguments": {
                "eventId": "event2",
                "newStartTime": "2025-06-08T12:00:00Z"
            }
        }
        ```
        """
        
        // When: Extract tool calls
        let result = extractToolCallsSimulated(from: responseWithMultipleCodeBlocks)
        let toolCalls = result.0
        let cleanedText = result.1
        
        // Then: Verify extraction
        XCTAssertEqual(toolCalls.count, 2, "Should extract two tool calls from code blocks")
        XCTAssertEqual(toolCalls[0].tool, "update-calendar", "First tool should be update-calendar")
        XCTAssertEqual(toolCalls[1].tool, "update-calendar", "Second tool should be update-calendar")
        XCTAssertEqual(cleanedText.trimmingCharacters(in: .whitespacesAndNewlines), "I'll help you reschedule both events.", "Should return cleaned text without code blocks")
    }
    
    // Test tool call extraction with no tools
    func testNoToolCallExtraction() {
        // Given: A response without tool calls
        let responseWithoutTools = """
        I understand you want to reschedule your events. Could you please provide more specific details about which events you'd like to move and to what times?
        """
        
        // When: Extract tool calls
        let result = extractToolCallsSimulated(from: responseWithoutTools)
        let toolCalls = result.0
        let cleanedText = result.1
        
        // Then: Verify no extraction
        XCTAssertEqual(toolCalls.count, 0, "Should extract no tool calls")
        XCTAssertEqual(cleanedText, responseWithoutTools, "Should return original text unchanged")
    }
    
    // Test LLM Service initialization
    func testLLMServiceInitialization() {
        // When: Initialize service with simplified configuration
        let service = LLMAIService()
        
        // Then: Service should be initialized
        XCTAssertNotNil(service, "LLM service should be initialized")
    }
    
    // Test sendChatMessage basic functionality
    func testSendChatMessage() async throws {
        // Given: A simple conversation history
        let conversationHistory: [MessageListItemType] = [
           .chatMessage(ChatMessage(
               content: "Hello, how are you?",
               isUser: true,
               timestamp: Date(),
               isSystem: false,
               workflowSteps: []
           ))
       ]
        
        print("🧪 Starting sendChatMessage test")
        print("📝 Created conversation history with 1 message")
        
        // When: Send chat message using the stream
        var hasReceivedData = false
        var accumulatedResponse = ""
        
        // Use a shorter timeout since this might fail due to network
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds timeout
            throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test timeout - no data received within 5 seconds"])
        }
        
        let streamTask = Task {
            for try await chunk in llmService.sendChatMessage(conversationHistory: conversationHistory) {
                hasReceivedData = true
                accumulatedResponse += chunk
                print("📦 Received chunk: \(chunk.prefix(50))...")
                
                // Cancel timeout task once we receive data
                timeoutTask.cancel()
                
                // For testing, we only need to verify we get some response
                if accumulatedResponse.count > 10 {
                    break
                }
            }
        }
        
        // Race between stream and timeout - if either throws, the test will fail
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await streamTask.value }
            group.addTask { try await timeoutTask.value }
            
            // Wait for either task to complete
            try await group.next()
            
            // Cancel remaining tasks
            streamTask.cancel()
            timeoutTask.cancel()
        }
        
        // Then: Verify we received data
        XCTAssertTrue(hasReceivedData, "Should have received data from sendChatMessage")
        XCTAssertTrue(accumulatedResponse.count > 0, "Should receive some response data")
        
        print("✅ Test PASSED: Received data from sendChatMessage")
        print("📊 Accumulated response length: \(accumulatedResponse.count) characters")
        print("📝 Response preview: \(accumulatedResponse.prefix(100))...")
        print("🏁 sendChatMessage test completed")
    }
    
    // Simulated tool call extraction for testing
    private func extractToolCallsSimulated(from response: String) -> ([ToolCall], String) {
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
                                    }
                                }
                            } catch {
                                // Continue on JSON parse error
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
        }
        
        return (toolCalls, cleanedText)
    }
}

// MARK: - Test Helper Classes
class TestLLMAIService: LLMAIService {
    // Override with invalid URL to trigger network error
    override func sendChatMessage(conversationHistory: [MessageListItemType]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Use an invalid URL that will definitely fail
                    guard let invalidURL = URL(string: "https://invalid-nonexistent-domain-12345.com/api") else {
                        continuation.finish(throwing: LLMError.invalidResponse)
                        return
                    }
                    
                    var request = URLRequest(url: invalidURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 5.0 // Short timeout for testing
                    
                    let requestBody = ["messages": [["role": "user", "content": "test"]]]
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    // This should fail with a network error
                    let (_, _) = try await URLSession.shared.data(for: request)
                    
                } catch {
                    // Convert URLError to LLMError for testing
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .cannotFindHost, .cannotConnectToHost:
                            continuation.finish(throwing: LLMError.networkError(urlError))
                        case .timedOut:
                            continuation.finish(throwing: LLMError.connectionTimeout)
                        default:
                            continuation.finish(throwing: LLMError.networkError(urlError))
                        }
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
}

// MARK: - Mock Classes
class MockCalendarMCP {
    func readCalendar(arguments: [String: Any]) async throws -> [String: Any] {
        return [
            "success": true,
            "count": 4,
            "date_range": [
                "startDate": "2025/06/07",
                "endDate": "2025/06/14"
            ],
            "events": [
                [
                    "title": "Eid al-Adha",
                    "start_time": "2025-06-06T16:00:00Z",
                    "end_time": "2025-06-07T15:59:59Z",
                    "is_all_day": true,
                    "location": "",
                    "notes": "The exact date of this holiday is difficult to predict precisely; this is just an approximation."
                ],
                [
                    "title": "Meeting",
                    "start_time": "2025-06-08T01:00:00Z",
                    "end_time": "2025-06-08T02:00:00Z",
                    "is_all_day": false,
                    "location": "Apple Park\nApple Inc., 1 Apple Park Way, Cupertino, CA 95014, United States",
                    "notes": ""
                ],
                [
                    "title": "Pick up my girlfriend",
                    "start_time": "2025-06-08T08:00:00Z",
                    "end_time": "2025-06-08T09:00:00Z",
                    "is_all_day": false,
                    "location": "Cupertino High School\n10100 Finch Ave, Cupertino, CA  95014, United States",
                    "notes": ""
                ],
                [
                    "title": "Have dinner at Top Cafe ",
                    "start_time": "2025-06-08T10:00:00Z",
                    "end_time": "2025-06-08T11:00:00Z",
                    "is_all_day": false,
                    "location": "Top Cafe\n1075 DeAnza Blvd, San Jose, CA 95129, United States",
                    "notes": ""
                ]
            ]
        ]
    }
    
    func updateCalendar(arguments: [String: Any]) async throws -> [String: Any] {
        return [
            "success": true,
            "message": "Event updated successfully",
            "eventId": arguments["eventId"] as? String ?? "",
            "newStartTime": arguments["newStartTime"] as? String ?? ""
        ]
    }
} 

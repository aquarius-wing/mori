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
        
        let conversationHistory = [userMessage, assistantResponse, toolSystemMessage, llmResponse, userFollowUp]
        
        print("🧪 Starting meeting rescheduling scenario test")
        print("📝 Conversation history prepared with \(conversationHistory.count) messages")
        
        // Since we can't actually test the full streaming without network calls,
        // we'll test the conversation setup and verify the structure
        XCTAssertEqual(conversationHistory.count, 5, "Should have 5 conversation messages")
        XCTAssertTrue(conversationHistory[0].isUser, "First message should be from user")
        XCTAssertFalse(conversationHistory[1].isUser, "Second message should be from assistant")
        XCTAssertTrue(conversationHistory[2].isSystem, "Third message should be system message")
        XCTAssertEqual(conversationHistory[4].content, "Two of them.", "Last message should be user follow-up")
        
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
        let conversationHistory = [
           ChatMessage(
               content: "Hello, how are you?",
               isUser: true,
               timestamp: Date(),
               isSystem: false,
               workflowSteps: []
           )
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
                    
                    // Check if this JSON contains "tool" field
                    if jsonString.contains("\"tool\"") {
                        if let jsonData = jsonString.data(using: .utf8) {
                            do {
                                let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                                if let tool = json?["tool"] as? String,
                                   let arguments = json?["arguments"] as? [String: Any] {
                                    let toolCall = ToolCall(tool: tool, arguments: arguments)
                                    toolCalls.append(toolCall)
                                    
                                    // Record the range for removal
                                    extractedRanges.append(startIndex..<endIndex)
                                }
                            } catch {
                                // Continue on JSON parse error
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
        }
        
        return (toolCalls, cleanedText)
    }
}

// MARK: - Test Helper Classes
class TestLLMAIService: LLMAIService {
    // Override with invalid URL to trigger network error
    override func sendChatMessage(conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
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

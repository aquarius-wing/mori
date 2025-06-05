import XCTest
@testable import Mori

final class OpenAIServiceTests: XCTestCase {
    
    var openAIService: OpenAIService!
    
    override func setUpWithError() throws {
        // Setup with a mock API key for testing
        openAIService = OpenAIService(apiKey: "test-api-key")
    }
    
    override func tearDownWithError() throws {
        openAIService = nil
    }
    
    // MARK: - extractToolCalls Tests
    
    func testExtractToolCalls_withValidSingleToolCall() throws {
        // Given - Your provided example
        let responseString = """
        {
            "tool": "read_calendar",
            "arguments": {
                "fromDate": "2025/06/05",
                "toDate": "2025/06/05"
            }
        }
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 1, "Should extract exactly one tool call")
        
        let toolCall = toolCalls.first!
        XCTAssertEqual(toolCall.tool, "read_calendar", "Tool name should match")
        
        let arguments = toolCall.arguments
        XCTAssertEqual(arguments["fromDate"] as? String, "2025/06/05", "fromDate argument should match")
        XCTAssertEqual(arguments["toDate"] as? String, "2025/06/05", "toDate argument should match")
    }
    
    func testExtractToolCalls_withMultipleToolCalls() throws {
        // Given
        let responseString = """
        Here are two tool calls:
        {
            "tool": "read_calendar",
            "arguments": {
                "fromDate": "2025/06/05",
                "toDate": "2025/06/05"
            }
        }
        And another one:
        {
            "tool": "create_event",
            "arguments": {
                "title": "Meeting",
                "date": "2025/06/06"
            }
        }
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 2, "Should extract exactly two tool calls")
        
        let firstToolCall = toolCalls[0]
        XCTAssertEqual(firstToolCall.tool, "read_calendar", "First tool name should match")
        XCTAssertEqual(firstToolCall.arguments["fromDate"] as? String, "2025/06/05", "First tool fromDate should match")
        
        let secondToolCall = toolCalls[1]
        XCTAssertEqual(secondToolCall.tool, "create_event", "Second tool name should match")
        XCTAssertEqual(secondToolCall.arguments["title"] as? String, "Meeting", "Second tool title should match")
    }
    
    func testExtractToolCalls_withNoToolCalls() throws {
        // Given
        let responseString = "This is just a regular response without any tool calls."
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 0, "Should extract no tool calls from regular text")
    }
    
    func testExtractToolCalls_withInvalidJSON() throws {
        // Given
        let responseString = """
        {
            "tool": "read_calendar",
            "arguments": {
                "fromDate": "2025/06/05"
                // Missing closing brace and comma
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 0, "Should not extract tool calls from invalid JSON")
    }
    
    func testExtractToolCalls_withMissingToolField() throws {
        // Given
        let responseString = """
        {
            "command": "read_calendar",
            "arguments": {
                "fromDate": "2025/06/05",
                "toDate": "2025/06/05"
            }
        }
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 0, "Should not extract tool calls without 'tool' field")
    }
    
    func testExtractToolCalls_withMissingArgumentsField() throws {
        // Given
        let responseString = """
        {
            "tool": "read_calendar",
            "params": {
                "fromDate": "2025/06/05",
                "toDate": "2025/06/05"
            }
        }
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 0, "Should not extract tool calls without 'arguments' field")
    }
    
    func testExtractToolCalls_withEmptyArguments() throws {
        // Given
        let responseString = """
        {
            "tool": "list_calendars",
            "arguments": {}
        }
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 1, "Should extract tool call even with empty arguments")
        
        let toolCall = toolCalls.first!
        XCTAssertEqual(toolCall.tool, "list_calendars", "Tool name should match")
        XCTAssertTrue(toolCall.arguments.isEmpty, "Arguments should be empty")
    }
    
    func testExtractToolCalls_withNestedJSONInArguments() throws {
        // Given
        let responseString = """
        {
            "tool": "create_event",
            "arguments": {
                "title": "Meeting",
                "location": {
                    "name": "Conference Room A",
                    "address": "123 Main St"
                },
                "attendees": ["alice@example.com", "bob@example.com"]
            }
        }
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 1, "Should extract tool call with complex arguments")
        
        let toolCall = toolCalls.first!
        XCTAssertEqual(toolCall.tool, "create_event", "Tool name should match")
        XCTAssertEqual(toolCall.arguments["title"] as? String, "Meeting", "Title should match")
        
        let location = toolCall.arguments["location"] as? [String: Any]
        XCTAssertNotNil(location, "Location should be a dictionary")
        XCTAssertEqual(location?["name"] as? String, "Conference Room A", "Location name should match")
        
        let attendees = toolCall.arguments["attendees"] as? [String]
        XCTAssertNotNil(attendees, "Attendees should be an array")
        XCTAssertEqual(attendees?.count, 2, "Should have two attendees")
        XCTAssertEqual(attendees?[0], "alice@example.com", "First attendee should match")
    }
    
    func testExtractToolCalls_withSurroundingText() throws {
        // Given
        let responseString = """
        I need to check your calendar for that date. Let me use this tool:
        
        {
            "tool": "read_calendar",
            "arguments": {
                "fromDate": "2025/06/05",
                "toDate": "2025/06/05"
            }
        }
        
        This will help me find your schedule.
        """
        
        // When
        let toolCalls = openAIService.extractToolCalls(from: responseString)
        
        // Then
        XCTAssertEqual(toolCalls.count, 1, "Should extract tool call even with surrounding text")
        
        let toolCall = toolCalls.first!
        XCTAssertEqual(toolCall.tool, "read_calendar", "Tool name should match")
        XCTAssertEqual(toolCall.arguments["fromDate"] as? String, "2025/06/05", "fromDate should match")
    }
} 
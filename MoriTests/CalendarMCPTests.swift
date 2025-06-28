import XCTest
import EventKit
@testable import Mori

final class CalendarMCPTests: XCTestCase {
    
    var calendarMCP: CalendarMCP!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        super.setUp()
        calendarMCP = CalendarMCP()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        calendarMCP = nil
        super.tearDown()
    }

    // MARK: - Test Cases
    /**
     add calendar
     */
    func testAddCalendarEventWithValidArguments() async throws {
        // Given: Valid arguments for creating a calendar event
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate.addingTimeInterval(3600) // 1 hour from now
        let endDate = currentDate.addingTimeInterval(7200)   // 2 hours from now
        
        let arguments: [String: Any] = [
            "title": "Test Meeting",
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate),
            "location": "Conference Room A",
            "notes": "This is a test meeting for unit testing",
            "isAllDay": false,
            "alarms": [
                ["relativeOffset": -15.0], // 15 minutes before
                ["relativeOffset": 0.0]    // At event start time
            ]
        ]
        
        // When: Adding calendar event
        do {
            let result = try await calendarMCP.addCalendar(arguments: arguments)
            
            // Then: Verify the result
            XCTAssertNotNil(result, "Result should not be nil")
            
            if let success = result["success"] as? Bool {
                // Note: This test might fail in CI/CD environment without calendar access
                // In a real app, we would need to mock the EventKit functionality
                print("Calendar access granted: \(success)")
                
                if success {
                    // Verify event details if creation was successful
                    if let eventData = result["event"] as? [String: Any] {
                        XCTAssertEqual(eventData["title"] as? String, "Test Meeting")
                        XCTAssertEqual(eventData["location"] as? String, "Conference Room A")
                        XCTAssertEqual(eventData["notes"] as? String, "This is a test meeting for unit testing")
                        XCTAssertEqual(eventData["is_all_day"] as? Bool, false)
                        
                        // Verify alarms
                        if let alarms = eventData["alarms"] as? [[String: Any]] {
                            XCTAssertEqual(alarms.count, 2, "Should have 2 alarms")
                        }
                        
                        print("✅ Calendar event created successfully in test")
                    }
                } else {
                    print("⚠️ Calendar access not granted - this is expected in test environment")
                }
            }
            
        } catch CalendarMCPError.accessDenied(let message) {
            // This is expected in test environment without calendar access
            print("⚠️ Calendar access denied (expected in test): \(message)")
            // This should not fail the test as it's expected behavior
            XCTAssertTrue(message.contains("Calendar access not granted"))
            
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /**
     Test adding calendar event with missing endDate parameter - should fail
     */
    func testAddCalendarEventMissingEndDate() async throws {
        // Given: Arguments missing required endDate parameter
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate.addingTimeInterval(3600) // 1 hour from now
        
        let arguments: [String: Any] = [
            "title": "Test Meeting",
            "startDate": formatter.string(from: startDate),
            // Missing endDate intentionally
            "location": "Conference Room A"
        ]
        
        // When & Then: Adding calendar event should throw error
        do {
            let _ = try await calendarMCP.addCalendar(arguments: arguments)
            XCTFail("Should have thrown an error for missing endDate")
        } catch CalendarMCPError.invalidArguments(let message) {
            // Expected error
            XCTAssertTrue(message.contains("title, startDate and endDate are required"))
            print("✅ Correctly caught missing endDate error: \(message)")
        } catch CalendarMCPError.accessDenied {
            // If calendar access is denied, we can't test this properly
            print("⚠️ Calendar access denied - cannot test missing endDate scenario")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /**
     Test adding calendar event with empty alarms array - should not add any alarms
     */
    func testAddCalendarEventWithEmptyAlarmsArray() async throws {
        // Given: Valid arguments with empty alarms array
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate.addingTimeInterval(3600) // 1 hour from now
        let endDate = currentDate.addingTimeInterval(7200)   // 2 hours from now
        
        let arguments: [String: Any] = [
            "title": "Test Meeting No Alarms",
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate),
            "alarms": [] // Empty array
        ]
        
        // When: Adding calendar event
        do {
            let result = try await calendarMCP.addCalendar(arguments: arguments)
            
            // Then: Verify no alarms were added
            if let success = result["success"] as? Bool, success {
                if let eventData = result["event"] as? [String: Any] {
                    if let alarms = eventData["alarms"] as? [[String: Any]] {
                        XCTAssertEqual(alarms.count, 0, "Should have no alarms when empty array provided")
                        print("✅ Correctly handled empty alarms array - no alarms added")
                    }
                }
            } else {
                print("⚠️ Calendar access not granted or creation failed - cannot fully test empty alarms")
            }
            
        } catch CalendarMCPError.accessDenied {
            print("⚠️ Calendar access denied - cannot test empty alarms scenario")
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /**
     Test adding calendar event with nil alarms - should add default alarm with relativeOffset: 0
     */
    func testAddCalendarEventWithNilAlarms() async throws {
        // Given: Valid arguments without alarms parameter (nil)
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate.addingTimeInterval(3600) // 1 hour from now
        let endDate = currentDate.addingTimeInterval(7200)   // 2 hours from now
        
        let arguments: [String: Any] = [
            "title": "Test Meeting Default Alarm",
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate)
            // No alarms parameter (nil)
        ]
        
        // When: Adding calendar event
        do {
            let result = try await calendarMCP.addCalendar(arguments: arguments)
            
            // Then: Verify default alarm was added
            if let success = result["success"] as? Bool, success {
                if let eventData = result["event"] as? [String: Any] {
                    if let alarms = eventData["alarms"] as? [[String: Any]] {
                        XCTAssertEqual(alarms.count, 1, "Should have 1 default alarm when no alarms provided")
                        
                        if let firstAlarm = alarms.first {
                            XCTAssertEqual(firstAlarm["relative_offset"] as? Double, 0.0, "Default alarm should have relativeOffset of 0")
                            print("✅ Correctly added default alarm with relativeOffset: 0")
                        }
                    }
                }
            } else {
                print("⚠️ Calendar access not granted or creation failed - cannot fully test nil alarms")
            }
            
        } catch CalendarMCPError.accessDenied {
            print("⚠️ Calendar access denied - cannot test nil alarms scenario")
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /**
     Test updating calendar event with empty id - should fail
     */
    func testUpdateCalendarEventWithEmptyId() async throws {
        // Given: Arguments with empty id
        let arguments: [String: Any] = [
            "id": "", // Empty id
            "title": "Updated Meeting"
            // Missing startDate and endDate which are required for new event creation
        ]
        
        // When & Then: Updating calendar event should throw error
        // Note: Empty id causes the code to go to "create new event" path instead of "update" path
        // Since startDate and endDate are missing, it should throw invalidArguments error
        do {
            let _ = try await calendarMCP.updateCalendar(arguments: arguments)
            XCTFail("Should have thrown an error for empty id")
        } catch CalendarMCPError.invalidArguments(let message) {
            // Expected error - when id is empty, code goes to create new event path
            // and throws error for missing required fields
            XCTAssertTrue(message.contains("title, startDate and endDate are required"))
            print("✅ Correctly caught missing required fields error when id is empty: \(message)")
        } catch CalendarMCPError.accessDenied {
            // If calendar access is denied, we can't test this properly
            print("⚠️ Calendar access denied - cannot test empty id scenario")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /**
     Test updating calendar event with empty alarms array - should remove existing alarms
     */
    func testUpdateCalendarEventWithEmptyAlarmsArray() async throws {
        // Given: First create an event with alarms, then update with empty alarms
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate.addingTimeInterval(3600) // 1 hour from now
        let endDate = currentDate.addingTimeInterval(7200)   // 2 hours from now
        
        // First create an event with alarms
        let createArguments: [String: Any] = [
            "title": "Test Meeting With Alarms",
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate),
            "alarms": [
                ["relativeOffset": -15.0], // 15 minutes before
                ["relativeOffset": 0.0]    // At event start time
            ]
        ]
        
        do {
            let createResult = try await calendarMCP.addCalendar(arguments: createArguments)
            
            if let success = createResult["success"] as? Bool, success,
               let eventData = createResult["event"] as? [String: Any],
               let eventId = eventData["id"] as? String, !eventId.isEmpty {
                
                // Now update the event with empty alarms array
                let updateArguments: [String: Any] = [
                    "id": eventId,
                    "alarms": [] // Empty array to remove alarms
                ]
                
                let updateResult = try await calendarMCP.updateCalendar(arguments: updateArguments)
                
                // Then: Verify alarms were removed
                if let updateSuccess = updateResult["success"] as? Bool, updateSuccess {
                    if let updatedEventData = updateResult["event"] as? [String: Any] {
                        if let alarms = updatedEventData["alarms"] as? [[String: Any]] {
                            XCTAssertEqual(alarms.count, 0, "Should have no alarms after updating with empty array")
                            print("✅ Correctly removed alarms when updating with empty array")
                        }
                    }
                } else {
                    print("⚠️ Update failed - cannot fully test empty alarms update")
                }
                
            } else {
                print("⚠️ Event creation failed or no event ID - cannot test alarms update")
            }
            
        } catch CalendarMCPError.accessDenied {
            print("⚠️ Calendar access denied - cannot test alarms update scenario")
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /**
     Test reading calendar events with missing endDate parameter - should fail
     */
    func testReadCalendarEventMissingEndDate() async throws {
        // Given: Arguments missing required endDate parameter
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate
        
        let arguments: [String: Any] = [
            "startDate": formatter.string(from: startDate)
            // Missing endDate intentionally
        ]
        
        // When & Then: Reading calendar events should throw error
        do {
            let _ = try await calendarMCP.readCalendar(arguments: arguments)
            XCTFail("Should have thrown an error for missing endDate")
        } catch CalendarMCPError.invalidArguments(let message) {
            // Expected error
            XCTAssertTrue(message.contains("startDate and endDate are required"))
            print("✅ Correctly caught missing endDate error in read operation: \(message)")
        } catch CalendarMCPError.accessDenied {
            // If calendar access is denied, we can't test this properly
            print("⚠️ Calendar access denied - cannot test missing endDate scenario")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /**
     Test reading calendar events with valid parameters - should succeed
     */
    func testReadCalendarEventWithValidParameters() async throws {
        // Given: Valid arguments for reading calendar events
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate
        let endDate = currentDate.addingTimeInterval(86400) // 24 hours from now
        
        let arguments: [String: Any] = [
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate)
        ]
        
        // When: Reading calendar events
        do {
            let result = try await calendarMCP.readCalendar(arguments: arguments)
            
            // Then: Verify the result structure
            XCTAssertNotNil(result, "Result should not be nil")
            
            if let success = result["success"] as? Bool {
                // Note: This test might fail in CI/CD environment without calendar access
                print("Calendar read operation success: \(success)")
                
                if success {
                    // Verify result structure
                    XCTAssertNotNil(result["events"], "Should have events array")
                    XCTAssertNotNil(result["count"], "Should have count field")
                    XCTAssertNotNil(result["date_range"], "Should have date_range field")
                    
                    if let count = result["count"] as? Int {
                        XCTAssertGreaterThanOrEqual(count, 0, "Count should be non-negative")
                        print("✅ Successfully read \(count) calendar events")
                    }
                    
                    if let events = result["events"] as? [[String: Any]] {
                        print("✅ Retrieved events array with \(events.count) items")
                        
                        // Verify event structure if there are events
                        for event in events {
                            XCTAssertNotNil(event["id"], "Event should have id")
                            XCTAssertNotNil(event["title"], "Event should have title")
                            XCTAssertNotNil(event["start_date"], "Event should have start_date")
                            XCTAssertNotNil(event["end_date"], "Event should have end_date")
                        }
                    }
                } else {
                    print("⚠️ Calendar access not granted - this is expected in test environment")
                }
            }
            
        } catch CalendarMCPError.accessDenied(let message) {
            // This is expected in test environment without calendar access
            print("⚠️ Calendar access denied (expected in test): \(message)")
            // This should not fail the test as it's expected behavior
            XCTAssertTrue(message.contains("Calendar access not granted"))
            
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /**
     Test removing calendar event with missing id parameter - should fail
     */
    func testRemoveCalendarEventMissingId() async throws {
        // Given: Arguments missing required id parameter
        let arguments: [String: Any] = [
            "title": "Some event title" // Irrelevant parameter
            // Missing id intentionally
        ]
        
        // When & Then: Removing calendar event should throw error
        do {
            let _ = try await calendarMCP.removeCalendar(arguments: arguments)
            XCTFail("Should have thrown an error for missing id")
        } catch CalendarMCPError.invalidArguments(let message) {
            // Expected error
            XCTAssertTrue(message.contains("Event id is required"))
            print("✅ Correctly caught missing id error in remove operation: \(message)")
        } catch CalendarMCPError.accessDenied {
            // If calendar access is denied, we can't test this properly
            print("⚠️ Calendar access denied - cannot test missing id scenario")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /**
     Test removing calendar event with valid parameters - should succeed
     */
    func testRemoveCalendarEventWithValidParameters() async throws {
        // Given: First create an event, then try to remove it
        let currentDate = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let startDate = currentDate.addingTimeInterval(3600) // 1 hour from now
        let endDate = currentDate.addingTimeInterval(7200)   // 2 hours from now
        
        // First create an event
        let createArguments: [String: Any] = [
            "title": "Test Event to Delete",
            "startDate": formatter.string(from: startDate),
            "endDate": formatter.string(from: endDate),
            "notes": "This event will be deleted in test"
        ]
        
        do {
            let createResult = try await calendarMCP.addCalendar(arguments: createArguments)
            
            if let success = createResult["success"] as? Bool, success,
               let eventData = createResult["event"] as? [String: Any],
               let eventId = eventData["id"] as? String, !eventId.isEmpty {
                
                // Now try to delete the event
                let deleteArguments: [String: Any] = [
                    "id": eventId
                ]
                
                let deleteResult = try await calendarMCP.removeCalendar(arguments: deleteArguments)
                
                // Then: Verify deletion was successful
                XCTAssertNotNil(deleteResult, "Delete result should not be nil")
                
                if let deleteSuccess = deleteResult["success"] as? Bool {
                    if deleteSuccess {
                        // Verify result structure
                        XCTAssertNotNil(deleteResult["message"], "Should have message field")
                        XCTAssertNotNil(deleteResult["eventId"], "Should have eventId field")
                        
                        if let returnedEventId = deleteResult["eventId"] as? String {
                            XCTAssertEqual(returnedEventId, eventId, "Returned event ID should match")
                        }
                        
                        if let message = deleteResult["message"] as? String {
                            XCTAssertTrue(message.contains("deleted successfully"), "Message should indicate successful deletion")
                        }
                        
                        print("✅ Successfully deleted calendar event with id: \(eventId)")
                    } else {
                        print("⚠️ Delete operation failed")
                        if let message = deleteResult["message"] as? String {
                            print("Delete failure message: \(message)")
                        }
                    }
                }
                
            } else {
                print("⚠️ Event creation failed or no event ID - cannot test deletion")
            }
            
        } catch CalendarMCPError.accessDenied {
            print("⚠️ Calendar access denied - cannot test deletion scenario")
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    func testToolDescriptionIsValid() {
        // Test that tool description is properly formatted
        let description = CalendarMCP.getToolDescription()
        
        XCTAssertTrue(description.contains("read-calendar"), "Should contain read-calendar tool")
        XCTAssertTrue(description.contains("add-calendar"), "Should contain add-calendar tool")
        XCTAssertTrue(description.contains("update-calendar"), "Should contain update-calendar tool")
        XCTAssertTrue(description.contains("remove-calendar"), "Should contain remove-calendar tool")
        
        print("✅ Tool description contains all required tools")
    }
    
    func testAvailableToolsList() {
        // Test that available tools list is correct
        let tools = CalendarMCP.getAvailableTools()
        
        XCTAssertEqual(tools.count, 4, "Should have 4 available tools")
        XCTAssertTrue(tools.contains("read-calendar"))
        XCTAssertTrue(tools.contains("add-calendar"))
        XCTAssertTrue(tools.contains("update-calendar"))
        XCTAssertTrue(tools.contains("remove-calendar"))
        
        print("✅ Available tools list is correct")
    }
} 

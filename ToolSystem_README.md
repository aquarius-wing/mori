# Mori - Tool System Integration Guide

## Overview

Successfully integrated tool calling system for the Mori application, supporting AI interaction with iOS Calendar.

## New Components

### 1. CalendarMCP.swift
- **Functionality**: Handles calendar-related operations
- **Permissions**: Automatically requests iOS calendar access permissions
- **Main Methods**:
  - `readCalendar(arguments:)`: Reads calendar events within specified date range
  - `requestCalendarAccess()`: Requests calendar access permissions

### 2. Enhanced OpenAIService.swift
- **Added**: Tool calling system
- **Template Design**: `generateSystemMessage()` dynamically generates system prompts
- **Main Features**:
  - `sendChatMessageWithTools()`: Chat method with tool calling support
  - `extractToolCalls()`: Extracts tool calls from AI responses
  - `executeTool()`: Executes specific tool operations
  - `generateSystemMessage()`: Dynamically gets tool descriptions and generates system messages

## Workflow

1. **User sends message** → AI analyzes if tools are needed
2. **AI response contains tool calls** → System automatically parses JSON-formatted tool requests
3. **Execute tools** → Calls corresponding CalendarMCP methods
4. **Tool results** → Added to conversation history as system messages
5. **AI generates final response** → Provides natural language reply based on tool results

## Tool Call Format

AI needs to request tools in the following JSON format:

```json
{
    "tool": "read-calendar",
    "arguments": {
        "fromDate": "2024/01/01",
        "toDate": "2024/01/07"
    }
}
```

## Supported Tools

### read-calendar
- **Description**: Read calendar events
- **Parameters**:
  - `fromDate`: Start date (YYYY/MM/DD format)
  - `toDate`: End date (YYYY/MM/DD format)
- **Returns**: Event list including title, time, location, etc.

## User Permissions

Added calendar permission request in Info.plist:
```xml
<key>NSCalendarsUsageDescription</key>
<string>This app needs calendar access to help you manage your schedule and answer questions about your events.</string>
```

## Example Conversation

**User**: "What do I have scheduled today?"

**AI**: Detects need for calendar information, automatically calls tool →

```json
{
    "tool": "read-calendar", 
    "arguments": {
        "fromDate": "2024/01/15",
        "toDate": "2024/01/15"
    }
}
```

**System**: Executes tool, returns today's events →

**AI**: "According to your calendar, you have the following appointments today:
- 10:00 AM Team meeting
- 2:00 PM Client presentation
- 7:00 PM Dinner appointment"

## Technical Features

- **Streaming Response**: Supports real-time AI reply display
- **Error Handling**: Comprehensive error handling and logging
- **Loop Protection**: Maximum 3 tool execution cycles to prevent infinite calls
- **Permission Management**: Automatic iOS permission request handling

## Template Design Advantages

- **Dynamic Tool Discovery**: System messages automatically include all available tools
- **Maintainability**: Tool descriptions and implementations in the same component
- **Consistency**: Unified tool description format
- **Extensibility**: New tools only need to implement `getToolDescription()` method

## Extensibility

System design supports easy addition of new tools:
1. Add tool methods in `CalendarMCP` or new MCP components
2. Add tool branches in `OpenAIService.executeTool()`
3. Tool descriptions automatically added to system messages via `getToolDescription()`

## Debug Features

- Detailed console log output
- Complete records of tool calls and responses
- Network request debug information 
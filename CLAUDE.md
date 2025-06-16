# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mori is a privacy-first AI Agent iOS app with voice chat capabilities that integrates with calendar management through MCP (Model Context Protocol) tools. The app supports multiple LLM providers (OpenAI and OpenRouter) and features voice recording, transcription, and calendar operations.

## Architecture

### Core Components

- **App Router**: `ContentView.swift` contains `AppRouter` class that manages navigation between onboarding and chat views based on API key setup status
- **Multi-Provider LLM Service**: `LLMAIService.swift` supports both OpenAI and OpenRouter with configurable endpoints and models
- **Calendar MCP Integration**: `CalendarMCP.swift` provides calendar read/write operations using EventKit
- **Voice Recording**: `AudioRecorder.swift` handles voice input and transcription
- **Chat Interface**: `ChatView.swift` with workflow step visualization and streaming responses

### Key Design Patterns

- Uses `@AppStorage` for persistent settings (API keys, provider selection, onboarding state)
- Implements workflow steps with status tracking (scheduled, executing, result, error)
- Streaming LLM responses with tool calling support
- MCP tool integration with JSON-based tool calling

## Development Commands

### Building and Testing
```bash
# Build the project
xcodebuild -scheme Mori -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -scheme Mori -destination 'platform=iOS Simulator,name=iPhone 16' test

# Build for device (requires provisioning profile)
xcodebuild -scheme Mori -destination generic/platform=iOS build
```

### Code Style Guidelines
Follow SwiftUI best practices from `.cursor/rules/swiftui-swift-cursor-rules.mdc`:
- Use latest SwiftUI and Swift features
- Prioritize readability over performance
- Write fully functional code with no TODOs or placeholders
- Think step-by-step before implementing
- Leave no missing functionality

## Key Configuration

### LLM Provider Setup
- Default OpenAI model: `gpt-4o-2024-11-20`
- Default OpenRouter model: `deepseek/deepseek-chat-v3-0324`
- Provider configuration handled via `LLMProviderConfig` struct
- Backward compatibility maintained for existing initialization methods

### App Storage Keys
- `hasCompletedOnboarding`: Onboarding completion status
- `currentProvider`: Selected LLM provider (openai/openRouter)
- `openaiApiKey`, `openrouterApiKey`: Provider API keys
- Additional provider-specific settings for base URLs and models

### Calendar Integration
- Requires EventKit permissions
- Uses ISO8601 date formatting for tool interactions
- Supports reading, creating, updating, and deleting calendar events
- Tool responses formatted as structured JSON for LLM processing

## Testing

Tests use Swift Testing framework (not XCTest). Test files:
- `MoriTests.swift`: Basic test structure
- `LLMAIServiceTests.swift`: LLM service functionality tests

## Recent Changes

The project recently underwent a major refactoring from `OpenAIService` to `LLMAIService` to support multiple providers. See `REFACTORING_SUMMARY.md` for detailed change log. All references have been updated throughout the codebase.
import Foundation
import SwiftUI

// MARK: - Memory Response Types
struct MemoryUpdateResponse: Codable {
    let success: Bool
    let message: String
    let result: String
    let newMemory: String  // Add field to store the original new memory
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case result
        case newMemory
    }
}

// MARK: - Memory Settings Manager
class MemorySettings: ObservableObject {
    static let shared = MemorySettings()
    
    @Published var userMemory: String {
        didSet {
            UserDefaults.standard.set(userMemory, forKey: "userMemory")
        }
    }
    
    private init() {
        // Load existing memory, default to empty if none saved
        self.userMemory = UserDefaults.standard.string(forKey: "userMemory") ?? ""
    }
    
    func updateMemory(_ newMemory: String) {
        userMemory = newMemory
    }
    
    func clearMemory() {
        userMemory = ""
    }
}

class MemoryMCP: ObservableObject {
    
    init() {
        // No longer create LLMAIService here to avoid circular dependency
    }
    
    // MARK: - Tool Definition
    static func getToolDescription() -> String {
        return """
        Tool: update-memory
        Description: If user say something need to be remembered, this tool will be call.
        Arguments:
        - memory: String(required), a simple sentence, must be in user preferred language

        **Things need to be remembered:**

        1. User prefer something
           1. Example: I like running around dusk
        2. User define something
           1. Example: When I say mauri or something, it usually mean Mori.
        3. User information
           1. Example 1: My daughter name Lucy, study at Bay Area Technology School
           2. Example 2: I need pick up my daughter 4 pm at Bay Area Technology School
              1. Remember: You have one daughter.
              2. Remember: She's currently a student at Bay Area Technology School.
        4. User routine
        """
    }
    
    // MARK: - Available Tools List
    static func getAvailableTools() -> [String] {
        return ["update-memory"]
    }
    
    // MARK: - Tool Functions
    func updateMemory(arguments: [String: Any]) async throws -> [String: Any] {
        print("🧠 Updating memory with arguments: \(arguments)")
        
        // Parse arguments
        guard let newMemory = arguments["memory"] as? String,
              !newMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MemoryMCPError.invalidArguments("memory is required and cannot be empty")
        }
        
        // Get current memory
        let memorySettings = MemorySettings.shared
        let currentMemory = memorySettings.userMemory
        
        // Create a temporary LLMAIService instance for network requests
        let llmService = LLMAIService()
        
        // Use AI to merge memories
        let mergedMemory = try await mergeMemories(currentMemory: currentMemory, newMemory: newMemory, using: llmService)
        
        // Update memory storage
        memorySettings.updateMemory(mergedMemory)
        
        let response = MemoryUpdateResponse(
            success: true,
            message: "Memory updated successfully",
            result: mergedMemory,
            newMemory: newMemory
        )
        
        // Convert to dictionary for return
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        return json as? [String: Any] ?? [:]
    }
    
    private func mergeMemories(currentMemory: String, newMemory: String, using llmService: LLMAIService) async throws -> String {
        // Create a simple system message for memory merging
        let systemPrompt = """
        You are a memory manager responsible for recording user habits, information, and preferences. Your goal is to merge new memories into existing memories.
        
        Current recorded content:
        \(currentMemory.isEmpty ? "(No records)" : currentMemory)
        ---
        
        New content to be updated:
        \(newMemory)
        ---
        
        Please process according to the following steps:
        Step 1: Understand what types of information exist in the original memory
        Step 2: Compare which parts of the new memory are related to the old memory
        Step 3: If completely different, directly add to the memory
        Step 4: If only partially different, perform local updates with additional explanations
        
        Please return the final merged result in the form of a multi-level markdown unordered list, ensuring completeness and organization of information.
        The resultmust be in user preferred language
        ```json
        {
          "result": "- User dietary preferences\n  - User likes spicy food but cannot tolerate very spicy levels, such as fire noodles"
        }
        ```
        """
        
        // Prepare request body for LLM API
        let requestBody: [String: Any] = [
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful assistant that merges user memories."
                ],
                [
                    "role": "user",
                    "content": systemPrompt
                ]
            ],
            "model": "deepseek-chat",
            "stream": true,
            "temperature": 0
        ]
        
        // Use LLMAIService to send the request
        var fullResponse = ""
        for try await chunk in llmService.sendChatMessage(requestBodyJSON: requestBody) {
            fullResponse += chunk
        }
        
        // Extract JSON result from the response
        return try extractJsonResult(from: fullResponse)
    }
    
    private func extractJsonResult(from response: String) throws -> String {
        print("🔍 Extracting JSON result from response: \(response.prefix(100))...")
        
        // Look for JSON code blocks (```json...```)
        let codeBlockPattern = "```json\\s*([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(location: 0, length: response.utf16.count)
            let matches = regex.matches(in: response, options: [], range: nsRange)
            
            for match in matches {
                if match.numberOfRanges >= 2 {
                    let jsonRange = match.range(at: 1)
                    
                    if let jsonSwiftRange = Range(jsonRange, in: response) {
                        let jsonString = String(response[jsonSwiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        print("🔍 Found JSON code block: \(jsonString.prefix(100))...")
                        
                        // Try to parse the JSON
                        if let jsonData = jsonString.data(using: .utf8) {
                            do {
                                let data = try JSONSerialization.jsonObject(with: jsonData)
                                
                                if let objectData = data as? [String: Any],
                                   let result = objectData["result"] as? String {
                                    print("✅ Successfully extracted memory result")
                                    return result
                                }
                            } catch {
                                print("⚠️ Failed to parse JSON from code block: \(error)")
                            }
                        }
                    }
                }
            }
        }
        
        // If no JSON found, return the full response as fallback
        print("⚠️ No JSON result found, using full response as fallback")
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Memory Update Result View
    static func createUpdateResultView(
        step: WorkflowStep
    ) -> some View {
        Group {
            if let resultValue = step.details["result"],
               let jsonData = resultValue.data(using: .utf8),
               let updateResponse = try? JSONDecoder().decode(
                   MemoryUpdateResponse.self,
                   from: jsonData
               )
            {
                if updateResponse.success {
                    // Success case: simple message showing what was remembered
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I've remembered: \(updateResponse.newMemory)")
                                .font(.body)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green.opacity(0.2))
                    )
                    .padding(.horizontal, 20)
                } else {
                    // Error case: keep detailed error info
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Memory update failed")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text(updateResponse.message)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.red.opacity(0.2))
                    )
                    .padding(.horizontal, 20)
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Helper Functions
    private static func openMemorySettings() {
        // This will be implemented when we integrate with the navigation system
        // For now, we'll just log
        print("🧠 Opening memory settings...")
        
        // Post notification to navigate to memory settings
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenMemorySettings"),
            object: nil
        )
    }
}

// MARK: - Memory Error Types
enum MemoryMCPError: Error {
    case invalidArguments(String)
    case serviceUnavailable(String)
    case processingFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .serviceUnavailable(let message):
            return "Service unavailable: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        }
    }
} 
import SwiftUI
import EventKit

enum OnboardingStep: Int, CaseIterable {
    case welcome = 1
    case textCompletion = 2
    case stt = 3
    case tts = 4
    case permission = 5
    case done = 6
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to Mori"
        case .textCompletion: return "Text Completion Provider"
        case .stt: return "Speech-to-Text Provider"
        case .tts: return "Text-to-Speech Provider"
        case .permission: return "Require Permission"
        case .done: return "🎉"
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("providerConfiguration") private var providerConfigData = Data()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("apiProviderChoice") private var apiProviderChoice: String = ""
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Text Completion Provider settings
    @State private var textProviderType: ProviderType = .openRouter
    @State private var textApiKey = ""
    @State private var textBaseUrl = ""
    @State private var textModel = ""
    @State private var showTextAdvanced = false
    
    // STT Provider settings
    @State private var sttProviderType: ProviderType = .openai
    @State private var sttApiKey = ""
    @State private var sttBaseUrl = ""
    @State private var sttModel = ""
    @State private var showSTTAdvanced = false
    
    // TTS Provider settings
    @State private var ttsProviderType: ProviderType = .openai
    @State private var ttsApiKey = ""
    @State private var ttsBaseUrl = ""
    @State private var ttsModel = ""
    @State private var ttsVoice = ""
    @State private var showTTSAdvanced = false
    
    // Calendar permission
    @State private var calendarPermissionGranted = false
    private let eventStore = EKEventStore()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header (only show on first step)
                if currentStep == .welcome {
                    welcomeHeader
                } else {
                    // Progress bar (only show for non-welcome steps)
                    progressBar
                }
                
                // Main content
                ScrollView {
                    stepContent
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Navigation buttons
                navigationButtons
                    .padding(.horizontal)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            .onAppear {
                loadExistingConfiguration()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .welcome {
                        Button(action: goBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(currentStep.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var welcomeHeader: some View {
        VStack(spacing: 10) {
            Image("AppIcon-Display")
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(16)
            
            Text("Mori")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Privacy-first AI Assistant")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            let totalSteps = getTotalStepsForCurrentPath()
            let currentStepNumber = getCurrentStepNumberForPath()
            
            ProgressView(value: Double(currentStepNumber), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 8)
            
            Text("Step \(currentStepNumber) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func getTotalStepsForCurrentPath() -> Int {
        if apiProviderChoice == "official" {
            return 2 // welcome → done
        } else {
            return 6 // welcome → textCompletion → stt → tts → permission → done
        }
    }
    
    private func getCurrentStepNumberForPath() -> Int {
        if apiProviderChoice == "official" {
            switch currentStep {
            case .welcome: return 1
            case .done: return 2
            default: return 1
            }
        } else {
            return currentStep.rawValue
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeContent
        case .textCompletion:
            textCompletionContent
        case .stt:
            sttContent
        case .tts:
            ttsContent
        case .permission:
            permissionContent
        case .done:
            doneContent
        }
    }
    
    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to Mori! Let's set up your AI providers.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text("Choose your setup preference:")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
            
            VStack(spacing: 16) {
                Button("Choose Official API Provider") {
                    apiProviderChoice = "official"
                    withAnimation {
                        currentStep = .permission
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                
                Button("Choose Custom API Provider") {
                    apiProviderChoice = "custom"
                    withAnimation {
                        currentStep = .textCompletion
                    }
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            
            if apiProviderChoice == "custom" {
                Text("We'll configure three types of providers:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Text Completion: For chat responses")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "mic")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text("Speech-to-Text: For voice transcription")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        Text("Text-to-Speech: For voice responses")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var textCompletionContent: some View {
        ProviderConfigView(
            title: "Text Completion Provider",
            description: "Choose your provider for AI chat responses",
            providerType: $textProviderType,
            apiKey: $textApiKey,
            baseUrl: $textBaseUrl,
            model: $textModel,
            showAdvanced: $showTextAdvanced,
            extraField: .constant(""),
            extraFieldTitle: ""
        )
    }
    
    private var sttContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            STTProviderConfigView(
                title: "Speech-to-Text Provider",
                description: "Configure voice transcription settings (OpenAI only)",
                apiKey: $sttApiKey,
                baseUrl: $sttBaseUrl,
                model: $sttModel,
                showAdvanced: $showSTTAdvanced
            )
            
            if textProviderType == .openai && !textApiKey.isEmpty {
                Button("Auto-fill from Text Completion Provider") {
                    sttProviderType = .openai
                    sttApiKey = textApiKey
                    sttBaseUrl = textBaseUrl
                    sttModel = textModel.isEmpty ? "whisper-1" : textModel
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
    }
    
    private var ttsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            TTSProviderConfigView(
                title: "Text-to-Speech Provider",
                description: "Configure voice generation settings (OpenAI only)",
                apiKey: $ttsApiKey,
                baseUrl: $ttsBaseUrl,
                model: $ttsModel,
                voice: $ttsVoice,
                showAdvanced: $showTTSAdvanced
            )
            
            VStack(spacing: 12) {
                if textProviderType == .openai && !textApiKey.isEmpty {
                    Button("Auto-fill from Text Completion Provider") {
                        ttsProviderType = .openai
                        ttsApiKey = textApiKey
                        ttsBaseUrl = textBaseUrl
                        ttsModel = textModel.isEmpty ? "tts-1" : textModel
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                if sttProviderType == .openai && !sttApiKey.isEmpty {
                    Button("Auto-fill from STT Provider") {
                        ttsProviderType = .openai
                        ttsApiKey = sttApiKey
                        ttsBaseUrl = sttBaseUrl
                        ttsModel = sttModel.isEmpty ? "tts-1" : sttModel
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var permissionContent: some View {
        VStack(spacing: 24) {
            Text("Calendar Permission")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Mori needs access to your calendar to provide better scheduling assistance.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Request Calendar Permission") {
                requestCalendarPermission()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(calendarPermissionGranted ? Color.green : Color.blue)
            .cornerRadius(10)
            .disabled(calendarPermissionGranted)
            
            if calendarPermissionGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Calendar permission granted")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private var doneContent: some View {
        VStack(alignment: .center, spacing: 24) {
            Text("🎉")
                .font(.system(size: 80))
            
            Text("Setup Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if apiProviderChoice == "official" {
                Text("You've chosen to use official API providers. Default configurations have been applied.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Your custom API providers have been configured successfully.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text("All API keys are stored securely on your device and never sent to third parties.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            // Only show button for non-welcome steps
            if currentStep != .welcome {
                Button(getButtonTitle()) {
                    if currentStep == .done {
                        saveAndComplete()
                    } else {
                        nextStep()
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed() ? Color.blue : Color.gray)
                .cornerRadius(10)
                .disabled(!canProceed())
            }
        }
    }
    
    private func getButtonTitle() -> String {
        switch currentStep {
        case .welcome:
            return ""
        case .done:
            return "Get Started"
        default:
            return "Next"
        }
    }
    
    private func goBack() {
        withAnimation {
            switch currentStep {
            case .textCompletion:
                currentStep = .welcome
            case .stt:
                currentStep = .textCompletion
            case .tts:
                currentStep = .stt
            case .permission:
                currentStep = .tts
            case .done:
                if apiProviderChoice == "official" {
                    currentStep = .welcome
                } else {
                    currentStep = .permission
                }
            default:
                break
            }
        }
    }
    
    private func requestCalendarPermission() {
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                if granted {
                    calendarPermissionGranted = true
                } else {
                    alertMessage = "Calendar permission denied. You can enable it later in Settings."
                    showingAlert = true
                }
            }
        }
    }
    
    private func loadExistingConfiguration() {
        // Try to load existing configuration
        if !providerConfigData.isEmpty {
            do {
                let config = try JSONDecoder().decode(ProviderConfiguration.self, from: providerConfigData)
                textProviderType = config.textCompletionProvider.type
                textApiKey = config.textCompletionProvider.apiKey
                textBaseUrl = config.textCompletionProvider.baseURL
                textModel = config.textCompletionProvider.model
                
                sttProviderType = config.sttProvider.type
                sttApiKey = config.sttProvider.apiKey
                sttBaseUrl = config.sttProvider.baseURL
                sttModel = config.sttProvider.model
                
                ttsProviderType = config.ttsProvider.type
                ttsApiKey = config.ttsProvider.apiKey
                ttsBaseUrl = config.ttsProvider.baseURL
                ttsModel = config.ttsProvider.model
                ttsVoice = config.ttsProvider.voice
            } catch {
                print("Failed to load provider configuration: \(error)")
            }
        }
    }
    
    private func canProceed() -> Bool {
        switch currentStep {
        case .welcome:
            return false // Handled by buttons in welcome content
        case .textCompletion:
            return !textApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .stt:
            return !sttApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tts:
            return !ttsApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .permission:
            return true // Can proceed regardless of permission status
        case .done:
            return true
        }
    }
    
    private func nextStep() {
        guard canProceed() else {
            showValidationError()
            return
        }
        
        withAnimation {
            if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
        }
    }
    
    private func showValidationError() {
        switch currentStep {
        case .textCompletion:
            alertMessage = "Please enter a valid API key for text completion"
        case .stt:
            alertMessage = "Please enter a valid API key for speech-to-text"
        case .tts:
            alertMessage = "Please enter a valid API key for text-to-speech"
        case .permission:
            alertMessage = "Calendar permission is required"
        case .done:
            alertMessage = "Please complete all required fields"
        default:
            alertMessage = "Please complete all required fields"
        }
        showingAlert = true
    }
    
    private func saveAndComplete() {
        if apiProviderChoice == "official" {
            // Create default official provider configuration
            let textProvider = TextCompletionProvider(
                type: .openai,
                apiKey: "official",
                baseURL: nil,
                model: nil
            )
            
            let sttProvider = STTProvider(
                type: .openai,
                apiKey: "official",
                baseURL: nil,
                model: nil
            )
            
            let ttsProvider = TTSProvider(
                type: .openai,
                apiKey: "official",
                baseURL: nil,
                model: nil,
                voice: nil
            )
            
            let configuration = ProviderConfiguration(
                textCompletionProvider: textProvider,
                sttProvider: sttProvider,
                ttsProvider: ttsProvider
            )
            
            // Save configuration
            do {
                let data = try JSONEncoder().encode(configuration)
                providerConfigData = data
            } catch {
                alertMessage = "Failed to save configuration: \(error.localizedDescription)"
                showingAlert = true
                return
            }
        } else {
            // Validate custom configuration
            guard !textApiKey.isEmpty && !sttApiKey.isEmpty && !ttsApiKey.isEmpty else {
                alertMessage = "Please complete all API key configurations"
                showingAlert = true
                return
            }
            
            // Create custom provider configuration
            let textProvider = TextCompletionProvider(
                type: textProviderType,
                apiKey: textApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: textBaseUrl.isEmpty ? nil : textBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                model: textModel.isEmpty ? nil : textModel.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            let sttProvider = STTProvider(
                type: sttProviderType,
                apiKey: sttApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: sttBaseUrl.isEmpty ? nil : sttBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                model: sttModel.isEmpty ? nil : sttModel.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            let ttsProvider = TTSProvider(
                type: ttsProviderType,
                apiKey: ttsApiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: ttsBaseUrl.isEmpty ? nil : ttsBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                model: ttsModel.isEmpty ? nil : ttsModel.trimmingCharacters(in: .whitespacesAndNewlines),
                voice: ttsVoice.isEmpty ? nil : ttsVoice.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            let configuration = ProviderConfiguration(
                textCompletionProvider: textProvider,
                sttProvider: sttProvider,
                ttsProvider: ttsProvider
            )
            
            // Save configuration
            do {
                let data = try JSONEncoder().encode(configuration)
                providerConfigData = data
            } catch {
                alertMessage = "Failed to save configuration: \(error.localizedDescription)"
                showingAlert = true
                return
            }
        }
        
        // Complete onboarding
        router.completeOnboarding()
    }
}

struct ProviderConfigView: View {
    let title: String
    let description: String
    @Binding var providerType: ProviderType
    @Binding var apiKey: String
    @Binding var baseUrl: String
    @Binding var model: String
    @Binding var showAdvanced: Bool
    @Binding var extraField: String
    let extraFieldTitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Provider selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Provider")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Provider", selection: $providerType) {
                    ForEach(ProviderType.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(getProviderDescription())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("Enter your \(providerType.displayName) API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Advanced settings
            Button(action: {
                showAdvanced.toggle()
            }) {
                HStack {
                    Text("Advanced Settings")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 15) {
                    // Base URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom API Base URL (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(getBaseUrlDescription())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField(getDefaultBaseUrl(), text: $baseUrl)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Model
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(getModelDescription())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField(getDefaultModel(), text: $model)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Extra field (for TTS voice)
                    if !extraFieldTitle.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(extraFieldTitle) (Optional)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Leave empty to use default voice 'alloy'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("alloy", text: $extraField)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showAdvanced)
    }
    
    private func getProviderDescription() -> String {
        switch providerType {
        case .openai:
            return "Your OpenAI API key will only be stored on this device."
        case .openRouter:
            return "Your OpenRouter API key will only be stored on this device."
        }
    }
    
    private func getBaseUrlDescription() -> String {
        switch providerType {
        case .openai:
            return "Leave empty to use official OpenAI API. Enter custom URL for compatible services."
        case .openRouter:
            return "Leave empty to use official OpenRouter API. Enter custom URL for compatible services."
        }
    }
    
    private func getDefaultBaseUrl() -> String {
        switch providerType {
        case .openai:
            return "https://api.openai.com"
        case .openRouter:
            return "https://openrouter.ai/api"
        }
    }
    
    private func getModelDescription() -> String {
        switch providerType {
        case .openai:
            return "Leave empty to use default. e.g., gpt-4o-2024-11-20"
        case .openRouter:
            return "Leave empty to use default. e.g., deepseek/deepseek-chat-v3-0324"
        }
    }
    
    private func getDefaultModel() -> String {
        switch providerType {
        case .openai:
            return "gpt-4o-2024-11-20"
        case .openRouter:
            return "deepseek/deepseek-chat-v3-0324"
        }
    }
}

struct STTProviderConfigView: View {
    let title: String
    let description: String
    @Binding var apiKey: String
    @Binding var baseUrl: String
    @Binding var model: String
    @Binding var showAdvanced: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Provider info (read-only)
            VStack(alignment: .leading, spacing: 10) {
                Text("Provider")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("OpenAI")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Only OpenAI supports STT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Your OpenAI API key will only be stored on this device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("Enter your OpenAI API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Advanced settings
            Button(action: {
                showAdvanced.toggle()
            }) {
                HStack {
                    Text("Advanced Settings")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 15) {
                    // Base URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom API Base URL (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Leave empty to use official OpenAI API.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("https://api.openai.com", text: $baseUrl)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Model
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Leave empty to use default whisper-1 model.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("whisper-1", text: $model)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showAdvanced)
    }
}

struct TTSProviderConfigView: View {
    let title: String
    let description: String
    @Binding var apiKey: String
    @Binding var baseUrl: String
    @Binding var model: String
    @Binding var voice: String
    @Binding var showAdvanced: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Provider info (read-only)
            VStack(alignment: .leading, spacing: 10) {
                Text("Provider")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("OpenAI")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Only OpenAI supports TTS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Your OpenAI API key will only be stored on this device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("Enter your OpenAI API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Advanced settings
            Button(action: {
                showAdvanced.toggle()
            }) {
                HStack {
                    Text("Advanced Settings")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 15) {
                    // Base URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom API Base URL (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Leave empty to use official OpenAI API.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("https://api.openai.com", text: $baseUrl)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Model
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Leave empty to use default tts-1 model.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("tts-1", text: $model)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Voice
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Leave empty to use default 'alloy' voice.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("alloy", text: $voice)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showAdvanced)
    }
}

#Preview {
    OnboardingView()
} 

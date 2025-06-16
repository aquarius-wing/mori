import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 1
    case textCompletion = 2
    case stt = 3
    case tts = 4
    case save = 5
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to Mori"
        case .textCompletion: return "Text Completion Provider"
        case .stt: return "Speech-to-Text Provider"
        case .tts: return "Text-to-Speech Provider"
        case .save: return "Complete Setup"
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("providerConfiguration") private var providerConfigData = Data()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Legacy support
    @AppStorage("currentProvider") private var currentProvider = LLMProviderType.openRouter.rawValue
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openaiBaseUrl") private var openaiBaseUrl = ""
    @AppStorage("openaiModel") private var openaiModel = ""
    @AppStorage("openrouterApiKey") private var openrouterApiKey = ""
    @AppStorage("openrouterBaseUrl") private var openrouterBaseUrl = ""
    @AppStorage("openrouterModel") private var openrouterModel = ""
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header (only show on first step)
                if currentStep == .welcome {
                    welcomeHeader
                }
                
                // Progress bar
                progressBar
                
                // Main content
                ScrollView {
                    VStack(spacing: 30) {
                        stepContent
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Navigation buttons
                navigationButtons
                    .padding(.horizontal)
            }
            .padding()
            .onAppear {
                loadExistingConfiguration()
            }
        }
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
            Text(currentStep.title)
                .font(.headline)
                .fontWeight(.semibold)
            
            ProgressView(value: Double(currentStep.rawValue), total: Double(OnboardingStep.allCases.count))
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 8)
            
            Text("Step \(currentStep.rawValue) of \(OnboardingStep.allCases.count)")
                .font(.caption)
                .foregroundColor(.secondary)
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
        case .save:
            saveContent
        }
    }
    
    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to Mori! Let's set up your AI providers.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text("We'll configure three types of providers:")
                .font(.subheadline)
                .fontWeight(.medium)
            
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
    
    private var saveContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Review Your Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                configSummaryRow(title: "Text Completion", provider: textProviderType.displayName, hasKey: !textApiKey.isEmpty)
                configSummaryRow(title: "Speech-to-Text", provider: sttProviderType.displayName, hasKey: !sttApiKey.isEmpty)
                configSummaryRow(title: "Text-to-Speech", provider: ttsProviderType.displayName, hasKey: !ttsApiKey.isEmpty)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            
            Text("All API keys are stored securely on your device and never sent to third parties.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
    
    private func configSummaryRow(title: String, provider: String, hasKey: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(provider)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Image(systemName: hasKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(hasKey ? .green : .red)
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("Previous") {
                    withAnimation {
                        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = previousStep
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            
            Button(currentStep == .save ? "Get Started" : "Next") {
                if currentStep == .save {
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
                loadLegacyConfiguration()
            }
        } else {
            loadLegacyConfiguration()
        }
    }
    
    private func loadLegacyConfiguration() {
        // Load from legacy AppStorage
        if let provider = LLMProviderType(rawValue: currentProvider) {
            textProviderType = provider == .openai ? .openai : .openRouter
            
            switch provider {
            case .openai:
                textApiKey = openaiApiKey
                textBaseUrl = openaiBaseUrl
                textModel = openaiModel
            case .openRouter:
                textApiKey = openrouterApiKey
                textBaseUrl = openrouterBaseUrl
                textModel = openrouterModel
            }
            
            // Set default STT and TTS to OpenAI if we have OpenAI text completion
            if provider == .openai {
                sttProviderType = .openai
                sttApiKey = textApiKey
                sttBaseUrl = textBaseUrl
                
                ttsProviderType = .openai
                ttsApiKey = textApiKey
                ttsBaseUrl = textBaseUrl
            }
        }
    }
    
    private func canProceed() -> Bool {
        switch currentStep {
        case .welcome:
            return true
        case .textCompletion:
            return !textApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .stt:
            return !sttApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tts:
            return !ttsApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .save:
            return !textApiKey.isEmpty && !sttApiKey.isEmpty && !ttsApiKey.isEmpty
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
        default:
            alertMessage = "Please complete all required fields"
        }
        showingAlert = true
    }
    
    private func saveAndComplete() {
        guard canProceed() else {
            showValidationError()
            return
        }
        
        // Create provider configuration
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
        
        // Save legacy configuration for backward compatibility
        currentProvider = textProviderType == .openai ? LLMProviderType.openai.rawValue : LLMProviderType.openRouter.rawValue
        
        switch textProviderType {
        case .openai:
            openaiApiKey = textProvider.apiKey
            openaiBaseUrl = textProvider.baseURL
            openaiModel = textProvider.model
        case .openRouter:
            openrouterApiKey = textProvider.apiKey
            openrouterBaseUrl = textProvider.baseURL
            openrouterModel = textProvider.model
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
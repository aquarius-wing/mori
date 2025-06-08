import SwiftUI

struct OnboardingView: View {
    @AppStorage("currentProvider") private var currentProvider = LLMProviderType.openRouter.rawValue
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openaiBaseUrl") private var openaiBaseUrl = ""
    @AppStorage("openaiModel") private var openaiModel = ""
    @AppStorage("openrouterApiKey") private var openrouterApiKey = ""
    @AppStorage("openrouterBaseUrl") private var openrouterBaseUrl = ""
    @AppStorage("openrouterModel") private var openrouterModel = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var selectedProvider: LLMProviderType = .openRouter
    @State private var tempApiKey = ""
    @State private var tempBaseUrl = ""
    @State private var tempModel = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showAdvancedSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 60) {
                // Welcome title
                VStack(spacing: 10) {
                    Image("AppIcon-Display")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(16)
                    
                    Text("Mori")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI Assistant")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // Provider selection and configuration
                VStack(alignment: .leading, spacing: 20) {
                    // Provider selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select AI Provider")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Picker("AI Provider", selection: $selectedProvider) {
                            ForEach(LLMProviderType.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedProvider) { oldValue, newValue in
                            updateFieldsForProvider(newValue)
                        }
                    }
                    
                    // API Key input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(getProviderDescription())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        SecureField("Enter your \(selectedProvider.displayName) API key", text: $tempApiKey)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                saveAndContinue()
                            }
                    }
                    
                    // Advanced settings
                    Button(action: {
                        showAdvancedSettings.toggle()
                    }) {
                        HStack {
                            Text("Advanced Settings")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if showAdvancedSettings {
                        VStack(alignment: .leading, spacing: 15) {
                            // Base URL configuration
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom API Base URL (Optional)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(getBaseUrlDescription())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                
                                TextField(getDefaultBaseUrl(), text: $tempBaseUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            // Model configuration
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Model (Optional)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(getModelDescription())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                
                                TextField(getDefaultModel(), text: $tempModel)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                        }
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .slide))
                    }
                }
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.2), value: showAdvancedSettings)
                
                // Help links
                VStack(spacing: 10) {
                    Text("How to get an API key?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Link("Visit \(selectedProvider.displayName) API page", destination: getProviderUrl())
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Continue button
                Button(action: saveAndContinue) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tempApiKey.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(tempApiKey.isEmpty)
                .padding(.horizontal)
            }
            .padding()
            .onAppear {
                // Initialize with current provider if returning
                if let provider = LLMProviderType(rawValue: currentProvider) {
                    selectedProvider = provider
                    updateFieldsForProvider(provider)
                }
            }
        }
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func updateFieldsForProvider(_ provider: LLMProviderType) {
        switch provider {
        case .openai:
            tempApiKey = openaiApiKey
            tempBaseUrl = openaiBaseUrl
            tempModel = openaiModel
        case .openRouter:
            tempApiKey = openrouterApiKey
            tempBaseUrl = openrouterBaseUrl
            tempModel = openrouterModel
        }
    }
    
    private func getProviderDescription() -> String {
        switch selectedProvider {
        case .openai:
            return "This app requires an OpenAI API key to access GPT models. Your key will only be stored on this device."
        case .openRouter:
            return "This app requires an OpenRouter API key to access various AI models. Your key will only be stored on this device."
        }
    }
    
    private func getBaseUrlDescription() -> String {
        switch selectedProvider {
        case .openai:
            return "Leave empty to use official OpenAI API. Enter custom URL for OpenAI-compatible services."
        case .openRouter:
            return "Leave empty to use official OpenRouter API. Enter custom URL for OpenRouter-compatible services."
        }
    }
    
    private func getDefaultBaseUrl() -> String {
        switch selectedProvider {
        case .openai:
            return "https://api.openai.com"
        case .openRouter:
            return "https://openrouter.ai/api"
        }
    }
    
    private func getModelDescription() -> String {
        switch selectedProvider {
        case .openai:
            return "Leave empty to use default model gpt-4o-2024-11-20. You can specify other OpenAI models."
        case .openRouter:
            return "Leave empty to use default model deepseek/deepseek-chat-v3-0324. You can specify other available models."
        }
    }
    
    private func getDefaultModel() -> String {
        switch selectedProvider {
        case .openai:
            return "gpt-4o-2024-11-20"
        case .openRouter:
            return "deepseek/deepseek-chat-v3-0324"
        }
    }
    
    private func getProviderUrl() -> URL {
        switch selectedProvider {
        case .openai:
            return URL(string: "https://platform.openai.com/api-keys")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")!
        }
    }
    
    private func saveAndContinue() {
        guard !tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter a valid API key"
            showingAlert = true
            return
        }
        
        // Validate custom Base URL format (if provided)
        let trimmedBaseUrl = tempBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBaseUrl.isEmpty {
            if !trimmedBaseUrl.hasPrefix("http://") && !trimmedBaseUrl.hasPrefix("https://") {
                alertMessage = "Custom API base URL must start with http:// or https://"
                showingAlert = true
                return
            }
            
            if URL(string: trimmedBaseUrl) == nil {
                alertMessage = "Please enter a valid URL format"
                showingAlert = true
                return
            }
        }
        
        let trimmedModel = tempModel.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save configuration based on selected provider
        currentProvider = selectedProvider.rawValue
        
        switch selectedProvider {
        case .openai:
            openaiApiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            openaiBaseUrl = trimmedBaseUrl
            openaiModel = trimmedModel
        case .openRouter:
            openrouterApiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            openrouterBaseUrl = trimmedBaseUrl
            openrouterModel = trimmedModel
        }
        
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
} 
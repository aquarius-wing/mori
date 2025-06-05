import SwiftUI

struct OnboardingView: View {
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("customApiBaseUrl") private var customApiBaseUrl = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var tempApiKey = ""
    @State private var tempBaseUrl = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showAdvancedSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 欢迎标题
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Mori")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI Assistant with Voice Chat")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // API配置输入
                VStack(alignment: .leading, spacing: 15) {
                    Text("Setup OpenAI API Key")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("This app requires an OpenAI API key to access GPT-4o and Whisper models. Your key will be securely stored on this device only.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    SecureField("Enter your OpenAI API key", text: $tempApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveAndContinue()
                        }
                    
                    // 高级设置
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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Custom API Base URL (Optional)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Leave empty to use OpenAI's official API. Enter a custom URL for OpenAI-compatible services.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            TextField("https://api.openai.com/v1", text: $tempBaseUrl)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .slide))
                    }
                }
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.2), value: showAdvancedSettings)
                
                // 帮助链接
                VStack(spacing: 10) {
                    Text("How to get an API key?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Link("Visit OpenAI API Page", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                // 继续按钮
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
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveAndContinue() {
        guard !tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter a valid API key"
            showingAlert = true
            return
        }
        
        // 验证自定义Base URL格式（如果提供了的话）
        let trimmedBaseUrl = tempBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBaseUrl.isEmpty {
            if !trimmedBaseUrl.hasPrefix("http://") && !trimmedBaseUrl.hasPrefix("https://") {
                alertMessage = "Custom API Base URL must start with http:// or https://"
                showingAlert = true
                return
            }
            
            if URL(string: trimmedBaseUrl) == nil {
                alertMessage = "Please enter a valid URL format"
                showingAlert = true
                return
            }
        }
        
        openaiApiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        customApiBaseUrl = trimmedBaseUrl
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
} 
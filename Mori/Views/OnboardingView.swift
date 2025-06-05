import SwiftUI

struct OnboardingView: View {
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var tempApiKey = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
                
                // API密钥输入
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
                }
                .padding(.horizontal)
                
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
        
        openaiApiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
} 
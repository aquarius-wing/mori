import EventKit
import SwiftUI

// Custom button style for dark background
struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome = 1
    case example = 2
    case permission = 3
    case done = 4

    var title: String {
        switch self {
        case .welcome: return "Welcome to Mori"
        case .example: return "Example"
        case .permission: return "Require Permission"
        case .done: return "🎉"
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("providerConfiguration") private var providerConfigData = Data()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding =
        false
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
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    currentStep == .welcome ? Rectangle()
                        .foregroundColor(.clear)
                        .frame(
                            width: (geometry.size.width
                                - geometry.safeAreaInsets.leading
                                    - geometry.safeAreaInsets.trailing) * 1,
                            height: (geometry.size.height
                                - geometry.safeAreaInsets.top
                                - geometry.safeAreaInsets.bottom) * 0.7
                        )
                        .background(
                            EllipticalGradient(
                                stops: [
                                    Gradient.Stop(
                                        color: Color(
                                            red: 0.24,
                                            green: 0.1,
                                            blue: 0.1
                                        ),
                                        location: 0.00
                                    ),
                                    Gradient.Stop(
                                        color: .black,
                                        location: 1.00
                                    ),
                                ],
                                center: UnitPoint(x: 0.5, y: 0.5)
                            )
                        )
                        .rotationEffect(Angle(degrees: -30.38))
                        .offset(
                            x: -geometry.size.width / 2 / 4,
                            y: -geometry.size.height / 2 / 5
                        )
                        .scaleEffect(5) : nil
                    
                    VStack(spacing: 0) {
                        // Progress bar (only show for non-welcome steps)
                        if currentStep != .welcome {
                            progressBar
                                .padding(.horizontal)
                                .padding(.top, 20)
                        }
                        
                        Spacer()
                        
                        // Step content
                        stepContent
                            .padding(.horizontal)
                            .padding(.top, 40)
                            .padding(.bottom, 40)
                        
                        Spacer()
                        
                        // Navigation button
                        navigationButton
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                            .cornerRadius(16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.black.ignoresSafeArea())
            }
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
                    if currentStep != .welcome {
                        Text(currentStep.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(
            currentStep == .welcome ? .large : .inline
        )
        .navigationBarHidden(currentStep == .welcome)
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }



    private var progressBar: some View {
        VStack(spacing: 8) {
            let totalSteps = getTotalStepsForCurrentPath()
            let currentStepNumber = getCurrentStepNumberForPath()

            ProgressView(
                value: Double(currentStepNumber),
                total: Double(totalSteps)
            )
            .progressViewStyle(LinearProgressViewStyle())
            .frame(height: 8)

            Text("Step \(currentStepNumber) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func getTotalStepsForCurrentPath() -> Int {
        if apiProviderChoice == "official" {
            return 3  // welcome → permission → done
        } else {
            return 4  // welcome → example → permission → done
        }
    }

    private func getCurrentStepNumberForPath() -> Int {
        return currentStep.rawValue
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeContent
        case .example:
            exampleContent
        case .permission:
            permissionContent
        case .done:
            doneContent
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 30) {
            Image("AppIcon-Display")
                .resizable()
                .frame(width: 120, height: 120)
                .cornerRadius(24)
            
            Spacer()

            VStack(spacing: 12) {
                Text("Hello, Here is Mori!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Let me help make your life better.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    private var exampleContent: some View {
        VStack(spacing: 24) {
            Text("Example")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("This is an example of how Mori can help you organize your tasks and schedule.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var permissionContent: some View {
        VStack(spacing: 24) {
            Text("Calendar Permission")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Mori needs access to your calendar to provide better scheduling assistance.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

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
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("You're all set up! Mori is ready to help you organize your life.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("All API keys are stored securely on your device and never sent to third parties.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var navigationButton: some View {
        Button(action: {
                if currentStep == .done {
                hasCompletedOnboarding = true
                router.completeOnboarding()
            } else {
                nextStep()
            }
            }) {
                Text(getButtonTitle())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(canProceed() ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canProceed() ? Color.white : Color.gray)
                    .cornerRadius(16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CustomButtonStyle())
            .disabled(!canProceed())
            .padding(.horizontal, 40)
    }

    private func getButtonTitle() -> String {
        switch currentStep {
        case .welcome:
            return "Get Started"
        case .example, .permission:
            return "Continue"
        case .done:
            return "Let's go"
        }
    }

    private func goBack() {
        withAnimation {
            switch currentStep {
            case .example:
                currentStep = .welcome
            case .permission:
                currentStep = .example
            case .done:
                currentStep = .permission
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
                    alertMessage =
                        "Calendar permission denied. You can enable it later in Settings."
                    showingAlert = true
                }
            }
        }
    }

    private func loadExistingConfiguration() {
        // Try to load existing configuration
        if !providerConfigData.isEmpty {
            do {
                let config = try JSONDecoder().decode(
                    ProviderConfiguration.self,
                    from: providerConfigData
                )
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
            return true  // Handled by buttons in welcome content
        case .example:
            return true  // Can always proceed from example
        case .permission:
            return true  // Can proceed regardless of permission status
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
            if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1)
            {
                currentStep = nextStep
            }
        }
    }

    private func showValidationError() {
        switch currentStep {
        case .example:
            alertMessage = "Please complete the example step"
        case .permission:
            alertMessage = "Calendar permission is required"
        case .done:
            alertMessage = "Please complete all required fields"
        default:
            alertMessage = "Please complete all required fields"
        }
        showingAlert = true
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}

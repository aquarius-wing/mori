import EventKit
import SwiftUI
import UserNotifications
import Intents

// Custom button style for dark background
struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                .easeInOut(duration: 0.1),
                value: configuration.isPressed
            )
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
        case .permission: return "Configure Permissions"
        case .done: return "🎉"
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding =
        false

    @State private var currentStep: OnboardingStep = .welcome

    // Initializer for setting initial step (useful for previews)
    init(initialStep: OnboardingStep = .welcome) {
        self._currentStep = State(initialValue: initialStep)
    }

    @State private var showingAlert = false
    @State private var alertMessage = ""

    

    // Permissions
    @State private var calendarPermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var siriPermissionGranted = false
    private let eventStore = EKEventStore()

    // Example card expansion state
    @State private var isExampleCardExpanded = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    currentStep == .welcome
                        ? Rectangle()
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

                        Spacer()

                        // Step content

                        stepContent
                            .padding(.horizontal)

                        Spacer()

                        if currentStep != .welcome {
                            HStack {
                                Spacer()
                                progressBar
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }

                        // Navigation button
                        navigationButton
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                            .cornerRadius(16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.black.ignoresSafeArea())
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .welcome {
                        Button(action: goBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(currentStep == .welcome)
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            let totalSteps = 3
            let currentStepNumber = getCurrentStepNumberForPath()

            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(
                        step == currentStepNumber
                            ? Color.white : Color.gray.opacity(0.4)
                    )
                    .frame(width: 8, height: 8)
                    .animation(
                        .easeInOut(duration: 0.3),
                        value: currentStepNumber
                    )
            }
        }
        .padding(.top, 8)
    }

    private func getCurrentStepNumberForPath() -> Int {
        // Subtract 1 to exclude welcome step from count
        return max(1, currentStep.rawValue - 1)
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
                .padding(.top, 24)

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
        .padding(.top, 40)
        .padding(.bottom, 40)
    }

    private var exampleContent: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        VStack(spacing: 0) {
                            Text("One word")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("to rule them all")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }

                        Text(
                            "All your personal calendar events and reminders will be managed by Mori"
                        )
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .padding(.top, 8)
                    }

                    VStack(spacing: 16) {
                        // Example card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))

                                Text("Save events to calendar")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Spacer()
                            }

                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                                    .padding(2)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(
                                        "Move all my events today to tomorrow"
                                    )
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .lineSpacing(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(
                                        horizontal: false,
                                        vertical: true
                                    )
                                }
                            }

                            // Expandable section
                            if isExampleCardExpanded {
                                VStack(spacing: 12) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 16))
                                            .padding(2)

                                        VStack(alignment: .leading, spacing: 0)
                                        {
                                            Text(
                                                "I'll help you move all your events today to tomorrow:"
                                            )
                                            .font(.body)
                                            .foregroundColor(.gray)
                                            .lineSpacing(2)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(
                                                horizontal: false,
                                                vertical: true
                                            )
                                        }

                                        Spacer()
                                    }

                                    // Event Card 1 - Before and After
                                    HStack(spacing: 8) {
                                        // Original Event Card 1
                                        HStack(spacing: 8) {
                                            Rectangle()
                                                .fill(Color.yellow)
                                                .frame(width: 3, height: 35)
                                                .cornerRadius(1.5)

                                            VStack(
                                                alignment: .leading,
                                                spacing: 2
                                            ) {
                                                Text("Kickoff Meeting")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.yellow)
                                                    .lineLimit(1)

                                                HStack(spacing: 4) {
                                                    Image(systemName: "clock")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 11))
                                                    Text("06/17")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .frame(maxWidth: .infinity)

                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))

                                        // Modified Event Card 1
                                        HStack(spacing: 8) {
                                            Rectangle()
                                                .fill(Color.green)
                                                .frame(width: 3, height: 35)
                                                .cornerRadius(1.5)

                                            VStack(
                                                alignment: .leading,
                                                spacing: 2
                                            ) {
                                                Text("Kickoff Meeting")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.green)
                                                    .lineLimit(1)

                                                HStack(spacing: 4) {
                                                    Image(systemName: "clock")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 11))
                                                    Text("06/18")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.top, 8)

                                    // Event Card 2 - Before and After
                                    HStack(spacing: 8) {
                                        // Original Event Card 2
                                        HStack(spacing: 8) {
                                            Rectangle()
                                                .fill(Color.yellow)
                                                .frame(width: 3, height: 35)
                                                .cornerRadius(1.5)

                                            VStack(
                                                alignment: .leading,
                                                spacing: 2
                                            ) {
                                                Text("Prototype Walkthrough")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.yellow)
                                                    .lineLimit(1)

                                                HStack(spacing: 4) {
                                                    Image(systemName: "clock")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 11))
                                                    Text("06/17")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .frame(maxWidth: .infinity)

                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))

                                        // Modified Event Card 2
                                        HStack(spacing: 8) {
                                            Rectangle()
                                                .fill(Color.green)
                                                .frame(width: 3, height: 35)
                                                .cornerRadius(1.5)

                                            VStack(
                                                alignment: .leading,
                                                spacing: 2
                                            ) {
                                                Text("Prototype Walkthrough")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.green)
                                                    .lineLimit(1)

                                                HStack(spacing: 4) {
                                                    Image(systemName: "clock")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 11))
                                                    Text("06/18")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .transition(
                                    .opacity.combined(with: .move(edge: .top))
                                )
                                .animation(
                                    .easeInOut(duration: 0.3),
                                    value: isExampleCardExpanded
                                )
                            }

                            // Expand/Collapse button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isExampleCardExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(
                                        systemName: "chevron.down"
                                    )
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                                    .rotationEffect(
                                        .degrees(
                                            isExampleCardExpanded ? 180 : 0
                                        )
                                    )
                                    .animation(
                                        .easeInOut(duration: 0.3),
                                        value: isExampleCardExpanded
                                    )
                                    Spacer()
                                }
                                .padding(.top, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(20)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(16)
                        .onTapGesture {
                            // Allow tapping anywhere on the card to expand/collapse
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExampleCardExpanded.toggle()
                            }
                        }
                    }

                    Spacer()

                    // Invisible anchor for scrolling to bottom
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.top, 40)
                .padding(.bottom, 40)
                .onChange(of: isExampleCardExpanded) { _, newValue in
                    if newValue {
                        // Scroll to bottom when expanded with a delay for smooth animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }

    private var permissionContent: some View {
        VStack(spacing: 32) {
            // Title
            Text("Configure Permissions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                // Calendar Permission Card
                PermissionCard(
                    icon: "calendar",
                    title: "Calendar",
                    description: "Mori needs to access your calendar data to manage events.",
                    isGranted: calendarPermissionGranted,
                    action: {
                        requestCalendarPermission()
                    }
                )
                
                // Notification Permission Card
                PermissionCard(
                    icon: "bell",
                    title: "Notifications",
                    description: "Mori needs to notification permissions in order to remind you about upcoming events.",
                    isGranted: notificationPermissionGranted,
                    action: {
                        requestNotificationPermission()
                    }
                )
            }
            Spacer()
        }
        .onAppear {
            checkPermissionStatus()
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
        case .example:
            return "Continue"
        case .permission:
            return "Continue"
        case .done:
            return "Let's go!"
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

    private func checkPermissionStatus() {
        #if DEBUG
        // In preview mode or debug, provide mock permission status
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Mock some permissions as granted for preview purposes
            calendarPermissionGranted = false
            notificationPermissionGranted = false
            siriPermissionGranted = false
            return
        }
        #endif
        
        // Check calendar permission
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        calendarPermissionGranted = (calendarStatus == .fullAccess)
        
        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionGranted = (settings.authorizationStatus == .authorized)
            }
        }
        
        // Check Siri permission
        let siriStatus = INPreferences.siriAuthorizationStatus()
        siriPermissionGranted = (siriStatus == .authorized)
    }
    
    private func requestCalendarPermission() {
        #if DEBUG
        // In preview mode, simulate permission grant
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            DispatchQueue.main.async {
                calendarPermissionGranted = true
            }
            return
        }
        #endif
        
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
    
    private func requestNotificationPermission() {
        #if DEBUG
        // In preview mode, simulate permission grant
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            DispatchQueue.main.async {
                notificationPermissionGranted = true
            }
            return
        }
        #endif
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationPermissionGranted = true
                } else {
                    alertMessage =
                        "Notification permission denied. You can enable it later in Settings."
                    showingAlert = true
                }
            }
        }
    }
    
    private func requestSiriPermission() {
        #if DEBUG
        // In preview mode, simulate permission grant
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            DispatchQueue.main.async {
                siriPermissionGranted = true
            }
            return
        }
        #endif
        
        INPreferences.requestSiriAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    siriPermissionGranted = true
                } else {
                    alertMessage =
                        "Siri permission denied. You can enable it later in Settings."
                    showingAlert = true
                }
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
            .environmentObject(AppRouter())
    }
}

#Preview("Example Step") {
    NavigationStack {
        OnboardingView(initialStep: .example)
            .environmentObject(AppRouter())
    }
}

#Preview("Permission Step") {
    NavigationStack {
        OnboardingView(initialStep: .permission)
            .environmentObject(AppRouter())
    }
}

#Preview("Done Step") {
    NavigationStack {
        OnboardingView(initialStep: .done)
            .environmentObject(AppRouter())
    }
}

// MARK: - Permission Card Component
struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First row: Icon and Choose button
            HStack {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                
                Spacer()
                
                // Choose/Done Button
                Button(action: action) {
                    Text(isGranted ? "Done" : "Choose")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isGranted ? Color.green : Color.blue)
                        )
                }
                .disabled(isGranted)
            }
            
            // Second row: Title
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            // Third row: Description
            Text(description)
                .font(.body)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

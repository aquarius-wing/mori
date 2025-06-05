<h1 align="center"> Mori </h1>

<h4 align="center">
    A privacy-first AI Agent app on iOS with voice chat capabilities.
</h4>

## 🤔 Why Mori?

1. **Voice-First AI Chat**: Talk to GPT-4o naturally using voice input with Whisper speech-to-text
2. **Privacy-First**: Your API keys and conversations stay on your device - no data collection
3. **Seamless Experience**: Stream responses in real-time with beautiful Markdown rendering
4. **Future-Ready**: Built for extensibility with planned Calendar and Reminders integration

## ✨ Core Features

### 🎙️ Voice Interaction
- **Voice Recording**: Hold to record, release to send
- **Speech-to-Text**: Powered by OpenAI Whisper for accurate transcription
- **Smart Chat**: Streaming conversations with GPT-4o
- **Rich Responses**: Clean text display for AI responses

### 🚀 User Experience
- **Onboarding Flow**: Guided setup for OpenAI API keys
- **Real-time Streaming**: See AI responses as they're generated
- **Chat History**: Persistent conversation memory
- **Permission Management**: Automatic microphone permission handling

## 🏗️ Technical Architecture

### 📱 Technologies
- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Professional audio recording
- **URLSession**: Efficient networking with streaming support

### 🗂️ Project Structure
```
Mori/
├── MoriApp.swift              # App entry point
├── ContentView.swift          # Main view controller
├── Views/
│   ├── OnboardingView.swift   # API key setup
│   └── ChatView.swift         # Chat interface
├── Services/
│   ├── AudioRecorder.swift    # Audio recording service
│   └── OpenAIService.swift    # OpenAI API service
├── Models/
│   └── ChatMessage.swift      # Message data model
└── Assets.xcassets/           # App resources
```

## 🚀 Quick Start

### 1. Requirements
- Xcode 15.0 or later
- iOS 17.0 or later
- Valid OpenAI API key

### 2. Get OpenAI API Key
1. Visit [OpenAI API Keys](https://platform.openai.com/api-keys)
2. Sign in or create an OpenAI account
3. Create a new API key
4. Copy and save the key (shown only once)

### 3. Installation & Setup
1. Clone the repository
2. Open `Mori.xcodeproj` in Xcode
3. Select your target device or simulator
4. Run with ⌘+R

### 4. First-time Setup
1. Enter your OpenAI API key in the onboarding screen
2. Tap "Get Started"
3. Allow microphone access when prompted

## 💬 How to Use

### Voice Chat
1. **Hold to Record**: Press and hold the microphone button
2. **Speak Naturally**: Ask your question or make a request
3. **Release to Send**: Let go to process your voice
4. **Watch the Magic**: See your speech converted to text and AI response streaming in

### Interface Features
- **Recording Status**: Button turns red and scales during recording
- **Permission Prompts**: Automatic microphone permission requests
- **Error Handling**: Friendly error messages for network/API issues
- **Clear Chat**: Reset conversation with the clear button

## ⚙️ API Configuration

### OpenAI Models Used
- **Speech-to-Text**: `whisper-1`
- **Chat Completion**: `gpt-4o`

### API Settings
- Audio Format: M4A (AAC encoding)
- Max Tokens: 2000
- Temperature: 0.7
- Streaming: Enabled

## 🔒 Privacy & Security

- ✅ API keys stored locally on device only
- ✅ Audio files deleted after processing
- ✅ No user data collection or tracking
- ✅ All communications use HTTPS encryption

## ❓ FAQ

### Q: Why does the app need microphone access?
A: Microphone access is required to record your voice for speech-to-text conversion and AI chat.

### Q: Is my API key secure?
A: Yes, your API key is stored only on your device and never uploaded to any servers.

### Q: What languages are supported?
A: Whisper supports many languages for speech recognition, but the AI primarily responds in English.

### Q: Why isn't the chat responding?
A: Check that:
- Your internet connection is stable
- Your API key is valid and has credit
- OpenAI services are operational

## 🛠️ Development

### Future Features
Planned enhancements include:
- Text input support
- Voice playback of AI responses
- Conversation export
- Custom AI personalities
- Calendar and Reminders integration
- Multi-language support
- Markdown rendering for rich text responses

### Dependencies
This project currently has no external dependencies and uses only Apple's built-in frameworks.

## 📄 License

This project is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for details.

## 🤝 Contributing

Issues and Pull Requests are welcome to improve this project!


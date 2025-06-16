## Models

TopLevelStructure:

- textCompletionProvider: 
  - currentProvider: string, default is openRouter
  - providers: TextCompletionProvider[]
- sttProvider: 
  - currentProvider: string, default is openai
  - providers: STTProvider[]
- ttsProvider: 
  - currentProvider: string, default is openai
  - providers: TTSProvider[]



### TextCompletionProvider

### currentProvider

Save the type of provider

#### OpenAI Providers

- type: openai
- apiKey: string
- baseURL: string, default is https://api.openai.com
- model: string, default is gpt-4o-2024-11-20

#### OpenRouter Providers

- type: openRouter
- apiKey: string
- model: string, default is deepseek/deepseek-chat-v3-0324

### STTProvider

we use OpenAI's whisper model to transcribe the audio to text.

when TextCompletionProvider type is openai, we will show a more button to auto input the settings as STTProvider.

- type: openai
- apiKey: string
- baseURL: string, default is https://api.openai.com
- model: string, default is whisper-1

### TTSProvider

we use OpenAI's gpt-4o-mini-tts model to generate the audio from text.

when TextCompletionProvider type is openai, we will show a more button to auto input the settings as STTProvider.

- type: openai
- apiKey: string
- baseURL: string, default is https://api.openai.com
- model: string, default is tts-1
- voice: string, default is allo
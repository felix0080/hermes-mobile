# Hermes Mobile — Project Architecture

> **Purpose**: This document is the single source of truth for the project.
> Any AI agent (Claude Code, Codex, Hermes) must read this before contributing.
> Update this spec when architecture decisions change.

## Overview

Hermes Mobile is a Flutter app that connects to [Hermes Agent](https://github.com/NousResearch/hermes-agent)'s built-in API Server. The API Server exposes OpenAI-compatible endpoints (`POST /v1/chat/completions`), so the app behaves like any OpenAI client — but connects to Hermes instead.

## Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| Framework | Flutter 3.29+ | Cross-platform iOS/Android, single codebase |
| Language | Dart 3.7+ | Type-safe, null-safe |
| HTTP | dio 5.x | Streaming SSE support, interceptors |
| State | provider 6.x | Simple, Flutter-recommended, no codegen |
| Voice STT | speech_to_text 7.x | On-device speech recognition (free) |
| Voice TTS | flutter_tts 4.x | On-device text-to-speech (free) |
| Markdown | flutter_markdown 0.7 | Render assistant responses with code blocks |
| Storage | sqflite + shared_preferences | Conversations + settings |
| IDs | uuid 4.x | Unique message/conversation IDs |

## Architecture

```
┌──────────────────────────────────────────────────┐
│                    Screens                        │
│  ChatScreen  ConversationsScreen  SettingsScreen  │
├──────────────────────────────────────────────────┤
│                   Providers                       │
│       ChatProvider        SettingsProvider        │
├──────────────────────────────────────────────────┤
│                   Services                        │
│    ApiService    SpeechService    StorageService  │
├──────────────────────────────────────────────────┤
│                    Models                         │
│         Message          Conversation             │
├──────────────────────────────────────────────────┤
│                    Config                         │
│               AppConfig (constants)               │
└──────────────────────────────────────────────────┘
```

### Data Flow

```
User types text → ChatInput.onSend()
  → ChatProvider.sendMessage(text)
    → ApiService.chatStream(messages, sessionId)  ← SSE streaming
      → POST /v1/chat/completions (OpenAI format)
        → Hermes API Server → AIAgent → response stream
    → ChatProvider updates messages list (real-time)
  → MessageBubble rebuilds with streaming content
```

### Voice Flow

```
User holds mic → ChatInput.onVoiceInput()
  → ChatProvider.startListening()
    → SpeechService.listen()  ← on-device STT
  → transcribed text → ChatProvider.sendMessage(text)
  → (same chat flow as above)
  → user taps speaker → ChatProvider.toggleSpeech()
    → SpeechService.speak(text)  ← on-device TTS
```

## API Contract

### Hermes API Server Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/chat/completions` | OpenAI-compatible chat (streaming) |
| GET | `/v1/models` | List available models |
| GET | `/health` | Health check |

### Request Format (chat completions)

```json
{
  "model": "hermes-agent",
  "messages": [
    {"role": "user", "content": "Hello"}
  ],
  "stream": true
}
```

### Response (SSE stream)

```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"content":"!"}}]}
data: [DONE]
```

### Headers

- `Authorization: Bearer <api_key>` — optional, only if API key is configured
- `X-Hermes-Session-Id: <uuid>` — for session continuity across requests
- `Accept: text/event-stream` — for streaming
- `Content-Type: application/json`

## File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Dart files | snake_case | `message_bubble.dart` |
| Classes | UpperCamelCase | `ChatProvider` |
| Constants | lowerCamelCase or SCREAMING_SNAKE | `defaultBaseUrl`, `SSE_DATA_PREFIX` |
| Variables | lowerCamelCase | `isLoading` |
| Private members | underscore prefix | `_messages` |
| File names in lib/ | snake_case, mirror class name | `chat_provider.dart` |
| Test files | `*_test.dart` | `message_test.dart` |

## State Management

Use `provider` package with `ChangeNotifier`:

- `ChatProvider` — messages list, API communication, voice state
- `SettingsProvider` — persistent settings (URL, API key, preferences)

Rules:
- Never mutate state directly — always through provider methods
- Call `notifyListeners()` after any state change
- Use `context.watch<T>()` for rebuilding on changes
- Use `context.read<T>()` for one-time reads (callbacks, initState)

## Project Structure

```
lib/
├── main.dart              # Entry point, MultiProvider setup
├── app.dart               # MaterialApp, theme, routes
├── config/
│   └── app_config.dart    # Constants (URLs, defaults)
├── models/
│   ├── message.dart       # Message model + MessageRole enum
│   └── conversation.dart  # Conversation model
├── services/
│   ├── api_service.dart   # HTTP client for Hermes API
│   ├── speech_service.dart # STT + TTS
│   └── storage_service.dart # Local DB (future)
├── providers/
│   ├── chat_provider.dart  # Chat state + API calls
│   └── settings_provider.dart # App settings
├── screens/
│   ├── chat_screen.dart         # Main chat UI
│   ├── conversations_screen.dart # History list
│   └── settings_screen.dart     # API config, preferences
└── widgets/
    ├── message_bubble.dart  # Single message display
    └── chat_input.dart      # Text input + mic button
```

## Testing

- Unit tests: `test/models/`, `test/services/`
- Widget tests: `test/widgets/`
- Integration tests: `test/integration/`

Run: `flutter test`

## Environment Setup

```bash
flutter pub get          # Install dependencies
flutter run              # Launch on connected device/emulator
flutter test             # Run tests
```

### Platform Setup After Flutter SDK Install

```bash
flutter create . --platforms=android,ios
```

This generates `android/` and `ios/` directories with native project files.

## Hermes API Server Setup

On the Hermes side, enable the API Server gateway:

```bash
# Configure via setup wizard
hermes gateway setup

# Or enable directly in config.yaml
# gateway:
#   platforms:
#     api_server:
#       enabled: true
#       host: "0.0.0.0"   # for mobile access
#       port: 8642

# Start the gateway
hermes gateway run
```

## Known Limitations

1. No conversation persistence yet (in-memory only, lost on app restart)
2. No attachment/file upload
3. No offline mode
4. Voice recognition quality depends on device STT engine (uses system default)

## Common Pitfalls

### macOS Sandbox Network Permission

macOS debug builds require `com.apple.security.network.client` entitlement to make outgoing HTTP requests. Without it, the app launches but silently fails to connect to any server. The default Flutter template only includes `network.server` (incoming connections).

Added in both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`.

### Android Build in China

Gradle/Maven downloads timeout from default Google servers. See `android/gradle/wrapper/gradle-wrapper.properties` (Tencent mirror) and `android/settings.gradle.kts` (Aliyun mirrors).

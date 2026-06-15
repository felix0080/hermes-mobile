# Hermes Mobile

Mobile client for [Hermes Agent](https://github.com/NousResearch/hermes-agent) — chat interface with voice support, powered by Hermes API Server.

## Features

- 💬 OpenAI-compatible chat interface (streaming responses)
- 🎤 Voice input (hold to talk, release to send)
- 🔊 Text-to-speech for responses
- 📱 iOS & Android (Flutter)
- 🔌 Connect to any Hermes API Server instance

## Quick Start

### Prerequisites

- Flutter SDK >= 3.29
- A running [Hermes Agent](https://github.com/NousResearch/hermes-agent) with API Server enabled

### Setup

```bash
# Clone
git clone https://github.com/felix0080/hermes-mobile.git
cd hermes-mobile

# Install dependencies
flutter pub get

# Run
flutter run
```

Configure your Hermes API Server URL in the app settings.

## Architecture

See [specs/PROJECT.md](specs/PROJECT.md) for full architecture and conventions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT

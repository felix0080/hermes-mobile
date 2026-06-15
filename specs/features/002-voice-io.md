# Feature: Voice Input & Output

## Status
done (MVP)

## Problem
Users want hands-free interaction: speak to Hermes and hear responses aloud. Essential for mobile use cases (driving, walking, accessibility).

## Design

### Voice Input (STT)
```
Hold mic button → start listening → release → stop + send
```

- On-device STT via `speech_to_text` package
- Uses system speech recognizer (Siri/Google)
- Language: Chinese (zh_CN), configurable later
- Visual feedback: mic icon turns red while listening

### Voice Output (TTS)
```
Tap speaker icon → TTS reads last assistant response
```

- On-device TTS via `flutter_tts` package
- Uses system TTS engine
- Auto-play option in settings

### States

| State | Mic Button | Speaker Button |
|-------|-----------|---------------|
| Idle | Mic icon (grey) | Speaker icon (grey) |
| Listening | Mic icon (red, pulsing) | Hidden/disabled |
| Speaking | Disabled | Speaker icon (active), stop on tap |
| Loading | Disabled (sending to API) | Hidden |

## Acceptance Criteria
- [x] Hold mic button starts voice recognition
- [x] Release mic button stops + sends transcribed text
- [x] Visual feedback during listening (red icon)
- [x] Tap speaker reads last assistant message
- [x] Tap speaker again stops playback
- [x] Auto-play TTS toggle in settings

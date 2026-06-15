# Feature: Settings & Configuration

## Status
done (MVP)

## Problem
Users need to configure the Hermes API Server connection and app preferences.

## Design

### Settings Page
```
┌──────────────────────────┐
│  Settings                │
├──────────────────────────┤
│  API Server URL          │
│  [http://localhost:8642] │
│                          │
│  API Key (optional)      │
│  [················]      │
│                          │
│  Auto-play TTS     [🔘] │
│                          │
│  ──────────────────────  │
│  About                   │
│  Hermes Mobile v0.1.0    │
└──────────────────────────┘
```

### Storage
- `shared_preferences` for key-value settings
- Keys: `base_url`, `api_key`, `model`, `auto_play_tts`
- Loaded on app start, saved on change

## Acceptance Criteria
- [x] User can set API Server URL
- [x] User can set optional API Key
- [x] User can toggle auto-play TTS
- [x] Settings persist across app restarts
- [x] Settings take effect immediately

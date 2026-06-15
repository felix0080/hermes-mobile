# Feature: Core Chat Interface

## Status
done (MVP)

## Problem
Users need a mobile chat interface to interact with Hermes Agent. The app must support streaming responses, message history display, and basic conversation management.

## Design

### UI Layout
```
┌──────────────────────────┐
│  AppBar (Hermes)   ⚙️ 📋  │
├──────────────────────────┤
│                          │
│   Messages list          │
│   (scrollable)           │
│                          │
│   ┌──────────────────┐   │
│   │ User message     │   │  ← right-aligned, primary color
│   └──────────────────┘   │
│   ┌──────────────────┐   │
│   │ Hermes response  │   │  ← left-aligned, surface color
│   │ (Markdown)       │   │     Markdown rendered
│   └──────────────────┘   │
│                          │
├──────────────────────────┤
│ [🎤] [______________] [→]│  ← input bar
└──────────────────────────┘
```

### States

| State | Behavior |
|-------|----------|
| Empty | Show placeholder icon + "Start a conversation" |
| Typing | Input field active, send button enabled when text exists |
| Sending | Send button → spinner, input disabled |
| Streaming | Response bubble shows partial text, cursor blinking |
| Done | Full response displayed, input re-enabled |
| Error | Error message shown in bubble, input re-enabled |

### Data Model

```
Message {
  id: String (uuid)
  content: String
  role: user | assistant | system
  timestamp: DateTime
  isStreaming: bool
}
```

### API Flow
1. User sends message → add to local list
2. POST /v1/chat/completions with stream=true
3. Parse SSE chunks → update assistant message in real-time
4. On [DONE] → mark message complete

### Session Continuity
- Generate a session ID on first message
- Send as `X-Hermes-Session-Id` header on subsequent requests
- Hermes API Server recognizes this and maintains context

## Acceptance Criteria
- [x] Text input sends message and displays in chat
- [x] Streaming response appears in real-time
- [x] Markdown rendered in assistant messages
- [x] Messages auto-scroll to bottom
- [x] Loading state shown during API call
- [x] Error state handled gracefully
- [x] Empty state shown when no messages
- [x] Session continuity via `X-Hermes-Session-Id`

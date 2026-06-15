# Feature: Multi-Server Support

## Status
in-progress

## Problem
Users may have multiple Hermes instances (local dev, remote server, work, personal). Currently the app only supports a single API server URL. Users need to add, manage, and switch between multiple servers.

## Design

### Data Model

```dart
class ServerConfig {
  String id;       // uuid
  String name;     // display name, e.g. "Home Mac", "VPS"
  String baseUrl;  // e.g. "http://192.168.1.100:8642"
  String apiKey;   // optional
}
```

### Storage
- `shared_preferences`: `servers` key stores JSON-encoded `List<ServerConfig>`
- `active_server_id`: which server is currently selected

### UI Changes

#### Server Switcher (AppBar)
```
┌──────────────────────────────────┐
│  ☰ Hermes  [Home Mac ▾]   📋 ⚙️ │  ← server dropdown in AppBar
├──────────────────────────────────┤
│  Chat area...                    │
```

#### Settings — Server Management
```
┌──────────────────────────────────┐
│  Servers                         │
├──────────────────────────────────┤
│  ● Home Mac         192.168...   │  ← active (dot indicator)
│    http://192.168.1.100:8642     │
│                                  │
│  ○ VPS               10.0.0...   │
│    http://10.0.0.50:8642        │
│                                  │
│  [+ Add Server]                  │
└──────────────────────────────────┘
```

#### Add/Edit Server Dialog
```
┌──────────────────────────────────┐
│  Add Server                      │
├──────────────────────────────────┤
│  Name: [________________]        │
│  URL:  [________________]        │
│  Key:  [________________]        │
│                                  │
│  [Test Connection]  [Save]       │
└──────────────────────────────────┘
```

### Behavior
- Active server indicated by dot in list
- Tap a server in list to switch → new conversation starts
- Swipe to delete (with confirmation)
- Long press to edit
- Switching servers clears current chat and starts fresh session
- Last active server remembered across app restarts
- If no servers configured, show setup prompt on first launch

## Acceptance Criteria
- [ ] User can add multiple Hermes servers (name, URL, API key)
- [ ] User can edit existing server configs
- [ ] User can delete server configs
- [ ] User can switch active server from AppBar dropdown
- [ ] User can switch active server from Settings
- [ ] Active server persists across app restarts
- [ ] Switching servers starts a new conversation
- [ ] Connection test button on add/edit dialog

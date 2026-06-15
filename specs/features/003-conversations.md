# Feature: Conversation Management

## Status
proposed

## Problem
Currently messages are in-memory only — lost on app restart. Users need persistent conversation history, the ability to start new conversations, and switch between them.

## Design

### Data Model

```
Conversation {
  id: String (uuid)
  title: String (first message or auto-generated)
  createdAt: DateTime
  updatedAt: DateTime
  messageCount: int
}
```

Messages stored in SQLite with foreign key to conversation.

### SQLite Schema

```sql
CREATE TABLE conversations (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  content TEXT NOT NULL,
  role TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id)
);
```

### UI States

| State | View |
|-------|------|
| Chat (active) | Current conversation with messages |
| Conversation list | All saved conversations, sorted by updatedAt |
| Empty list | "No conversations" placeholder |
| New conversation | Clears chat, starts fresh session |

### Actions
- New chat: button in AppBar or list
- Switch conversation: tap in list
- Delete conversation: swipe to delete
- Auto-save: save messages after each exchange
- Auto-title: use first user message as title

## Acceptance Criteria
- [ ] Messages persist across app restarts
- [ ] Conversation list shows all chats
- [ ] User can create new conversation
- [ ] User can switch between conversations
- [ ] User can delete conversations
- [ ] Conversations auto-save after each exchange
- [ ] Conversation title derived from first message

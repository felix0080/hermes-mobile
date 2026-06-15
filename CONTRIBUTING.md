# Contributing to Hermes Mobile

Thanks for your interest! Hermes Mobile is an open-source Flutter app that connects to Hermes Agent's API Server.

## Spec-Driven Development

This project uses **spec-driven development**. All features are designed in `specs/` before implementation. AI agents (Claude Code, Codex, etc.) read these specs to understand the project.

### Workflow

1. **Propose**: Create a spec in `specs/features/` describing the feature
2. **Implement**: Write code following the spec
3. **Review**: PR against `main` with the spec as reference

### Spec Format

See `specs/PROJECT.md` for the project architecture spec. Feature specs should follow this template:

```markdown
# Feature: <Name>

## Status
proposed | in-progress | done

## Problem
What user problem does this solve?

## Design
How it works, UI flows, data model changes.

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

## Project Structure

```
lib/
├── main.dart              # Entry point
├── app.dart               # MaterialApp + theme
├── config/                # App configuration
├── models/                # Data models
├── services/              # API, voice, storage
├── providers/             # State management
├── screens/               # Full-screen pages
└── widgets/               # Reusable UI components
```

## Conventions

- Use `provider` for state management
- One widget per file (except small private helpers)
- Dart file names: lowercase_with_underscores
- Class names: UpperCamelCase
- Constants use `static const` in classes
- Always use type annotations for public APIs

## License

By contributing, you agree your contributions will be licensed under MIT.

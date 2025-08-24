# CycleAvatar

A smart fitness tracking app with recovery-based avatar growth system.

## Project Structure

This project follows Clean Architecture principles with the following structure:

```
lib/
├── core/                           # Core functionality
│   ├── app/                       # App configuration
│   │   └── app_router.dart        # GoRouter configuration
│   ├── constants/                 # App constants
│   │   └── muscle_group_constants.dart
│   ├── l10n/                      # Localization
│   │   └── app_localizations.dart
│   ├── providers/                 # Global providers
│   │   └── providers.dart
│   └── theme/                     # App theming
│       └── app_theme.dart
├── data/                          # Data layer
│   ├── datasources/               # Data sources
│   │   └── local/
│   │       └── database_helper.dart
│   └── repositories/              # Repository implementations
│       └── user_repository_impl.dart
├── domain/                        # Domain layer
│   └── entities/                  # Domain entities
│       ├── exercise.dart
│       ├── muscle_group.dart
│       ├── user.dart
│       └── workout_session.dart
├── presentation/                  # Presentation layer
│   └── pages/                     # App pages
│       ├── avatar/
│       ├── history/
│       ├── home/
│       ├── settings/
│       └── workout/
└── l10n/                          # Localization files
    ├── app_en.arb
    └── app_ja.arb
```

## Features

- **Offline-first architecture** with SQLite local storage
- **Multi-language support** (English/Japanese)
- **Clean Architecture** with separation of concerns
- **State management** using Riverpod
- **Material Design 3** theming
- **Cross-platform** (Android/iOS)

## Key Dependencies

- `flutter_riverpod`: State management
- `sqflite`: Local database
- `go_router`: Navigation
- `dio`: HTTP client
- `freezed`: Immutable data classes
- `json_annotation`: JSON serialization

## Getting Started

1. Ensure Flutter SDK is installed
2. Run `flutter pub get` to install dependencies
3. Run `flutter pub run build_runner build` to generate code
4. Run `flutter run` to start the app

## Architecture Layers

### Domain Layer
Contains business entities and core business logic. Independent of external frameworks.

### Data Layer
Handles data persistence and external API communication. Implements repository interfaces defined in the domain layer.

### Presentation Layer
Contains UI components, pages, and state management. Depends on domain layer through dependency injection.

## Development Guidelines

- Follow Clean Architecture principles
- Use Riverpod for state management
- Implement proper error handling
- Write unit tests for business logic
- Use Freezed for immutable data classes
- Follow Flutter/Dart style guidelines
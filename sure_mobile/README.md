# Sure Mobile

A Flutter mobile application for Sure personal finance management. This app provides basic functionality to:

- **Login** - Authenticate with your Sure Finance server
- **View Balance** - See all your accounts and their balances

## Features

- 🔐 Secure authentication with OAuth 2.0
- 📱 Cross-platform support (Android & iOS)
- 💰 View all linked accounts
- 🎨 Material Design 3 with light/dark theme support
- 🔄 Token refresh for persistent sessions
- 🔒 Two-factor authentication (MFA) support

## Requirements

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK (for Android builds)
- Xcode (for iOS builds)

## Getting Started

### 1. Install Flutter

Follow the official Flutter installation guide: https://docs.flutter.dev/get-started/install

### 2. Install Dependencies

```bash
cd sure_mobile
flutter pub get
```

### 3. Configure API Endpoint

Edit `lib/services/api_config.dart` to point to your Sure Finance server:

```dart
// For local development with Android emulator
static String _baseUrl = 'http://10.0.2.2:3000';

// For local development with iOS simulator
static String _baseUrl = 'http://localhost:3000';

// For production
static String _baseUrl = 'https://your-sure-server.com';
```

### 4. Run the App

```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios

# For web (development only)
flutter run -d chrome
```

## Project Structure

```
sure_mobile/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   │   ├── account.dart
│   │   ├── auth_tokens.dart
│   │   └── user.dart
│   ├── providers/             # State management
│   │   ├── auth_provider.dart
│   │   └── accounts_provider.dart
│   ├── screens/               # UI screens
│   │   ├── login_screen.dart
│   │   └── dashboard_screen.dart
│   ├── services/              # API services
│   │   ├── api_config.dart
│   │   ├── auth_service.dart
│   │   ├── accounts_service.dart
│   │   └── device_service.dart
│   └── widgets/               # Reusable widgets
│       └── account_card.dart
├── android/                   # Android configuration
├── ios/                       # iOS configuration
├── pubspec.yaml               # Dependencies
└── README.md
```

## API Integration

This app integrates with the Sure Finance Rails API:

- `POST /api/v1/auth/login` - User authentication
- `POST /api/v1/auth/signup` - User registration
- `POST /api/v1/auth/refresh` - Token refresh
- `GET /api/v1/accounts` - Fetch user accounts

## Building for Release

### Android

```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Future Expansion

This app provides a foundation for additional features:

- Transaction history
- Account sync
- Budget management
- Investment tracking
- AI chat assistant
- Push notifications
- Biometric authentication

## License

This project is part of Sure Finance, distributed under the AGPLv3 license.

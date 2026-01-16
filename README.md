# VittaraFinOS

> **Track Wealth, Master Life**

A comprehensive personal finance management application built with Flutter, designed to help you manage your spending, track expenses, and gain insights into your financial health.

## Features

- 📊 **Financial Overview Dashboard** - Get a quick glance at your financial status
- 💰 **Expense Tracking** - Log and categorize your expenses
- 🏦 **Bank Management** - Connect and manage multiple bank accounts
- 📱 **Native iOS Experience** - Beautiful Cupertino-style UI for iOS users
- 🔄 **Cross-Platform Support** - Works on iOS, Android, Web, macOS, Windows, and Linux
- 🛡️ **Robust Error Handling** - Built-in logging and error tracking
- ⚡ **Smooth Animations** - Fintech-quality loader animations

## Tech Stack

- **Frontend**: Flutter 3.1+
- **Language**: Dart 3.1.0+
- **UI Framework**: Material Design + Cupertino (iOS)
- **State Management**: Built-in Flutter patterns
- **Logging**: Custom logger with file persistence
- **Animations**: Lottie JSON animations

## Project Structure

```
finance_app/
├── lib/
│   ├── main.dart                 # App entry point and routing
│   ├── ui/
│   │   ├── fintech_loader.dart  # Animated splash screen loader
│   │   ├── manage_screen.dart   # Bank management interface
│   │   └── manage/
│   │       └── banks_screen.dart # Bank account management
│   └── utils/
│       ├── logger.dart          # Logging utility
│       └── file_logger.dart     # File-based logging
├── assets/
│   └── animations/
│       └── loader.json          # Lottie animation files
├── android/                      # Android native code
├── ios/                         # iOS native code
├── web/                         # Web build configuration
├── macos/                       # macOS native code
├── windows/                     # Windows native code
└── linux/                       # Linux native code
```

## Getting Started

### Prerequisites

- Flutter SDK: 3.1.0 or higher
- Dart: 3.1.0 or higher
- For iOS: Xcode 12+
- For Android: Android Studio or Android SDK

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/msagastya/VittaraFinOS.git
   cd spend-analyzer
   ```

2. **Navigate to the Flutter project**
   ```bash
   cd finance_app
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## Dependencies

- **lottie** (^3.1.2) - JSON-based animations
- **logger** (^2.6.2) - Console logging
- **path_provider** (^2.1.2) - File system access
- **cupertino_icons** (^1.0.8) - iOS icon set

## App Screens

### Splash Screen
- Displays VittaraFinOS branding with animated fintech loader
- Auto-navigates to dashboard after 3.5 seconds
- Smooth transition with fade effects

### Dashboard Screen
- Main interface with financial overview
- Manage button - Access bank management settings
- Settings button - Configure app preferences
- iOS-style navigation bar for seamless UX

### Manage Screen
- Bank account management interface
- Add/remove connected bank accounts
- View bank details and linked accounts

## Error Handling

The app includes comprehensive error handling:
- **Flutter Framework Errors** - Caught and logged from the Flutter layer
- **Uncaught Exceptions** - Handled at the zone level
- **File-based Logging** - Errors are persisted to device storage
- **Logging Context** - Contextual information for debugging

## Building for Production

### iOS
```bash
flutter build ios --release
```

### Android
```bash
flutter build apk --release
```

### Web
```bash
flutter build web --release
```

### Windows
```bash
flutter build windows --release
```

### macOS
```bash
flutter build macos --release
```

### Linux
```bash
flutter build linux --release
```

## Development

### Running Tests
```bash
flutter test
```

### Code Analysis
```bash
flutter analyze
```

### Format Code
```bash
dart format lib/
```

## Logging

The app uses a custom logging system:

```dart
// Log information
logger.info('User logged in', context: 'AuthService');

// Log errors
logger.error('Payment failed',
  context: 'PaymentService',
  error: exception,
  stackTrace: stackTrace);
```

Logs are stored locally and can be accessed for debugging.

## Contributing

We welcome contributions! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please open an issue on the [GitHub Issues](https://github.com/msagastya/VittaraFinOS/issues) page.

## Roadmap

- [ ] Integration with real banking APIs
- [ ] Advanced expense categorization and analytics
- [ ] Budget management and alerts
- [ ] Multi-currency support
- [ ] Investment tracking
- [ ] Financial goal setting
- [ ] Export financial reports

## Author

**Sagastya M**
- GitHub: [@msagastya](https://github.com/msagastya)

---

**Track Wealth, Master Life** 💪

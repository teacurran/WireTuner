# T001: Flutter Project Setup for Desktop

## Status
- **Phase**: 0 - Foundation & Setup
- **Priority**: Critical
- **Estimated Effort**: 0.5 days
- **Dependencies**: None

## Overview
Create the initial Flutter project configured for macOS and Windows desktop targets. This establishes the foundational project structure for WireTuner.

## Objectives
- Initialize Flutter project with desktop support
- Configure for macOS and Windows targets
- Set up basic project structure and dependencies
- Verify project builds and runs on target platforms

## Requirements

### Functional Requirements
1. Flutter project initialized with desktop support enabled
2. macOS desktop target configured and building
3. Windows desktop target configured and building
4. Basic application window opens successfully
5. Project follows Flutter best practices for desktop apps

### Technical Requirements
- Flutter SDK 3.x or later
- Desktop support enabled (`flutter config --enable-macos-desktop --enable-windows-desktop`)
- Default window size: 1280x800
- Application name: "WireTuner"
- Package name: `com.wiretuner.app`

## Implementation Details

### Project Structure
```
wiretuner/
├── lib/
│   ├── main.dart                 # Application entry point
│   ├── screens/                  # Screen widgets
│   ├── models/                   # Data models
│   ├── widgets/                  # Reusable UI components
│   ├── services/                 # Business logic services
│   └── utils/                    # Utility functions
├── macos/                        # macOS platform code
├── windows/                      # Windows platform code
├── test/                         # Unit tests
└── pubspec.yaml                  # Dependencies
```

### Initial Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

### Main Application (lib/main.dart)
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const WireTunerApp());
}

class WireTunerApp extends StatelessWidget {
  const WireTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WireTuner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WireTuner'),
      ),
      body: const Center(
        child: Text(
          'WireTuner Vector Editor',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
```

## Success Criteria

### Automated Verification
- [ ] `flutter doctor` shows no critical issues
- [ ] `flutter build macos` completes successfully
- [ ] `flutter build windows` completes successfully (on Windows machine)
- [ ] `flutter analyze` shows no errors or warnings
- [ ] `flutter test` runs successfully (even with no tests yet)

### Manual Verification
- [ ] Application launches on macOS showing "WireTuner Vector Editor"
- [ ] Application launches on Windows showing "WireTuner Vector Editor"
- [ ] Window can be resized, minimized, and closed
- [ ] Window title shows "WireTuner"
- [ ] No console errors or warnings on launch

## Notes
- Windows testing requires a Windows machine or VM
- Consider using GitHub Actions for cross-platform CI later
- Desktop support may require additional platform-specific setup

## References
- Flutter Desktop Documentation: https://docs.flutter.dev/desktop
- Flutter Project Structure: https://docs.flutter.dev/development/tools/sdk/overview#project-structure
- Dissipate prototype main.dart: `/Users/tea/dev/github/dissipate/lib/main.dart`

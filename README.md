# CatechHub - Technical Documentation

CatechHub is a Flutter-based mobile application for local catechism register management. The application provides secure, offline-first data storage with PIN-based and biometric authentication, designed specifically for Android devices.

## Project Status

**Version:** 1.2.0  
**Status:** Stable Release  
**Platform:** Android (API 21+)  
**Flutter SDK:** ^3.12.0

## Technology Stack

### Core Framework
- **Flutter**: ^3.12.0 - UI framework and cross-platform development
- **Dart**: ^3.12.0 - Programming language

### State Management & Navigation
- **flutter_riverpod**: ^2.6.1 - State management and dependency injection
- **go_router**: ^17.2.3 - Declarative routing and navigation

### Authentication & Security
- **local_auth**: ^2.1.0 - Biometric authentication (fingerprint, face recognition)
- **flutter_secure_storage**: ^10.2.0 - Secure key-value storage for encryption keys
- **crypto**: ^3.0.0 - Cryptographic operations (SHA-256 hashing)

### Data Storage
- **hive_flutter**: ^1.1.0 - Local NoSQL database for offline data persistence
- **hive_generator**: ^2.0.1 - Code generation for Hive type adapters
- **build_runner**: ^2.4.9 - Code generation for Hive adapters

### QR Code & Data Sharing
- **qr_flutter**: ^4.1.0 - QR code generation
- **mobile_scanner**: ^5.0.0 - QR code scanning and camera integration

### File Management
- **file_picker**: ^12.0.0-beta.4 - File selection for data import/export
- **image_picker**: ^1.1.0 - Image capture and selection
- **path_provider**: ^2.1.0 - File system path access
- **open_filex**: ^4.5.0 - File opening and viewing

### PDF & Printing
- **pdf**: ^3.10.0 - PDF generation
- **printing**: ^5.11.0 - PDF printing and sharing

### UI & Utilities
- **intl**: ^0.20.2 - Internationalization and date formatting
- **url_launcher**: ^6.3.0 - URL launching for external links
- **http**: ^1.2.0 - HTTP client for API calls
- **package_info_plus**: ^10.0.0 - Package and app version information
- **device_info_plus**: ^13.1.0 - Device information access
- **permission_handler**: ^11.3.0 - Runtime permission management
- **flutter_local_notifications**: ^17.0.0 - Local notifications
- **wiredash**: ^2.6.1 - In-app feedback and bug reporting

## Architecture Overview

### Application Architecture
```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Widgets, Pages, UI Components)        │
├─────────────────────────────────────────┤
│         Business Logic Layer            │
│  (Providers, Services, Controllers)    │
├─────────────────────────────────────────┤
│           Data Layer                    │
│  (Repository, Local Storage, APIs)     │
├─────────────────────────────────────────┤
│         Infrastructure Layer            │
│  (Auth, Security, Network, Storage)    │
└─────────────────────────────────────────┘
```

### Security Architecture
- **Authentication**: PIN-based with SHA-256 hashing + salt
- **Biometric**: Device-local fingerprint/face recognition
- **Data Encryption**: AES encryption for sensitive data
- **Secure Storage**: Flutter Secure Storage for encryption keys
- **Screen Security**: Privacy settings to prevent screenshots
- **Session Management**: Automatic session timeout

### Data Flow
```
User Input → UI → Provider → Service → Repository → Local Storage
                ↓        ↓         ↓           ↓
            Validation  Business Logic  Encryption  Persistence
```

## Project Structure

```
lib/
├── main.dart                          # Application entry point
├── app/
│   ├── router.dart                     # GoRouter configuration
│   └── go_router_refresh_stream.dart   # Router refresh stream
├── core/
│   ├── auth/
│   │   ├── auth_provider.dart          # Authentication state management
│   │   ├── auth_service.dart           # Authentication business logic
│   │   └── session_lifecycle_observer.dart # Session lifecycle management
│   ├── storage/
│   │   └── local_database.dart         # Hive database initialization
│   ├── services/
│   │   ├── data_export_service.dart    # Data export/import functionality
│   │   ├── qr_data_service.dart        # QR code data handling
│   │   └── update_service.dart         # App update management
│   ├── navigation/
│   │   └── back_button_handler.dart    # Android back button handling
│   ├── security/
│   │   └── privacy_settings.dart       # Privacy and security settings
│   └── analytics/
│       ├── analytics_provider.dart     # Analytics state management
│       ├── analytics_service.dart     # Analytics tracking
│       └── event_tracking_service.dart # Event tracking service
├── features/
│   ├── auth/
│   │   └── login_page.dart             # Login and PIN entry
│   ├── dashboard/
│   │   └── dashboard_page.dart         # Main dashboard
│   ├── students/
│   │   ├── students_page.dart          # Student list
│   │   ├── student_detail_page.dart    # Student details
│   │   ├── allergies_page.dart        # Allergy management
│   │   └── autonomous_exits_page.dart  # Exit permissions
│   ├── classes/
│   │   ├── classes_page.dart           # Class management
│   │   ├── class_detail_page.dart      # Class details
│   │   ├── my_group_page.dart          # Group management
│   │   ├── group_management_page.dart  # Group administration
│   │   └── attendance_print_page.dart  # Attendance printing
│   ├── meetings/
│   │   ├── attendance_meetings_page.dart # Meeting management
│   │   └── attendance_page.dart        # Attendance tracking
│   ├── planning/
│   │   └── planning_page.dart         # Programming/planning
│   ├── documents/
│   │   ├── documents_page.dart        # Document management
│   │   └── document_detail_page.dart  # Document details
│   ├── data_share/
│   │   ├── data_share_selection_page.dart # Data share options
│   │   ├── data_share_send_page.dart  # QR sending
│   │   └── data_share_receive_page.dart # QR receiving
│   ├── settings/
│   │   ├── settings_page.dart         # Settings management
│   │   ├── privacy.dart               # Privacy settings
│   │   └── delete_data_page.dart      # Data deletion
│   ├── phone_verification/
│   │   └── verify_number_page.dart    # Phone verification
│   ├── update/
│   │   └── update_page.dart           # App updates
│   └── attachments/
│       └── widgets/
│           └── attachments_section.dart # Attachment widgets
└── shared/
    ├── widgets/
    │   └── app_scaffold.dart           # App scaffold wrapper
    └── models/
        └── student_model.dart         # Student data model
```

## Development Setup

### Prerequisites
- Flutter SDK >= 3.12.0
- Dart SDK >= 3.12.0
- Android Studio / VS Code with Flutter extension
- Android device or emulator (API 21+)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/CatechHub-dev/CatechHub.git
cd CatechHub

# Install dependencies
flutter pub get

# Generate Hive adapters (if needed)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running the Application

```bash
# Debug mode
flutter run

# Release mode
flutter run --release

# Specific device
flutter run -d <device-id>

# APK build
flutter build apk

# App bundle build
flutter build appbundle
```

## Data Management

### Local Storage (Hive)
- **Database**: Hive NoSQL database
- **Location**: App-specific directory on device
- **Encryption**: AES encryption for sensitive boxes
- **Key Storage**: Flutter Secure Storage for encryption keys

### Data Models
```dart
// Student Model
class Student {
  final String id;
  final String name;
  final String surname;
  final List<String> allergies;
  final Map<String, dynamic> attachments;
  // ... other fields
}

// Meeting Model
class Meeting {
  final String id;
  final DateTime date;
  final String topic;
  final Map<String, bool> attendance;
  // ... other fields
}
```

### Data Export/Import
- **Format**: JSON with base64 encoding
- **Compression**: Base64 encoding for data size reduction
- **Security**: Checksum verification using SHA-256
- **QR Sharing**: Chunked QR code transmission (max 600 chars per QR)

## QR Code System

### QR Code Generation
- **Library**: qr_flutter
- **Error Correction**: Level L (7%) for maximum readability
- **Chunk Size**: 600 characters per QR code
- **Data Format**: JSON with metadata (chunk index, total chunks, checksum)

### QR Code Scanning
- **Library**: mobile_scanner
- **Authentication**: PIN-based verification after data reception
- **Integrity**: SHA-256 checksum validation per chunk and complete package
- **Assembly**: Automatic chunk reassembly and validation

### QR Data Structure
```json
{
  "i": 0,              // chunk index
  "t": 3,              // total chunks
  "d": "base64data",   // encoded data
  "c": "checksum"      // chunk checksum
}
```

## Security Implementation

### Authentication Flow
1. **PIN Setup**: User creates 8-digit PIN during first launch
2. **PIN Storage**: SHA-256 hash stored in local storage
3. **Biometric**: Optional biometric enrollment after PIN setup
4. **Session**: Automatic session timeout after inactivity
5. **Screen Lock**: Privacy mode to prevent screenshots

### Data Encryption
- **Algorithm**: AES-256-CBC
- **Key Management**: Flutter Secure Storage
- **Scope**: Personal data, sensitive information
- **Performance**: Optimized encryption for mobile devices

### Permissions
- **Camera**: QR code scanning
- **Storage**: Data export/import and file attachments
- **Biometric**: Fingerprint/face recognition
- **Notifications**: Update alerts

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Widget Tests
```bash
flutter test test/widget/
```

## Build & Deployment

### Android Build
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

### Build Configuration
- **Minimum SDK**: 21 (Android 5.0)
- **Target SDK**: 34 (Android 14)
- **Compile SDK**: 34
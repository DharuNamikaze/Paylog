# Flutter SMS Transaction Parser

A Flutter application that monitors incoming SMS messages, identifies financial transactions, parses transaction details, and persists them to Firebase Firestore.

## Setup Instructions

### 1. Firebase Configuration

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add an Android app to your Firebase project
3. Use package name: `com.example.flutter_sms_parser`
4. Download the `google-services.json` file
5. Place it in `android/app/google-services.json`

### 2. Dependencies

Run the following command to install dependencies:

```bash
flutter pub get
```

### 3. Build and Run

```bash
flutter run
```

## Project Structure

```
lib/
├── core/           # Utilities, constants, and shared components
├── data/           # Data sources, repositories, and models
├── domain/         # Business logic, entities, and use cases
├── presentation/   # UI components, screens, and BLoCs
└── main.dart       # Application entry point
```

## Permissions

The app requires the following Android permissions:
- `READ_SMS`: To read existing SMS messages
- `RECEIVE_SMS`: To receive new SMS messages
- `INTERNET`: For Firebase connectivity
- `ACCESS_NETWORK_STATE`: To monitor network connectivity
- `WAKE_LOCK`: For background processing

## Features

- Automatic SMS monitoring for financial transactions
- Transaction parsing and classification
- Cloud storage with Firebase Firestore
- Offline queue with local storage
- Manual SMS input capability
- Real-time transaction dashboard
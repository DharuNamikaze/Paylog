# Firebase Setup Instructions

## Prerequisites
- Flutter SDK installed
- Android Studio or VS Code with Flutter extensions
- A Google account

## Step-by-Step Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `flutter-sms-parser` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

### 2. Add Android App to Firebase
1. In your Firebase project, click "Add app" and select Android
2. Enter the following details:
   - **Android package name**: `com.example.flutter_sms_parser`
   - **App nickname**: `Flutter SMS Parser` (optional)
   - **Debug signing certificate SHA-1**: (optional for now)
3. Click "Register app"

### 3. Download Configuration File
1. Download the `google-services.json` file
2. Place it in `android/app/google-services.json`
3. **Important**: Do not commit this file to version control

### 4. Enable Firestore Database
1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
4. Select a location for your database
5. Click "Done"

### 5. Set up Firestore Security Rules (Optional)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read/write their own transactions
    match /users/{userId}/transactions/{document} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 6. Test the Setup
1. Run `flutter pub get` to install dependencies
2. Run `flutter run` to test the app
3. Check that Firebase initializes without errors

## Troubleshooting

### Common Issues
1. **Build errors**: Ensure `google-services.json` is in the correct location
2. **Gradle sync issues**: Check that all Gradle files are properly configured
3. **Permission errors**: Ensure SMS permissions are declared in AndroidManifest.xml

### Verification
- App should start without Firebase initialization errors
- Check Android Studio logs for any Firebase-related warnings
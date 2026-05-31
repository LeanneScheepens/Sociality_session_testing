# Firebase Setup Guide for Sociality Sessions

This guide will help you set up Firebase for your Flutter session hosting app using the **free Spark plan**.

## 🚀 Quick Setup 

### Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `sociality-sessions` (or your preferred name)
4. Disable Google Analytics (optional for this project)
5. Click "Create project"

### Step 2: Enable Required Services

#### Enable Authentication
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Click **Anonymous** and enable it
3. Click **Save**

#### Enable Firestore Database
1. Go to **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (for development)
4. Select your preferred location
5. Click **Done**

### Step 3: Configure Flutter App

#### Install FlutterFire CLI
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure your project (run in your Flutter project root)
flutterfire configure
```

#### Or Manual Configuration
Als FlutterFire CLI niet werkt, vervang handmatig de waarden in `firebase_options.dart`:

**Stap 1: Ga naar Firebase Console**
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Selecteer je `sociality-sessions` project

**Stap 2: Voeg Flutter app toe**
1. Klik op **Project Settings** (gear icon)
2. Scroll naar beneden naar "Your apps"
3. Klik **Add app** → kies **Flutter** 🔥

**Stap 3: Registreer je app**
1. **Android package name**: `com.example.sociality_session_testing`
2. **App nickname**: `Sociality Sessions` (optioneel)
3. Klik **Register app**

**Stap 4: Kopieer configuratie waarden**
Je ziet nu de configuratie. Kopieer deze waarden:

```json
// Voor Android
{
  "apiKey": "AIzaSyC...",           // Kopieer deze
  "appId": "1:123:android:abc...", // En deze  
  "messagingSenderId": "123456789", // En deze
  "projectId": "je-project-naam",   // En deze
  "storageBucket": "je-project.appspot.com"
}
```

**Stap 5: Update firebase_options.dart**
Vervang in [firebase_options.dart](lib/firebase_options.dart):
- `YOUR_ANDROID_API_KEY` → jouw `apiKey`
- `YOUR_ANDROID_APP_ID` → jouw `appId` 
- `YOUR_MESSAGING_SENDER_ID` → jouw `messagingSenderId`
- `YOUR_PROJECT_ID` → jouw `projectId`

**Voorbeeld:**
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyC_jouw_echte_key_hier',
  appId: '1:123456789:android:abc123def456',
  messagingSenderId: '123456789',
  projectId: 'sociality-sessions-abc12',
  storageBucket: 'sociality-sessions-abc12.appspot.com',
);
```

## 📊 Firebase Free Tier Limits

Our app stays well within Firebase free limits:

| Service | Free Limit | Our Usage |
|---------|------------|-----------|
| **Firestore** | 50K reads, 20K writes, 20K deletes/day | ~10 operations per session |
| **Authentication** | 50K Monthly Active Users | Perfect for testing |
| **Cloud Functions** | 125K invocations/month | Optional cleanup |

## 🔧 Firestore Database Structure

The app creates this structure automatically:

```
sessions/
  {sessionId}/
    code: "ABC123"           // 6-character join code
    hostId: "user123"        // Host user ID
    hostName: "User123"      // Display name
    isActive: true           // Session status
    createdAt: timestamp     // Creation time
    participants: [          // Array of participants
      {
        id: "user123",
        name: "User123", 
        joinedAt: timestamp
      }
    ]
    sessionData: {}          // Your app's custom data
```

## 🔐 Security Rules

For development, use these test rules (⚠️ **Not for production**):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to sessions
    match /sessions/{sessionId} {
      allow read, write: if true;
    }
  }
}
```

For production, implement proper security:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /sessions/{sessionId} {
      allow read: if resource.data.isActive == true;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (request.auth.uid == resource.data.hostId || 
         request.auth.uid in resource.data.participants[].id);
      allow delete: if request.auth != null && 
        request.auth.uid == resource.data.hostId;
    }
  }
}
```

## 🏃‍♂️ How to Run

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Update Firebase configuration**:
   - Update `firebase_options.dart` with your project credentials

3. **Run the app:**
   ```bash
   flutter run
   ```

## ✨ Features Included

- ✅ **Host Sessions**: Generate unique 6-character codes
- ✅ **Join Sessions**: Real-time participant tracking  
- ✅ **Auto-cleanup**: Sessions end when host leaves
- ✅ **Real-time Updates**: Live participant list
- ✅ **Anonymous Auth**: No signup required
- ✅ **Cross-platform**: Works on iOS, Android, Web, Desktop

## 🆘 Troubleshooting

### Common Issues:

**Firebase not initialized:**
- Make sure `firebase_options.dart` has correct values
- Check if `flutterfire configure` was run successfully

**Authentication issues:**
- Ensure Anonymous auth is enabled in Firebase Console
- Check internet connection

**Firestore permission denied:**
- Verify Firestore rules allow read/write access
- Ensure database is in "test mode" for development

**Session not found:**
- Sessions are case-sensitive (codes are uppercase)
- Inactive sessions are automatically cleaned up
- Check if session still exists in Firestore console

## 🔄 Optional: Cloud Functions for Cleanup

To automatically clean up old sessions, you can deploy this Cloud Function:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Clean up sessions older than 24 hours
exports.cleanupOldSessions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const cutoff = new Date();
    cutoff.setHours(cutoff.getHours() - 24);
    
    const oldSessions = await admin.firestore()
      .collection('sessions')
      .where('createdAt', '<', cutoff)
      .get();
    
    const batch = admin.firestore().batch();
    oldSessions.forEach(doc => batch.delete(doc.ref));
    
    return batch.commit();
  });
```

## 📱 Next Steps

1. **Customize Session Data**: Add your app-specific data to `sessionData`
2. **Enhanced UI**: Customize the UI to match your app's design
3. **Push Notifications**: Notify users when sessions start/end
4. **User Profiles**: Replace anonymous auth with real user accounts
5. **Session Types**: Add different types of sessions (public/private)

## 🤝 Ready to Go!

Your session hosting system is now ready! Users can:
- Host sessions and share codes
- Join sessions instantly 
- See real-time participant updates
- Automatically leave when host ends session

The system leverages Firebase's real-time capabilities while staying within the generous free tier limits! 🎉
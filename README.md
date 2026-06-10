# Mini Live

Mini Live is a Flutter live-streaming app built around Agora RTC and Firebase. It supports host-led live rooms, audience viewing, chat, emoji reactions, RTMP restream targets, stream analytics, and a super-admin panel for managing Agora runtime configuration.

## Features

- Email, Google, and guest sign-in
- Admin host dashboard for creating and managing live streams
- Audience live room with chat and emoji reactions
- Host controls for mute, camera off, leave room, and end live
- Waiting state when the host leaves without ending the live
- Firestore-backed messages, viewer count, stream state, analytics, and RTMP targets
- Super-admin Agora configuration screen
- Android debug and release build support

## Requirements

- Flutter SDK with Dart 3.11 or newer
- Android Studio or a configured Android SDK
- Firebase project with Authentication, Firestore, and Crashlytics enabled
- Agora project with App ID and temporary token or backend-generated token
- Firebase CLI for deploying Firestore rules

Check your local setup:

```bash
flutter doctor
```

## Firebase Setup

1. Create or open a Firebase project.
2. Enable Authentication providers:
   - Email/password
   - Google sign-in, if required
   - Anonymous sign-in, if guest access is required
3. Enable Cloud Firestore.
4. Enable Crashlytics.
5. Add the Android app package:

```text
com.mini.app
```

6. Download `google-services.json` and place it here:

```text
android/app/google-services.json
```

7. Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

Firestore rules are stored in:

```text
firestore.rules
```

## Super Admin Account

The super-admin account is fixed:

```text
Email: superadmin@gmail.com
Password: 123456
```

Create this user once in Firebase Authentication. After that, do not create another super-admin account.

When this account logs in, the app keeps the Firestore user role as:

```text
superadmin
```

Super admin can update Agora settings from the Config tab:

- Agora App ID
- Agora Channel
- Agora Temp Token

Agora config cannot be changed while any live stream is running. End the live first, then update the config.

## User Roles

```text
user
```

Can watch live streams, send chat messages, and send emoji reactions.

```text
admin
```

Can create, start, rejoin, leave, and end live streams. Camera and microphone permissions are required before creating or starting a live.

```text
superadmin
```

Can update Agora runtime configuration. This role is reserved for `superadmin@gmail.com`.

## Agora Configuration

Default fallback values are in:

```text
lib/core/constants/app_constants.dart
```

Runtime values are loaded from Firestore:

```text
app_config/agora
```

The app uses Firestore values first. If the config document does not exist or cannot be read, it falls back to `AppConstants`.

After super admin saves a new Agora config, the local Agora engine is reset so the next live room uses the latest values.

## Install Dependencies

```bash
flutter pub get
```

## Run on Android

Connect a device or start an emulator:

```bash
flutter devices
flutter run
```

For release-mode testing:

```bash
flutter run --release
```

## Build APK

Debug APK:

```bash
flutter build apk --debug
```

Release APK:

```bash
flutter build apk --release
```

Generated APK files are available under:

```text
build/app/outputs/flutter-apk/
```

## Live Stream Flow

1. Admin logs in.
2. Admin opens Go Live.
3. App asks for camera and microphone permissions before creating or starting a live.
4. Admin creates a live.
5. Admin starts the live.
6. Audience users open the live from the Live tab.
7. If host leaves without ending, audience sees a waiting state.
8. If host rejoins, audience video resumes.
9. If host ends the live, audience is removed from the live room.

## Firestore Collections

```text
users
live_streams
live_streams/{streamId}/messages
rtmp_destinations
analytics
stream_events
app_config/agora
```

## Common Issues

### Start Live or Join keeps loading

- Confirm the device has internet.
- Confirm Firestore rules are deployed.
- Confirm the Agora App ID, channel, and token are valid.
- Confirm the token has not expired.

### Audience sees waiting for host

- Host may have left the room without ending the live.
- Host camera may be off.
- Host may not have completed Agora connection yet.

### Camera or microphone does not work

- Android app settings may have denied permissions.
- Open app settings and allow Camera and Microphone.

### Super admin cannot save config

- Check if a live stream is currently running.
- End all live streams before saving Agora config.
- Deploy Firestore rules again.

## Useful Commands

```bash
flutter analyze
flutter test
flutter build apk --debug
firebase deploy --only firestore:rules
```

## Project Structure

```text
lib/core
lib/features/auth
lib/features/live_stream
lib/features/rtmp
lib/features/analytics
lib/shared
```

The app follows a feature-first structure with repository interfaces, Firebase-backed implementations, BLoC state management, and shared models/widgets.

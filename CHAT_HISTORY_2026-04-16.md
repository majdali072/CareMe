# CareMe — session notes (2026-04-15 → 2026-04-16)

A human-readable summary of the chat for this session.

## Problems fixed & how

### 1. Location picker showed coordinates instead of an address
- Rewrote `lib/widgets/location_picker.dart` to use the `geocoding` Flutter plugin (native OS reverse geocoding — no HTTP key required on Android/iOS).
- Removed `lib/config/app_config.dart` and the web-only HTTP fallback that was added briefly.

### 2. AI chatbot now suggests admin-added doctors/pharmacies by location
- `backend/api/views.py` chat view:
  - Added `_haversine_km` helper.
  - Added `_nearby_contacts()` which picks up to 5 closest entries (≤50 km) from MongoDB collections `doctors` / `pharmacies`.
  - The lists (with name, address, phone, km distance) are injected into the Gemini system prompt.
- `SYSTEM_PROMPT` updated to instruct the model to recommend only from that list.

### 3. Google API key wiring
- Replaced the old key with `AIzaSyDxH73xrf5oJCGEzJk5R2VAg3NvbpraICQ` in:
  - `android/app/build.gradle.kts` (manifest placeholder default)
  - `ios/Runner/AppDelegate.swift`
  - `web/index.html`

### 4. APK build path
- Deleted corrupted NDK at `C:/Users/twoqu/AppData/Local/Android/sdk/ndk/28.2.13676358`.
- Installed missing `platforms;android-36` via sdkmanager (needed `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"`).
- Enabled core-library desugaring for `flutter_local_notifications`:
  ```kotlin
  compileOptions { isCoreLibraryDesugaringEnabled = true }
  dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
  ```
- Output: `build/app/outputs/flutter-apk/app-release.apk` (~54 MB).

### 5. Backend reachable from the phone
- Chose ngrok free tunnel (option B).
- Hard-coded ngrok URL in `lib/services/api_service.dart`: `https://entail-joining-pamphlet.ngrok-free.dev/api` (rotates when ngrok restarts — rebuild APK each time it changes).
- Added `ngrok-skip-browser-warning: 1` to default request headers.

### 6. Multiple runtime errors
- **Google sign-in error 10 (DEVELOPER_ERROR):** SHA-1 mismatch. Debug keystore SHA-1 on this machine: `A9:F5:88:95:84:69:D1:31:DF:50:58:88:40:85:F8:B0:40:00:8D:E6`. Fix = add this fingerprint in Firebase → the CareMe Android app → download fresh `google-services.json` into `android/app/`.
- **OTP reinstated** in `lib/screens/login_screen.dart` — non-admin password logins now send OTP and push the verification screen before `onLogin`.
- **Stay signed in after close** — added `shared_preferences` dep. `ApiService.loadSession()`/`_persistSession()` + `_clearSession()`. `main.dart` hydrates on startup, validates with `getProfile()`, shows a spinner while bootstrapping, then skips login if the token still works.
- **Download error "Bytes are required on Android & iOS":** `FilePicker.platform.saveFile()` now receives `bytes:` in `lib/screens/medications_screen.dart`. Desktop branch still calls `File.writeAsBytes`.

## Running the setup

Two terminals on the PC:

```
cd C:\Users\twoqu\Desktop\CareMe\backend
python manage.py runserver 0.0.0.0:8000
```

```
ngrok http 8000
```

Then open the installed APK on the phone. If ngrok URL changes, update `api_service.dart` `_baseUrl` and rebuild:

```
cd C:\Users\twoqu\Desktop\CareMe
flutter build apk --release
```

## Outstanding

- Google Sign-In will keep failing until the SHA-1 above is added in Firebase and a fresh `google-services.json` replaces the one in `android/app/`.
- Release APKs are signed with the debug keystore — fine for sideloading, not Play Store.
- Free ngrok rotates its URL on every restart (requires APK rebuild). Consider a reserved domain (paid) or Cloudflare Tunnel for stability.

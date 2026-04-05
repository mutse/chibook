# Chibook

A cross-platform Android/iOS reading app inspired by WeRead, built with Flutter.

## Phase 1 scope

- EPUB and PDF import from local files
- Bookshelf with recent progress
- Reader shells for EPUB and PDF
- AI voice read-aloud pipeline abstraction
- Local persistence for books, notes, and reading progress

## Stack

- Flutter
- Riverpod for state management
- GoRouter for navigation
- Sqflite for local metadata storage
- File Picker for book import
- Flutter TTS for on-device speech fallback
- OpenAI-compatible TTS endpoint adapter for cloud AI narration

## Project status

This repository currently contains the initial architecture and implementation skeleton.

## Mobile packaging

Android and iOS platform projects are included in:

- `android/`
- `ios/`

Common build commands:

```bash
/Users/mutse/development/flutter/bin/flutter pub get
/Users/mutse/development/flutter/bin/flutter analyze
/Users/mutse/development/flutter/bin/flutter build apk
/Users/mutse/development/flutter/bin/flutter build appbundle
/Users/mutse/development/flutter/bin/flutter build ios --no-codesign
```

Before publishing a release, update the default app identifiers and signing config:

- Android `applicationId`: `android/app/build.gradle.kts`
- iOS bundle identifier: `ios/Runner.xcodeproj/project.pbxproj`
- Android release signing: copy `android/key.properties.example` to `android/key.properties` and fill in your keystore values

Current default mobile identifiers:

- Android package: `ai.chibook.app`
- iOS bundle identifier: `ai.chibook.app`

## GitHub CI/CD

This repository now includes two GitHub Actions workflows:

- `.github/workflows/flutter-ci.yml`
- `.github/workflows/mobile-release.yml`

### CI

`flutter-ci.yml` runs on `pull_request` and common branch pushes, and executes:

- `flutter pub get`
- `flutter analyze`
- `flutter test`

### CD packaging

`mobile-release.yml` runs in two ways:

- Push a tag like `v0.1.0`
- Run it manually from GitHub Actions via `workflow_dispatch`

It produces:

- Android `app-release.apk`
- Android `app-release.aab`
- iOS `ipa`

When triggered by a tag, the workflow also publishes those artifacts to the corresponding GitHub Release.

### Required GitHub Secrets

Android signing:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded `.jks` or `.keystore`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

iOS signing:

- `IOS_CERTIFICATE_P12_BASE64`: base64-encoded distribution certificate `.p12`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`: base64-encoded `.mobileprovision`
- `IOS_KEYCHAIN_PASSWORD`: temporary CI keychain password

Optional GitHub Repository Variables:

- `IOS_BUNDLE_ID`: defaults to `ai.chibook.app`
- `IOS_TEAM_ID`: defaults to `X87NKU435C`

### Secret preparation examples

Encode Android keystore:

```bash
base64 -i android/keystore/release.jks | pbcopy
```

Encode iOS certificate:

```bash
base64 -i Certificates.p12 | pbcopy
```

Encode provisioning profile:

```bash
base64 -i profile.mobileprovision | pbcopy
```

### Recommended release flow

1. Configure the signing secrets and optional repository variables in GitHub.
2. Push a version tag such as `v0.1.0`.
3. Wait for the `Mobile Release` workflow to finish.
4. Download the artifacts from the workflow run or GitHub Release page.

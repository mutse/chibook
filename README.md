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

- Android `app-debug.apk`
- Android `app-release.aab`
- iOS `Runner.app` (unsigned)

When triggered by a tag, the workflow also publishes those artifacts to the corresponding GitHub Release.

### Signing behavior

`mobile-release.yml` does not require any GitHub Secrets.

- Android APK is built as `debug`, so it is signed with the default debug keystore generated in CI.
- Android AAB is built as `release`, but without a custom production keystore.
- iOS is built with `--no-codesign`, so the uploaded artifact is an unsigned `.app` bundle rather than an installable `.ipa`.

If you later want production signing and store-ready packages, you can add a separate signed release workflow.

### Recommended release flow

1. Push a version tag such as `v0.1.0`, or run the workflow manually in GitHub Actions.
2. Wait for the `Mobile Release` workflow to finish.
3. Download the artifacts from the workflow run or GitHub Release page.

# Local Signing Setup Guide

This document contains the exact commands and secrets needed to set up local signed builds and GitHub Actions releases.

## 1. Prerequisites

Install Flutter (stable) and Android Studio (includes JDK with `keytool`):
- Flutter: https://docs.flutter.dev/get-started/install
- Android Studio: https://developer.android.com/studio

Verify:
```bash
flutter doctor
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -version
```

## 2. Generate Android Scaffold

```bash
flutter create . --platforms android --project-name thousand_games --org com.thousandgames
```

This creates the `android/` folder (git-ignored).

## 3. Patch AndroidManifest (AdMob + INTERNET)

```powershell
powershell -ExecutionPolicy Bypass -File tool/patch_android_manifest.ps1
```

## 4. Place Keystore

Copy the generated `upload-keystore.jks` to `android/app/`:
```bash
cp upload-keystore.jks android/app/upload-keystore.jks
```

## 5. Create key.properties

Create `android/key.properties` (git-ignored):
```properties
storeFile=../upload-keystore.jks
storePassword=changeme123
keyAlias=thousandgames
keyPassword=changeme123
```

**⚠️ Change the passwords above to strong unique values before production use!**

## 6. Wire Signing Config into build.gradle

Run the CI preparation script (works in Git Bash / WSL):
```bash
export KEYSTORE_BASE64="$(base64 -w0 upload-keystore.jks)"
export KEYSTORE_PASSWORD="changeme123"
export KEY_ALIAS="thousandgames"
export KEY_PASSWORD="changeme123"
chmod +x tool/ci_prepare_android.sh
./tool/ci_prepare_android.sh
```

Or on Windows PowerShell:
```powershell
$env:KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
$env:KEYSTORE_PASSWORD = "changeme123"
$env:KEY_ALIAS = "thousandgames"
$env:KEY_PASSWORD = "changeme123"
bash tool/ci_prepare_android.sh
```

This patches `android/app/build.gradle` with the release signing config.

## 7. Build Signed Release APK

```bash
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## 8. Verify Installation

1. Transfer `app-release.apk` to Android device
2. Enable "Install unknown apps" for your file source
3. Tap APK to install

## 9. GitHub Actions Secrets

Go to: `https://github.com/bibekpanditdev/100-games/settings/secrets/actions`

Add these **Repository secrets**:

| Secret | Value |
|--------|-------|
| `KEYSTORE_BASE64` | `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` |
| `KEYSTORE_PASSWORD` | `changeme123` |
| `KEY_ALIAS` | `thousandgames` |
| `KEY_PASSWORD` | `changeme123` |

**⚠️ Change passwords before production!**

## 10. Release Process

```bash
# 1. Bump version in pubspec.yaml (e.g., 1.0.0+1)
# 2. Commit & push to main
git add pubspec.yaml
git commit -m "chore: bump version to 1.0.0"
git push origin main

# 3. Tag and push
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will:
- Build signed APK + AAB
- Create GitHub Release with artifacts attached
- Auto-generate release notes

## 11. Backup Keystore

**CRITICAL**: Losing the keystore = unable to sign future updates.

Backup locations:
- `upload-keystore.jks` (this file)
- Passwords: `changeme123` (store & key)
- Alias: `thousandgames`

Store in: password manager, encrypted drive, secure cloud backup.
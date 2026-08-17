#!/usr/bin/env bash
# CI-side Android preparation (ubuntu runners). The android/ folder is NOT
# committed — it is regenerated each build so it always matches the runner's
# Flutter version — and this script makes the generated project
# release-buildable:
#   1. flutter create . (android scaffold only)
#   2. patch AndroidManifest (INTERNET + AdMob app id)
#   3. decode the upload keystore from KEYSTORE_BASE64
#   4. write android/key.properties from signing env vars
#   5. wire the release signing config into app build.gradle(.kts)
# Everything is idempotent and safe for local use too.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "::group::Generate android/ scaffold"
flutter create . --platforms android --project-name thousand_games --org com.thousandgames
echo "::endgroup::"

echo "::group::Patch AndroidManifest"
chmod +x tool/patch_android_manifest.sh
./tool/patch_android_manifest.sh
echo "::endgroup::"

echo "::group::Keystore + key.properties"
if [ -z "${KEYSTORE_BASE64:-}" ] || [ -z "${KEYSTORE_PASSWORD:-}" ] \
   || [ -z "${KEY_ALIAS:-}" ] || [ -z "${KEY_PASSWORD:-}" ]; then
  echo "Signing secrets missing — release builds will fall back to the debug key."
  exit 0
fi

KEYSTORE_PATH="$PWD/android/app/upload-keystore.jks"
echo "$KEYSTORE_BASE64" | base64 -d > "$KEYSTORE_PATH"

cat > android/key.properties <<PROPS
storeFile=$KEYSTORE_PATH
storePassword=$KEYSTORE_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$KEY_PASSWORD
PROPS
echo "key.properties written (git-ignored; never committed)."
echo "::endgroup::"

# ---- Wire signing config into the app-level gradle file ----------------
GRADLE_GROOVY="android/app/build.gradle"
GRADLE_KTS="android/app/build.gradle.kts"

if [ -f "$GRADLE_GROOVY" ] && ! grep -q "keystoreProperties" "$GRADLE_GROOVY"; then
  echo "::group::Patch build.gradle (Groovy) signing"
  python3 - "$GRADLE_GROOVY" <<'EOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

loader = '''
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
'''
# Properties loader above the android {} block.
content = content.replace('android {', loader + '\nandroid {', 1)

signing_block = '''android {
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
'''
content = content.replace('android {', signing_block, 1)

# Release builds use the release config when key.properties exists.
content = content.replace(
    'signingConfig = signingConfigs.debug',
    "signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug",
)
with open(path, 'w') as f:
    f.write(content)
EOF
  echo "::endgroup::"

elif [ -f "$GRADLE_KTS" ] && ! grep -q "keystoreProperties" "$GRADLE_KTS"; then
  echo "::group::Patch build.gradle.kts (Kotlin DSL) signing"
  python3 - "$GRADLE_KTS" <<'EOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

loader = '''
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
'''
content = loader + '\n' + content

signing_block = '''android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
'''
content = content.replace('android {', signing_block, 1)

content = content.replace(
    'signingConfig = signingConfigs["debug"]',
    'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs["release"] else signingConfigs["debug"]',
)
content = content.replace(
    'signingConfig = signingConfigs.debug',
    'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs["release"] else signingConfigs["debug"]',
)
with open(path, 'w') as f:
    f.write(content)
EOF
  echo "::endgroup::"
fi

echo "Android signing preparation complete."

#!/usr/bin/env bash
# Patches android/app/src/main/AndroidManifest.xml after `flutter create .`:
#  - adds the INTERNET permission (required by AdMob; harmless offline)
#  - adds the AdMob APPLICATION_ID meta-data (Google's sample id by default)
# Idempotent: safe to run repeatedly. Replace the sample app id with yours
# before releasing.
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "Manifest not found at $MANIFEST. Run 'flutter create . --platforms android' first." >&2
  exit 1
fi

if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i 's|<manifest[^>]*>|&\n    <uses-permission android:name="android.permission.INTERNET" />|' "$MANIFEST"
  echo "Added INTERNET permission."
fi

if ! grep -q "com.google.android.gms.ads.APPLICATION_ID" "$MANIFEST"; then
  APP_ID="ca-app-pub-3940256099942544~3347511713"  # Google sample; replace for release
  python3 - "$MANIFEST" "$APP_ID" <<'EOF'
import sys, re
path, app_id = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
meta = f'    <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="{app_id}" />\n'
content = re.sub(r'(\s*)<application', rf'\1{meta}\1<application', content, count=1)
with open(path, 'w') as f:
    f.write(content)
EOF
  echo "Added AdMob APPLICATION_ID meta-data ($APP_ID)."
fi

echo "AndroidManifest.xml is ready."

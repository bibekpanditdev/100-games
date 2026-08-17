# Patches android/app/src/main/AndroidManifest.xml after `flutter create .`:
#  - adds the INTERNET permission (required by AdMob; harmless offline)
#  - adds the AdMob APPLICATION_ID meta-data (Google's sample id by default)
# Idempotent: safe to run repeatedly. Replace the sample app id with yours
# before releasing.

$manifest = "android/app/src/main/AndroidManifest.xml"

if (-not (Test-Path $manifest)) {
    Write-Error "Manifest not found at $manifest. Run 'flutter create . --platforms android --project-name thousand_games' first."
    exit 1
}

$content = Get-Content $manifest -Raw

if ($content -notmatch "android.permission.INTERNET") {
    $content = $content -replace "<manifest[^>]*>", "`$0`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
    Write-Host "Added INTERNET permission."
}

if ($content -notmatch "com.google.android.gms.ads.APPLICATION_ID") {
    $appId = "ca-app-pub-3940256099942544~3347511713"  # Google sample; replace for release
    $meta = "    <meta-data android:name=`"com.google.android.gms.ads.APPLICATION_ID`" android:value=`"$appId`" />`n"
    $content = $content -replace "(\s*)<application", "`$1$meta`$1<application"
    Write-Host "Added AdMob APPLICATION_ID meta-data ($appId)."
}

Set-Content -Path $manifest -Value $content -NoNewline
Write-Host "AndroidManifest.xml is ready."

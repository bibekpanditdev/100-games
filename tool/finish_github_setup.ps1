#!/usr/bin/env pwsh
# One-shot finish for the GitHub repo/CI setup. Run from the project folder
# in a NORMAL terminal (it opens a browser for GitHub login):
#
#   powershell -ExecutionPolicy Bypass -File tool\finish_github_setup.ps1
#
# What it does:
#   1. Fetches the GitHub CLI (portable, into ..\thousand-games-signing\) if
#      not installed, then `gh auth login` (browser, one time).
#   2. Pushes main + the v1.0.0 tag to github.com/bibekpanditdev/100-games.
#   3. Uploads the 4 signing secrets (KEYSTORE_BASE64, KEYSTORE_PASSWORD,
#      KEY_ALIAS, KEY_PASSWORD) from ..\thousand-games-signing\.
#   4. Applies branch protection on main (PRs required; admins exempt so
#      solo work isn't blocked).
#   5. Prints the live workflow run link so you can watch the signed APK
#      release build.
$ErrorActionPreference = 'Stop'

$repo = 'bibekpanditdev/100-games'
$signingDir = Join-Path (Split-Path (Get-Location) -Parent) 'thousand-games-signing'
$gitExe = Join-Path $signingDir 'mingit\cmd\git.exe'
$ghDir = Join-Path $signingDir 'gh'
$ghExe = Join-Path $ghDir 'bin\gh.exe'
$credsFile = Join-Path $signingDir 'keystore-credentials.txt'
$keystoreB64 = Join-Path $signingDir 'upload-keystore.jks.base64'

if (-not (Test-Path $credsFile) -or -not (Test-Path $keystoreB64)) {
  throw "Signing material not found in $signingDir (keystore-credentials.txt / upload-keystore.jks.base64)."
}

# ---- 1. GitHub CLI ----------------------------------------------------------
if (-not (Test-Path $ghExe)) {
  Write-Host 'Downloading GitHub CLI (portable)...'
  $api = Invoke-RestMethod 'https://api.github.com/repos/cli/cli/releases/latest'
  $asset = $api.assets | Where-Object { $_.name -match 'windows_amd64\.zip$' } | Select-Object -First 1
  $zip = Join-Path $signingDir 'gh.zip'
  Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath $ghDir -Force
  # The zip contains gh_<ver>_windows_amd64/ — flatten it.
  $inner = Get-ChildItem $ghDir -Directory | Where-Object Name -match '^gh_' | Select-Object -First 1
  if ($inner) { Move-Item $inner.FullName "$ghDir\tmp" -Force; Remove-Item "$ghDir\bin" -Recurse -Force -ErrorAction SilentlyContinue; Move-Item "$ghDir\tmp\*" $ghDir -Force; Remove-Item "$ghDir\tmp" -Recurse -Force }
  Remove-Item $zip
}
$gh = $ghExe

& $gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Signing in to GitHub — complete the browser prompt.' -ForegroundColor Cyan
  & $gh auth login --hostname github.com --git-protocol https --web
  if ($LASTEXITCODE -ne 0) { throw 'gh auth login failed.' }
}
& $gh auth setup-git 2>&1 | Out-Null

# ---- 2. Push main + tag ------------------------------------------------------
Write-Host 'Pushing main + v1.0.0...' -ForegroundColor Cyan
& $gitExe push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
& $gitExe push origin v1.0.0
if ($LASTEXITCODE -ne 0) { throw 'git push of the tag failed.' }

# ---- 3. Signing secrets ------------------------------------------------------
Write-Host 'Uploading signing secrets...' -ForegroundColor Cyan
$cred = Get-Content $credsFile -Raw
$storePassword = ([regex]::Match($cred, 'storePassword=(\S+)')).Groups[1].Value
$alias = ([regex]::Match($cred, 'keyAlias=(\S+)')).Groups[1].Value

Get-Content $keystoreB64 -Raw | & $gh secret set KEYSTORE_BASE64 --repo $repo
$storePassword | & $gh secret set KEYSTORE_PASSWORD --repo $repo
$alias | & $gh secret set KEY_ALIAS --repo $repo
$storePassword | & $gh secret set KEY_PASSWORD --repo $repo

# ---- 4. Branch protection ----------------------------------------------------
Write-Host 'Applying branch protection on main...' -ForegroundColor Cyan
$protection = @'
{
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "enforce_admins": false,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true
}
'@
$protection | & $gh api -X PUT "repos/$repo/branches/main/protection" --input - 2>&1 | Out-Null

# ---- 5. Point at the running workflow ----------------------------------------
Start-Sleep -Seconds 5
$run = & $gh run list --repo $repo --limit 1 --json url,displayTitle 2>$null | ConvertFrom-Json
if ($run) {
  Write-Host ''
  Write-Host ("Release build started: " + $run[0].url) -ForegroundColor Green
  Write-Host 'Watch it finish, then grab the signed APK from the Releases page.'
} else {
  Write-Host 'No workflow run detected yet — check the Actions tab.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'IMPORTANT: back up the keystore + password from' -ForegroundColor Yellow
Write-Host "  $signingDir" -ForegroundColor Yellow
Write-Host 'to a safe place outside GitHub (losing it permanently breaks app updates).' -ForegroundColor Yellow

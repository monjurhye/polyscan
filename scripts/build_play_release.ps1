# Builds the signed Play bundle with the real Android AdMob IDs.
# Usage: scripts\build_play_release.ps1 -BuildNumber 1
# The IDs come from docs/android-release.md; versionName comes from pubspec.yaml.
# Raise -BuildNumber on every upload: Play never accepts the same number twice.
param(
    [Parameter(Mandatory)][int]$BuildNumber,
    [Parameter(Mandatory)][string]$AppId,
    [Parameter(Mandatory)][string]$Banner,
    [Parameter(Mandatory)][string]$Interstitial,
    [Parameter(Mandatory)][string]$AppOpen
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

if (-not (Test-Path 'android\key.properties')) { throw 'android\key.properties is missing: restore it from the key backup.' }
foreach ($id in $AppId, $Banner, $Interstitial, $AppOpen) {
    # Google's test IDs earn nothing, and a release must never ship with them.
    if ($id -like 'ca-app-pub-3940256099942544*') { throw "$id is Google's test ID." }
}

# build.gradle.kts reads the app ID from the environment; a stale Gradle daemon would keep the old value.
$env:ADMOB_ANDROID_APP_ID = $AppId
flutter build appbundle --release --build-number=$BuildNumber `
    --dart-define=ADMOB_ANDROID_BANNER=$Banner `
    --dart-define=ADMOB_ANDROID_INTERSTITIAL=$Interstitial `
    --dart-define=ADMOB_ANDROID_APP_OPEN=$AppOpen
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed.' }
Get-Item build\app\outputs\bundle\release\app-release.aab | Select-Object FullName, Length

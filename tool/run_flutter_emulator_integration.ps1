# BASMA — Flutter ↔ Firebase Emulator integration_test runner (Windows)
#
# Prerequisites:
#   1. Firebase Emulator Suite on demo-rafiq-rules
#        npm --prefix functions run serve
#   2. Seed (fresh empty emulator only):
#        node functions/scripts/seed-integration-fixture.mjs
#   3. Android Emulator OR physical device with adb (USB/Wi-Fi).
#      App uses 127.0.0.1 + automaticHostMapping:false → requires adb reverse.
#
# Usage:
#   powershell -File tool/run_flutter_emulator_integration.ps1
#   powershell -File tool/run_flutter_emulator_integration.ps1 <adb-device-id>
#
# Never targets Production. Fails if USE_FIREBASE_EMULATOR is omitted.
# Does not uninstall or clear app data. Same package as installed `dev` debug.

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

# Cursor/agent sandboxes sometimes redirect GRADLE_USER_HOME into a temp cache
# that stalls dependency resolution. Prefer the real user Gradle home.
if ($env:GRADLE_USER_HOME -and $env:GRADLE_USER_HOME -match 'cursor-sandbox-cache|Temp\\cursor') {
  Write-Host "Clearing sandboxed GRADLE_USER_HOME=$($env:GRADLE_USER_HOME)"
  Remove-Item Env:GRADLE_USER_HOME -ErrorAction SilentlyContinue
}
if (-not $env:JAVA_HOME -and (Test-Path "$env:ProgramFiles\Android\Android Studio\jbr")) {
  $env:JAVA_HOME = "$env:ProgramFiles\Android\Android Studio\jbr"
  $env:Path = "$env:JAVA_HOME\bin;" + $env:Path
}

function Test-EmulatorPorts {
  foreach ($port in 9099, 8080, 5001, 9199) {
    $ok = $false
    try {
      $c = New-Object System.Net.Sockets.TcpClient
      $iar = $c.BeginConnect('127.0.0.1', $port, $null, $null)
      $ok = $iar.AsyncWaitHandle.WaitOne(1500, $false) -and $c.Connected
      $c.Close()
    } catch { $ok = $false }
    if (-not $ok) {
      throw "Firebase Emulator port 127.0.0.1:$port is closed. Start demo-rafiq-rules emulators first; refusing Production fallback."
    }
  }
}

Test-EmulatorPorts

$device = $args[0]
if (-not $device) {
  $devices = flutter devices --machine | ConvertFrom-Json
  # Prefer a physical phone over the Android Emulator when both are attached.
  $android = @(
    $devices | Where-Object {
      $_.targetPlatform -like 'android*' -and $_.emulator -ne $true -and $_.id -notlike 'emulator-*'
    }
    $devices | Where-Object { $_.targetPlatform -like 'android*' }
  ) | Select-Object -First 1
  if (-not $android) {
    Write-Error "No Android device. Connect a phone (USB/Wi-Fi adb) or launch an AVD."
  }
  $device = $android.id
}

Write-Host "Using device: $device"
Write-Host "Applying adb reverse for Emulator loopback ports..."
adb -s $device reverse tcp:9099 tcp:9099
adb -s $device reverse tcp:8080 tcp:8080
adb -s $device reverse tcp:5001 tcp:5001
adb -s $device reverse tcp:9199 tcp:9199
adb -s $device reverse --list

flutter test integration_test `
  --flavor dev `
  --dart-define=USE_FIREBASE_EMULATOR=true `
  -d $device

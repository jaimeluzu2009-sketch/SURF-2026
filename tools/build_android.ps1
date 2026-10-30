param([ValidateSet("All", "APK", "AAB")][string]$Format = "All")
$ErrorActionPreference = "Stop"
$proj = Split-Path $PSScriptRoot -Parent
$tools = $env:BARRELS_TOOLS
if ([string]::IsNullOrWhiteSpace($tools)) { $tools = "A:\CLAUDE\Herramientas" }
$keys = $env:BARRELS_KEYS_DIR
if ([string]::IsNullOrWhiteSpace($keys)) { $keys = Join-Path (Split-Path $proj -Parent) "barrels-claves" }
$tmp = "$tools\tmp\barrels-android"
New-Item -ItemType Directory -Force $tmp, "$proj\build\android" | Out-Null
$envNames = @("GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD", "GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "JAVA_HOME", "ANDROID_HOME", "GRADLE_USER_HOME", "TEMP", "TMP", "JAVA_TOOL_OPTIONS")
$old = @{}
foreach ($name in $envNames) { $old[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
 $line = Get-Content "$keys\contrasena.txt" | Where-Object { $_ -like "Contrase*" }
 $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = ($line -split ": ", 2)[1].Trim()
 $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "$keys\barrels-upload.jks"
 $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "barrels"
 $env:JAVA_HOME = "$tools\jdk-17"
 $env:ANDROID_HOME = "$tools\android-sdk"
 $env:GRADLE_USER_HOME = "$tools\gradle-home"
 $env:TEMP = $tmp
 $env:TMP = $tmp
 $env:JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Djava.io.tmpdir=$tmp"
 $jobs = @()
 if ($Format -in @("All", "AAB")) { $jobs += ,@("Android Play Store", "barrels-1.2.0.aab") }
 if ($Format -in @("All", "APK")) { $jobs += ,@("Android APK", "barrels-1.2.0.apk") }
 foreach ($job in $jobs) {
  $log = "$tmp\$($job[1]).log"
  $destination = "$proj\build\android\$($job[1])"
  & "$tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path $proj --export-release $job[0] $destination *> $log
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $destination)) { Get-Content $log -Tail 25; throw "Falló la exportación $($job[0])" }
  Get-Item -LiteralPath $destination | Select-Object Name, Length, LastWriteTime
 }
} finally {
 foreach ($name in $envNames) { [Environment]::SetEnvironmentVariable($name, $old[$name], 'Process') }
}

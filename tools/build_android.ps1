# Compila BARRELS para Android: AAB para Google Play y APK universal para instalar a mano.
# Uso (PowerShell, desde la carpeta del proyecto):  .\tools\build_android.ps1
# Antes de cada versión nueva sube version/code (y version/name) en export_presets.cfg.

$ErrorActionPreference = "Stop"
$proj = Split-Path $PSScriptRoot -Parent
$tools = "A:\CLAUDE\Herramientas"
$keys = "A:\PROYECTOS 3D GODOT\barrels-claves"
$tmp = "$tools\tmp\android-build"
New-Item -ItemType Directory -Force $tmp, "$proj\build\android" | Out-Null

# La contraseña se lee del archivo de claves: no se guarda en el proyecto.
$line = Get-Content "$keys\contrasena.txt" | Where-Object { $_ -like "Contrase*" }
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = ($line -split ": ", 2)[1].Trim()
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = "$keys\barrels-upload.jks"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "barrels"
$env:JAVA_HOME = "$tools\jdk-17"
$env:ANDROID_HOME = "$tools\android-sdk"
$env:GRADLE_USER_HOME = "$tools\gradle-home"
# Todo lo temporal en A: (el disco C: está casi lleno). Java usa los certificados de Windows
# porque Avast inspecciona HTTPS con su propio certificado raíz.
$env:TEMP = $tmp
$env:TMP = $tmp
$env:JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT -Djava.io.tmpdir=$tmp"

$godot = "$tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
foreach ($job in @(@("Android Play Store", "build/android/barrels.aab"), @("Android APK", "build/android/barrels.apk"))) {
	Write-Host "Exportando $($job[0])..."
	& $godot --headless --path $proj --export-release $job[0] $job[1] *> "$tmp\$($job[0] -replace ' ', '_').log"
	Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force  # cierra el daemon de Gradle
	Get-Item "$proj\$($job[1])" | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }, LastWriteTime
}

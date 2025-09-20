
param(
    [string]$NdkVersion = "27.0.12077973"
)

Write-Host "==> Regenerating android/ with your local Flutter..." -ForegroundColor Cyan
if (Test-Path ".\android") { Remove-Item -Recurse -Force .\android }
flutter create . | Out-Host

# Ensure local.properties has flutter.sdk
$lp = ".\android\local.properties"
if (!(Test-Path $lp)) {
  throw "android\local.properties not found. Flutter should have created it. Run 'flutter doctor'."
}
# Read and show
Write-Host "==> Found local.properties:" -ForegroundColor Cyan
Get-Content $lp | Out-Host

# Patch app/build.gradle
$gradle = ".\android\app\build.gradle"
if (!(Test-Path $gradle)) { throw "Expected $gradle" }
$txt = Get-Content $gradle -Raw

# Insert/ensure compileOptions, kotlinOptions, ndkVersion, debug/release, desugaring dep
$txt = $txt -replace 'compileOptions\s*\{[^}]*\}', 'compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled true
    }'

$txt = $txt -replace 'kotlinOptions\s*\{[^}]*\}', "kotlinOptions { jvmTarget = '17' }"

# Ensure ndkVersion line exists inside android { }
if ($txt -notmatch 'ndkVersion') {
    $txt = $txt -replace '(android\s*\{)', "`${1}`r`n    ndkVersion `"$NdkVersion`""
} else {
    $txt = $txt -replace 'ndkVersion\s*".*?"', "ndkVersion `"$NdkVersion`""
}

# Force debug buildType to disable shrink
$txt = $txt -replace 'debug\s*\{[^}]*\}', 'debug {
            minifyEnabled false
            shrinkResources false
        }'

# Add desugaring dependency if missing
if ($txt -notmatch 'coreLibraryDesugaring') {
    $txt = $txt -replace '(dependencies\s*\{)', "${1}`r`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'"
}

Set-Content -Path $gradle -Value $txt -Encoding UTF8
Write-Host "==> Patched android/app/build.gradle" -ForegroundColor Green

# Manifest: add POST_NOTIFICATIONS permission (outside <application>), remove ${applicationName}
$manifest = ".\android\app\src\main\AndroidManifest.xml"
$mtxt = Get-Content $manifest -Raw
$mtxt = $mtxt -replace 'android:name="\$\{applicationName\}"', ''
if ($mtxt -notmatch 'POST_NOTIFICATIONS') {
    $mtxt = $mtxt -replace '(<manifest[^>]*>)', '$1' + "`r`n    <uses-permission android:name=""android.permission.POST_NOTIFICATIONS""/>"
}
Set-Content -Path $manifest -Value $mtxt -Encoding UTF8
Write-Host "==> Patched AndroidManifest.xml" -ForegroundColor Green

# Ensure MainActivity.kt with embedding v2 exists
$pkgPath = ".\android\app\src\main\kotlin\com\example\monitoreo_movil"
New-Item -ItemType Directory -Force -Path $pkgPath | Out-Null
$mainKt = @"
package com.example.monitoreo_movil
import io.flutter.embedding.android.FlutterActivity
class MainActivity : FlutterActivity()
"@
Set-Content -Path (Join-Path $pkgPath "MainActivity.kt") -Value $mainKt -Encoding UTF8
Write-Host "==> Ensured MainActivity.kt (embedding v2)" -ForegroundColor Green

# Create minimal proguard rules
$proguard = ".\android\app\proguard-rules.pro"
if (!(Test-Path $proguard)) {
  @"
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepattributes *Annotation*
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
"@ | Set-Content -Path $proguard -Encoding UTF8
  Write-Host "==> Created proguard-rules.pro" -ForegroundColor Green
}

Write-Host "==> Done. Now run:" -ForegroundColor Cyan
Write-Host "    flutter clean" -ForegroundColor Yellow
Write-Host "    flutter pub get" -ForegroundColor Yellow
Write-Host "    flutter run" -ForegroundColor Yellow

Param(
  [Parameter(Mandatory = $false)]
  [string]$GoogleServiceInfoPlist = "ios/Runner/GoogleService-Info.plist",

  [Parameter(Mandatory = $false)]
  [string]$SupabaseProjectDir = ".",

  [Parameter(Mandatory = $false)]
  [switch]$AlsoSetAdmin
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $GoogleServiceInfoPlist)) {
  throw "GoogleService-Info.plist not found at: $GoogleServiceInfoPlist"
}

$plist = Get-Content -LiteralPath $GoogleServiceInfoPlist -Raw

function Get-PlistValue([string]$content, [string]$key) {
  $pattern = "<key>${key}</key>\s*<string>([^<]+)</string>"
  $m = [Regex]::Match($content, $pattern)
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return ""
}

$iosAppId = Get-PlistValue $plist "GOOGLE_APP_ID"
$apiKey = Get-PlistValue $plist "API_KEY"
$projectId = Get-PlistValue $plist "PROJECT_ID"
$senderId = Get-PlistValue $plist "GCM_SENDER_ID"
$storageBucket = Get-PlistValue $plist "STORAGE_BUCKET"
$bundleId = Get-PlistValue $plist "BUNDLE_ID"

if (-not $iosAppId) {
  throw "GOOGLE_APP_ID not found in plist."
}

$tempDir = Join-Path $env:TEMP ("supabase-secrets-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null
$envFile = Join-Path $tempDir "firebase_ios.secrets.env"

$lines = @()
if ($apiKey) { $lines += "FIREBASE_API_KEY=$apiKey" }
if ($projectId) { $lines += "FIREBASE_PROJECT_ID=$projectId" }
if ($senderId) { $lines += "FIREBASE_MESSAGING_SENDER_ID=$senderId" }
if ($storageBucket) { $lines += "FIREBASE_STORAGE_BUCKET=$storageBucket" }
if ($bundleId) { $lines += "FIREBASE_IOS_BUNDLE_ID=$bundleId" }
$lines += "FIREBASE_IOS_APP_ID=$iosAppId"

if ($AlsoSetAdmin) {
  $lines += "FIREBASE_IOS_APP_ID_ADMIN=$iosAppId"
}

Set-Content -LiteralPath $envFile -Value ($lines -join "`n") -NoNewline

Push-Location $SupabaseProjectDir
try {
  $null = (Get-Command supabase -ErrorAction Stop)
  supabase secrets set --env-file $envFile | Out-Null
}
finally {
  Pop-Location
  Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "OK: Supabase secrets updated from $GoogleServiceInfoPlist (iOS)."

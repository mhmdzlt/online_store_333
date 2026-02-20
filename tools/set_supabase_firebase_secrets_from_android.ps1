Param(
  [Parameter(Mandatory = $false)]
  [string]$GoogleServicesJson = "android/app/google-services.json",

  [Parameter(Mandatory = $false)]
  [string]$SupabaseProjectDir = ".",

  [Parameter(Mandatory = $false)]
  [string]$AppPackageName = "com.example.online_store_333",

  [Parameter(Mandatory = $false)]
  [switch]$AlsoSetAdmin
)

$ErrorActionPreference = 'Stop'

function Get-ClientForPackage($gs, $packageName) {
  foreach ($client in $gs.client) {
    $pkg = $client.client_info.android_client_info.package_name
    if ($pkg -eq $packageName) {
      return $client
    }
  }
  return $null
}

if (-not (Test-Path -LiteralPath $GoogleServicesJson)) {
  throw "google-services.json not found at: $GoogleServicesJson"
}

$gs = Get-Content -LiteralPath $GoogleServicesJson -Raw | ConvertFrom-Json
$client = Get-ClientForPackage $gs $AppPackageName
if ($null -eq $client) {
  throw "No client found in google-services.json for package: $AppPackageName"
}

$apiKey = $client.api_key[0].current_key
$projectId = $gs.project_info.project_id
$senderId = $gs.project_info.project_number
$storageBucket = $gs.project_info.storage_bucket
$androidAppId = $client.client_info.mobilesdk_app_id

if (-not $apiKey -or -not $projectId -or -not $senderId -or -not $androidAppId) {
  throw "Missing required fields in google-services.json (apiKey/projectId/senderId/androidAppId)."
}

# Create a temp env file so secrets are not passed on the command line.
$tempDir = Join-Path $env:TEMP ("supabase-secrets-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null
$envFile = Join-Path $tempDir "firebase.secrets.env"

$lines = @(
  "FIREBASE_API_KEY=$apiKey",
  "FIREBASE_PROJECT_ID=$projectId",
  "FIREBASE_MESSAGING_SENDER_ID=$senderId",
  "FIREBASE_STORAGE_BUCKET=$storageBucket",
  "FIREBASE_ANDROID_APP_ID=$androidAppId"
)

if ($AlsoSetAdmin) {
  $lines += "FIREBASE_ANDROID_APP_ID_ADMIN=$androidAppId"
}

Set-Content -LiteralPath $envFile -Value ($lines -join "`n") -NoNewline

Push-Location $SupabaseProjectDir
try {
  # Best-effort: check supabase CLI exists.
  $null = (Get-Command supabase -ErrorAction Stop)

  # Set secrets from env file.
  supabase secrets set --env-file $envFile | Out-Null
}
finally {
  Pop-Location
  Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "OK: Supabase secrets updated from $GoogleServicesJson (Android only)."
Write-Output "NOTE: iOS App ID is not set; Edge Function now returns missing=['ios.appId'] but still succeeds for Android."

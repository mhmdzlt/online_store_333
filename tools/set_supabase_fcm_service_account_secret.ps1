Param(
  [Parameter(Mandatory = $true)]
  [string]$ServiceAccountJsonPath,

  [Parameter(Mandatory = $false)]
  [string]$SupabaseProjectDir = ".",

  [Parameter(Mandatory = $false)]
  [switch]$RotatePushSecret,

  [Parameter(Mandatory = $false)]
  [string]$OutputPushSecretPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ServiceAccountJsonPath)) {
  throw "Service account json not found: $ServiceAccountJsonPath"
}

$raw = Get-Content -LiteralPath $ServiceAccountJsonPath -Raw
if (-not $raw -or $raw.Trim().Length -lt 10) {
  throw "Service account json file is empty or invalid."
}

# Encode to base64 to avoid env/newline issues.
$bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
$b64 = [Convert]::ToBase64String($bytes)

# Create a temp env file so secrets are not passed on the command line.
$tempDir = Join-Path $env:TEMP ("supabase-secrets-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null
$envFile = Join-Path $tempDir "fcm_service_account.env"

$lines = @(
  "FIREBASE_SERVICE_ACCOUNT_JSON_B64=$b64"
)

if ($RotatePushSecret) {
  $pushSecret = [Guid]::NewGuid().ToString('N')
  $lines += "PUSH_SEND_SECRET=$pushSecret"
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

Write-Output "OK: Supabase secrets updated: FIREBASE_SERVICE_ACCOUNT_JSON_B64" 
if ($RotatePushSecret) {
  Write-Output "OK: Supabase secret updated: PUSH_SEND_SECRET (new random value)"
  Write-Output "IMPORTANT: Keep PUSH_SEND_SECRET private (do not embed in mobile apps)."

  if ($OutputPushSecretPath) {
    $outDir = Split-Path -Parent $OutputPushSecretPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
      New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    Set-Content -LiteralPath $OutputPushSecretPath -Value $pushSecret -NoNewline
    Write-Output "OK: PUSH_SEND_SECRET written locally to: $OutputPushSecretPath"
  }
}

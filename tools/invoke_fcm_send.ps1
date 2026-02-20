Param(
  [Parameter(Mandatory = $true)]
  [string]$SupabaseAnonKey,

  [Parameter(Mandatory = $false)]
  [string]$SupabaseProjectRef = "enxihyplaelrdkievkrk",

  [Parameter(Mandatory = $false)]
  [string]$PushSecretPath = ".\tools\.secrets\push_send_secret.txt",

  [Parameter(Mandatory = $false)]
  [string]$Phone,

  [Parameter(Mandatory = $false)]
  [string]$Token,

  [Parameter(Mandatory = $true)]
  [string]$Title,

  [Parameter(Mandatory = $true)]
  [string]$Body,

  [Parameter(Mandatory = $false)]
  [string]$Route = "home"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PushSecretPath)) {
  throw "Push secret file not found: $PushSecretPath"
}

$pushSecret = (Get-Content -LiteralPath $PushSecretPath -Raw).Trim()
if (-not $pushSecret) {
  throw "Push secret file is empty: $PushSecretPath"
}

if (-not $Phone -and -not $Token) {
  throw "Provide -Phone or -Token"
}

$url = "https://$SupabaseProjectRef.supabase.co/functions/v1/fcm_send"
$headers = @{
  apikey        = $SupabaseAnonKey
  Authorization = "Bearer $SupabaseAnonKey"
  'Content-Type' = 'application/json'
  'x-push-secret' = $pushSecret
}

$payload = @{
  title = $Title
  body  = $Body
  route = $Route
}
if ($Phone) { $payload.phone = $Phone }
if ($Token) { $payload.token = $Token }

$json = ($payload | ConvertTo-Json -Depth 6)

try {
  $res = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $json
  [Console]::WriteLine("OK: sent=$($res.sent) failed=$($res.failed)")
} catch {
  [Console]::WriteLine("ERROR")
  if ($_.Exception.Response -and $_.Exception.Response.GetResponseStream()) {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    [Console]::WriteLine($reader.ReadToEnd())
  } else {
    [Console]::WriteLine($_.Exception.Message)
  }
}

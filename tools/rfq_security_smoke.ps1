$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$supabaseConfigPath = Join-Path $repoRoot 'lib/core/config/supabase_config.dart'

$base = $env:SUPABASE_URL
$anon = $env:SUPABASE_ANON_KEY

if ([string]::IsNullOrWhiteSpace($base) -or [string]::IsNullOrWhiteSpace($anon)) {
  if (Test-Path $supabaseConfigPath) {
    $content = Get-Content $supabaseConfigPath -Raw
    $urlMatch = [regex]::Match($content, "url\s*=\s*'([^']+)'")
    $keyMatch = [regex]::Match($content, "anonKey\s*=\s*'([^']+)'")

    if ([string]::IsNullOrWhiteSpace($base) -and $urlMatch.Success) {
      $base = $urlMatch.Groups[1].Value
    }
    if ([string]::IsNullOrWhiteSpace($anon) -and $keyMatch.Success) {
      $anon = $keyMatch.Groups[1].Value
    }
  }
}

if ([string]::IsNullOrWhiteSpace($base) -or [string]::IsNullOrWhiteSpace($anon)) {
  Write-Host 'FAIL: Missing SUPABASE_URL or SUPABASE_ANON_KEY.' -ForegroundColor Red
  Write-Host 'Set env vars or keep lib/core/config/supabase_config.dart with url/anonKey constants.'
  exit 2
}

$base = $base.TrimEnd('/')
$headers = @{
  apikey = $anon
  Authorization = "Bearer $anon"
  'Content-Type' = 'application/json'
}

$passed = 0
$failed = 0

function Pass([string]$name) {
  $script:passed++
  Write-Host "PASS: $name" -ForegroundColor Green
}

function Fail([string]$name, [string]$msg) {
  $script:failed++
  Write-Host "FAIL: $name :: $msg" -ForegroundColor Red
}

# 1) anon direct table access should be blocked
try {
  Invoke-RestMethod -Uri "$base/rest/v1/part_requests?select=id&limit=1" -Headers $headers -Method Get | Out-Null
  Fail 'anon_table_select_blocked' 'expected deny but request succeeded'
} catch {
  if ($_.Exception.Message -match '401|403|Unauthorized|permission') {
    Pass 'anon_table_select_blocked'
  } else {
    Fail 'anon_table_select_blocked' $_.Exception.Message
  }
}

# 2) valid request creation should succeed
$created = $null
try {
  $goodBody = @{
    p_customer_name = 'Security Test'
    p_customer_phone = '07712345678'
    p_description = 'rfq security test'
    p_image_urls = @('https://example.com/a.jpg')
  } | ConvertTo-Json -Depth 5

  $created = Invoke-RestMethod -Uri "$base/rest/v1/rpc/create_part_request_public" -Headers $headers -Method Post -Body $goodBody

  if ($created.request_number -and $created.access_token) {
    Pass 'create_part_request_valid'
  } else {
    Fail 'create_part_request_valid' 'missing request_number/access_token'
  }
} catch {
  Fail 'create_part_request_valid' $_.Exception.Message
}

# 3) empty phone must fail
try {
  $badBody = @{
    p_customer_name = 'X'
    p_customer_phone = ''
    p_description = 'bad'
  } | ConvertTo-Json -Depth 5

  Invoke-RestMethod -Uri "$base/rest/v1/rpc/create_part_request_public" -Headers $headers -Method Post -Body $badBody | Out-Null
  Fail 'create_part_request_empty_phone_rejected' 'expected failure but succeeded'
} catch {
  if ($_.Exception.Message -match '400|Customer phone is required|Invalid customer phone length') {
    Pass 'create_part_request_empty_phone_rejected'
  } else {
    Fail 'create_part_request_empty_phone_rejected' $_.Exception.Message
  }
}

# 4) thread creation should return null unless seller has submitted offer
try {
  $threadBody = @{
    p_request_number = $created.request_number
    p_access_token = $created.access_token
    p_seller_id = '00000000-0000-0000-0000-000000000001'
  } | ConvertTo-Json -Depth 4

  $threadRes = Invoke-RestMethod -Uri "$base/rest/v1/rpc/get_or_create_part_thread_public" -Headers $headers -Method Post -Body $threadBody

  if (($null -eq $threadRes) -or ($threadRes -eq 'null')) {
    Pass 'thread_requires_seller_offer'
  } else {
    Fail 'thread_requires_seller_offer' "expected null, got $threadRes"
  }
} catch {
  Fail 'thread_requires_seller_offer' $_.Exception.Message
}

# 5) seller-only RPC must fail for anon
try {
  $sellerBody = @{
    p_request_id = '00000000-0000-0000-0000-000000000001'
    p_message = 'hello'
  } | ConvertTo-Json

  Invoke-RestMethod -Uri "$base/rest/v1/rpc/send_part_message_seller" -Headers $headers -Method Post -Body $sellerBody | Out-Null
  Fail 'seller_rpc_blocked_for_anon' 'expected failure but succeeded'
} catch {
  if ($_.Exception.Message -match '401|Not authenticated|permission|Unauthorized') {
    Pass 'seller_rpc_blocked_for_anon'
  } else {
    Fail 'seller_rpc_blocked_for_anon' $_.Exception.Message
  }
}

Write-Host "SUMMARY: passed=$passed failed=$failed"
if ($failed -gt 0) {
  exit 1
}

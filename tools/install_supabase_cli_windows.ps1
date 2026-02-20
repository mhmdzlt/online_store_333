$ErrorActionPreference = 'Stop'

# Installs Supabase CLI on Windows without npm.
# Downloads the official GitHub release asset in small HTTP Range chunks
# to avoid truncated downloads on unstable/proxied networks.

$version = $env:SUPABASE_CLI_VERSION
if ([string]::IsNullOrWhiteSpace($version)) {
  $version = 'v2.75.0'
}

$arch = $env:SUPABASE_CLI_ARCH
if ([string]::IsNullOrWhiteSpace($arch)) {
  $arch = 'amd64'
}

$assetName = "supabase_windows_${arch}.tar.gz"
$sourceUrl = "https://github.com/supabase/cli/releases/download/$version/$assetName"

Write-Host "Supabase CLI asset: $assetName ($version)" -ForegroundColor Cyan

function Get-RemoteFileSizeBytes([string] $url) {
  # Prefer Content-Range from a 0-0 range request (reliable across redirects).
  $headers = & curl.exe -sS -L --fail -D - -o NUL -H 'Range: bytes=0-0' $url
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to query remote headers.'
  }

  $lines = $headers -split "`r?`n"
  $contentRange = ($lines | Where-Object { $_ -match '^Content-Range:\s*bytes\s+\d+-\d+\/\d+' } | Select-Object -Last 1)
  if ($contentRange) {
    return [int64](($contentRange -replace '^Content-Range:\s*bytes\s+\d+-\d+\/', ''))
  }

  # Fallback: last Content-Length (ignore redirects that often report 0).
  $lenLine = ($lines | Where-Object { $_ -match '^Content-Length:\s*\d+' } | Select-Object -Last 1)
  if ($lenLine) {
    return [int64]($lenLine -replace '^Content-Length:\s*', '')
  }

  throw 'Could not determine remote file size (no Content-Range or Content-Length).'
}

$total = Get-RemoteFileSizeBytes $sourceUrl

Write-Host "Total bytes: $total" -ForegroundColor Cyan

$chunk = 2097152 # 2MB
$base = Join-Path $env:TEMP "supabase_cli_$assetName.part"
$tarPath = Join-Path $env:TEMP $assetName
$installDir = Join-Path $env:LOCALAPPDATA "Supabase\\cli\\$version"

# Build ranges
$ranges = New-Object System.Collections.Generic.List[object]
for ($start = 0; $start -lt $total; $start += $chunk) {
  $end = [Math]::Min($start + $chunk - 1, $total - 1)
  $ranges.Add([pscustomobject]@{ Start = $start; End = $end; Expected = ($end - $start + 1) })
}

foreach ($r in $ranges) {
  $partPath = "$base.$($r.Start)-$($r.End)"

  $needs = $true
  if (Test-Path $partPath) {
    $existing = (Get-Item $partPath).Length
    if ($existing -eq $r.Expected) { $needs = $false }
  }

  if (-not $needs) {
    continue
  }

  $ok = $false
  for ($attempt = 1; $attempt -le 10 -and -not $ok; $attempt++) {
    Remove-Item -Force -ErrorAction SilentlyContinue $partPath

    Write-Host ("GET {0}-{1} (attempt {2})" -f $r.Start, $r.End, $attempt)
    # Use the stable GitHub release URL and follow redirects each time.
    & curl.exe -sS -L --fail --retry 6 --retry-all-errors --retry-delay 2 --http1.1 `
      -H ("Range: bytes={0}-{1}" -f $r.Start, $r.End) `
      -o $partPath `
      $sourceUrl

    if ($LASTEXITCODE -ne 0) {
      continue
    }

    if (-not (Test-Path $partPath)) {
      continue
    }

    $got = (Get-Item $partPath).Length
    if ($got -ne $r.Expected) {
      continue
    }

    $ok = $true
  }

  if (-not $ok) {
    throw ("Failed downloading range {0}-{1}" -f $r.Start, $r.End)
  }
}

# Combine parts into a single tar.gz
Remove-Item -Force -ErrorAction SilentlyContinue $tarPath
$out = [System.IO.File]::Open($tarPath, [System.IO.FileMode]::CreateNew)
try {
  foreach ($r in $ranges) {
    $partPath = "$base.$($r.Start)-$($r.End)"
    $bytes = [System.IO.File]::ReadAllBytes($partPath)
    $out.Write($bytes, 0, $bytes.Length)
  }
} finally {
  $out.Close()
}

$actual = (Get-Item $tarPath).Length
Write-Host "Combined bytes: $actual" -ForegroundColor Cyan
if ($actual -ne $total) {
  throw "Combined size mismatch. Expected $total got $actual"
}

# Extract supabase.exe
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $installDir
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

tar -xzf $tarPath -C $installDir

$exePath = Join-Path $installDir 'supabase.exe'
if (-not (Test-Path $exePath)) {
  throw "supabase.exe not found in $installDir"
}

Write-Host "Installed: $exePath" -ForegroundColor Green
& $exePath --version

Write-Host "\nAdd to PATH for this session:" -ForegroundColor Yellow
Write-Host "  $env:Path = '$installDir;' + $env:Path"
Write-Host "\nOr add permanently (User PATH) via Windows Environment Variables." -ForegroundColor Yellow

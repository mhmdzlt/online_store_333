param(
  [string]$Repo = "mhmdzlt/online_store_333",
  [string]$IOSBundleId,
  [string]$AppleTeamId,
  [string]$AscKeyId,
  [string]$AscIssuerId,
  [string]$AscKeyP8Path,
  [string]$AscKeyP8B64,
  [string]$MatchGitUrl,
  [string]$MatchPassword,
  [switch]$RunWorkflow,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-GhPath {
  $cmd = Get-Command gh -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $default = "C:\Program Files\GitHub CLI\gh.exe"
  if (Test-Path $default) { return $default }

  throw "GitHub CLI not found. Install it first (winget install --id GitHub.cli -e)."
}

function Set-GitHubSecret {
  param(
    [string]$GhPath,
    [string]$Repo,
    [string]$Name,
    [string]$Value,
    [switch]$DryRun
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    Write-Output "SKIP: $Name is empty"
    return
  }

  if ($DryRun) {
    Write-Output "DRY-RUN: would set secret $Name"
    return
  }

  $tmp = New-TemporaryFile
  try {
    Set-Content -Path $tmp -Value $Value -NoNewline -Encoding UTF8
    Get-Content -Raw -Path $tmp | & $GhPath secret set $Name -R $Repo | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed setting secret $Name"
    }
    Write-Output "OK: $Name"
  }
  finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
  }
}

$gh = Get-GhPath

# Validate auth
if (-not $DryRun) {
  & $gh auth status | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Not authenticated with GitHub CLI. Run: gh auth login"
  }
}

if ([string]::IsNullOrWhiteSpace($IOSBundleId)) {
  $plistPath = Join-Path $PSScriptRoot "..\ios\Runner\GoogleService-Info.plist"
  if (Test-Path $plistPath) {
    $plistText = Get-Content -Raw -Path $plistPath
    $m = [regex]::Match($plistText, '<key>BUNDLE_ID</key>\s*<string>([^<]+)</string>')
    if ($m.Success) {
      $IOSBundleId = $m.Groups[1].Value.Trim()
      Write-Output "Auto-detected IOS_BUNDLE_ID=$IOSBundleId"
    }
  }
}

if ([string]::IsNullOrWhiteSpace($AscKeyP8B64) -and -not [string]::IsNullOrWhiteSpace($AscKeyP8Path)) {
  if (-not (Test-Path $AscKeyP8Path)) {
    throw "ASC key file not found: $AscKeyP8Path"
  }
  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $AscKeyP8Path))
  $AscKeyP8B64 = [Convert]::ToBase64String($bytes)
  Write-Output "ASC_KEY_P8_B64 generated from file"
}

Set-GitHubSecret -GhPath $gh -Repo $Repo -Name "IOS_BUNDLE_ID" -Value $IOSBundleId -DryRun:$DryRun
Set-GitHubSecret -GhPath $gh -Repo $Repo -Name "APPLE_TEAM_ID" -Value $AppleTeamId -DryRun:$DryRun
Set-GitHubSecret -GhPath $gh -Repo $Repo -Name "ASC_KEY_ID" -Value $AscKeyId -DryRun:$DryRun
Set-GitHubSecret -GhPath $gh -Repo $Repo -Name "ASC_ISSUER_ID" -Value $AscIssuerId -DryRun:$DryRun
Set-GitHubSecret -GhPath $gh -Repo $Repo -Name "ASC_KEY_P8_B64" -Value $AscKeyP8B64 -DryRun:$DryRun
Set-GitHubSecret -GhPath $gh -Repo $Repo -Name "MATCH_GIT_URL" -Value $MatchGitUrl -DryRun:$DryRun
Set-GitHubSecret -GhPath $gh -Repo $Repo -Name "MATCH_PASSWORD" -Value $MatchPassword -DryRun:$DryRun

if ($RunWorkflow) {
  if ($DryRun) {
    Write-Output "DRY-RUN: would trigger workflow 'iOS TestFlight'"
  }
  else {
    & $gh workflow run "iOS TestFlight" -R $Repo
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to trigger workflow iOS TestFlight"
    }
    Write-Output "OK: Triggered workflow iOS TestFlight"
  }
}

Write-Output "Done."

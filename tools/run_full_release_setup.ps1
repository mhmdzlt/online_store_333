param(
  [string]$Repo = "mhmdzlt/online_store_333",
  [string]$IOSBundleId,
  [string]$AppleTeamId,
  [string]$AscKeyId,
  [string]$AscIssuerId,
  [string]$AscKeyP8Path,
  [string]$MatchGitUrl,
  [string]$MatchPassword
)

$ErrorActionPreference = 'Stop'

function Get-GhPath {
  $cmd = Get-Command gh -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $default = "C:\Program Files\GitHub CLI\gh.exe"
  if (Test-Path $default) { return $default }

  throw "GitHub CLI not found. Install first: winget install --id GitHub.cli -e"
}

$gh = Get-GhPath

# Ensure authentication
& $gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Output "GitHub auth required. Starting interactive login..."
  & $gh auth login -w
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub login failed or was cancelled."
  }
}

# Ask for missing values interactively (secure input where appropriate)
if ([string]::IsNullOrWhiteSpace($AppleTeamId)) {
  $AppleTeamId = Read-Host "Enter APPLE_TEAM_ID"
}
if ([string]::IsNullOrWhiteSpace($AscKeyId)) {
  $AscKeyId = Read-Host "Enter ASC_KEY_ID"
}
if ([string]::IsNullOrWhiteSpace($AscIssuerId)) {
  $AscIssuerId = Read-Host "Enter ASC_ISSUER_ID"
}
if ([string]::IsNullOrWhiteSpace($AscKeyP8Path)) {
  $AscKeyP8Path = Read-Host "Enter full path to AuthKey_XXXXXX.p8"
}
if ([string]::IsNullOrWhiteSpace($MatchGitUrl)) {
  $MatchGitUrl = Read-Host "Enter MATCH_GIT_URL"
}
if ([string]::IsNullOrWhiteSpace($MatchPassword)) {
  $secure = Read-Host "Enter MATCH_PASSWORD" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $MatchPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

$setupScript = Join-Path $PSScriptRoot "set_github_testflight_secrets.ps1"
if (-not (Test-Path $setupScript)) {
  throw "Missing script: $setupScript"
}

& $setupScript \
  -Repo $Repo \
  -IOSBundleId $IOSBundleId \
  -AppleTeamId $AppleTeamId \
  -AscKeyId $AscKeyId \
  -AscIssuerId $AscIssuerId \
  -AscKeyP8Path $AscKeyP8Path \
  -MatchGitUrl $MatchGitUrl \
  -MatchPassword $MatchPassword \
  -RunWorkflow

if ($LASTEXITCODE -ne 0) {
  throw "Failed during secrets setup/workflow trigger."
}

Write-Output "All done: secrets configured and iOS TestFlight workflow triggered."

# GitHub Secrets required for iOS TestFlight workflow

This repo contains a workflow that can build iOS on GitHub-hosted macOS runners.
Uploading to TestFlight requires signing + App Store Connect API access.

## Required secrets

### App Store Connect API Key
- `ASC_KEY_ID`: App Store Connect API key ID
- `ASC_ISSUER_ID`: issuer ID
- `ASC_KEY_P8_B64`: base64 of the `.p8` key file contents

How to base64 encode on Windows PowerShell:

```powershell
$bytes = [System.IO.File]::ReadAllBytes('AuthKey_XXXXXX.p8')
[Convert]::ToBase64String($bytes) | Set-Clipboard
```

### Signing (fastlane match)
- `MATCH_GIT_URL`: private git repo URL used by match (e.g. `https://github.com/<org>/<repo>.git`)
- `MATCH_PASSWORD`: password used to encrypt the match repo

### Project identifiers
- `IOS_BUNDLE_ID`: e.g. `com.example.onlineStore333` (should be your final production bundle id)
- `APPLE_TEAM_ID`: your Apple Developer Team ID

## One-command setup (recommended)

Use the helper script in this repo to set all secrets in one run:

```powershell
pwsh .\tools\set_github_testflight_secrets.ps1 \
	-Repo "mhmdzlt/online_store_333" \
	-AppleTeamId "YOUR_TEAM_ID" \
	-AscKeyId "YOUR_ASC_KEY_ID" \
	-AscIssuerId "YOUR_ASC_ISSUER_ID" \
	-AscKeyP8Path "C:\path\to\AuthKey_XXXXXX.p8" \
	-MatchGitUrl "https://github.com/<org>/<repo>.git" \
	-MatchPassword "YOUR_MATCH_PASSWORD" \
	-RunWorkflow
```

Notes:
- `IOS_BUNDLE_ID` is auto-detected from `ios/Runner/GoogleService-Info.plist` if not provided.
- Requires GitHub CLI auth first: `gh auth login`.

## Upload behavior

The workflow now auto-detects whether upload can run:

- If all required secrets are present, it runs `fastlane testflight`.
- If any secret is missing, it skips upload and prints a clear message.

Run it manually from Actions → iOS TestFlight → Run workflow.

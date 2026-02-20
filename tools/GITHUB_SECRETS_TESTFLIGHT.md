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

## Enabling upload

In `.github/workflows/ios_testflight.yml`, change the upload step condition:

- from: `if: ${{ false }}`
- to: `if: ${{ true }}`

Then run the workflow manually (Actions → iOS TestFlight → Run workflow).

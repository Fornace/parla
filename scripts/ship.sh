#!/bin/bash
# Ship Parla to App Store Connect.
#
#   scripts/ship.sh              archive, export a distribution IPA, stop there
#   scripts/ship.sh --upload     ... then create the app record if needed and upload
#
# Needs, in this order:
#   1. Xcode with the Fornace team signed in (it is: automatic signing already
#      created the profiles and registered the App Group).
#   2. The App Store Connect API key, for the upload half:
#        source ~/.agent_credentials/apple/appstore-connect.env
#      That file points APP_STORE_CONNECT_KEY_FILEPATH at
#      ~/.agent_credentials/apple/AuthKey_K6R4NZ46Z5.p8, which is NOT on this
#      Mac yet. Without it the archive and export still work.
#
# App record creation cannot be done with the API key alone: App Store Connect
# has no create-app endpoint. It runs through a web session (`asc web apps
# create`), which needs an Apple Account sign-in the first time.

set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="app.fornace.parla"
APP_NAME="Parla"
SKU="PARLA-001"
ARCHIVE="build/Parla.xcarchive"
EXPORT_DIR="build/export"
UPLOAD=0

for arg in "$@"; do
  case "$arg" in
    --upload) UPLOAD=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n== %s\n' "$1"; }

step "Project"
if [ ! -f project.yml ]; then
  echo "run this from a Parla checkout" >&2
  exit 1
fi
xcodegen generate --quiet

step "Archive"
rm -rf "$ARCHIVE"
xcodebuild \
  -project Parla.xcodeproj \
  -scheme Parla \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

step "Export"
rm -rf "$EXPORT_DIR"
cat > build/exportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>2V6YSU4HFB</string>
	<key>destination</key>
	<string>export</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist build/exportOptions.plist \
  -allowProvisioningUpdates

echo
echo "IPA: $EXPORT_DIR/Parla.ipa"

if [ "$UPLOAD" -eq 0 ]; then
  echo "Dry run complete. Add --upload to send it to App Store Connect."
  exit 0
fi

step "Credentials"
if [ -z "${APP_STORE_CONNECT_KEY_FILEPATH:-}" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.agent_credentials/apple/appstore-connect.env"
fi
KEY_FILE="${APP_STORE_CONNECT_KEY_FILEPATH:-$HOME/.agent_credentials/apple/AuthKey_K6R4NZ46Z5.p8}"
export ASC_KEY_ID="${APP_STORE_CONNECT_KEY_ID}"
export ASC_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"
export ASC_PRIVATE_KEY_PATH="$KEY_FILE"

if [ ! -f "$KEY_FILE" ]; then
  cat >&2 <<MISSING
The App Store Connect API key is missing: $KEY_FILE

Download it once from App Store Connect > Users and Access > Integrations >
Team Keys (key id $APP_STORE_CONNECT_KEY_ID) and save it there. It is the only
blocker left for the upload.
MISSING
  exit 1
fi

step "App record"
APP_ID="$(asc apps list --bundle-id "$BUNDLE_ID" --output json 2>/dev/null | python3 -c '
import json,sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
apps = data if isinstance(data, list) else data.get("apps", [])
for app in apps:
    if app.get("bundleId") == "'"$BUNDLE_ID"'":
        print(app.get("id", ""))
        break
' || true)"

if [ -z "$APP_ID" ]; then
  echo "No app record yet. Creating one through the App Store Connect web API."
  asc web apps create --name "$APP_NAME" --bundle-id "$BUNDLE_ID" --sku "$SKU" --primary-locale en-US --platform IOS
  APP_ID="$(asc apps list --bundle-id "$BUNDLE_ID" --output json | python3 -c '
import json,sys
data = json.load(sys.stdin)
apps = data if isinstance(data, list) else data.get("apps", [])
print(next((a["id"] for a in apps if a.get("bundleId") == "'"$BUNDLE_ID"'"), ""))
')"
fi

if [ -z "$APP_ID" ]; then
  echo "Could not find or create the app record for $BUNDLE_ID" >&2
  exit 1
fi
echo "App Store Connect app id: $APP_ID"

step "Upload"
asc builds upload --app "$APP_ID" --ipa "$EXPORT_DIR/Parla.ipa" --wait

step "Done"
asc builds list --app "$APP_ID" --platform IOS --sort -uploadedDate --limit 3

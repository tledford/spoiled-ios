#!/bin/bash
set -euo pipefail

# Builds and installs on the iPhone. Talks to production unless given --local.
#
#   ./build-deploy.sh                Production API
#   ./build-deploy.sh --local        The worker on this Mac, port 8788
#   ./build-deploy.sh --local 9000   The worker on this Mac, another port

DEVICE_ID="00008150-000C69961A42401C"
PROJECT_NAME="Spoiled.xcodeproj"
SCHEME_NAME="Spoiled"
BUNDLE_ID="dev.tomled.Spoiled"

LOCAL_SETTINGS=()
if [[ "${1:-}" == "--local" ]]; then
    PORT="${2:-8788}"
    HOST="$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || true)"
    if [[ -z "$HOST" ]]; then
        echo "Couldn't find this Mac's network address." >&2
        exit 1
    fi
    LOCAL_SETTINGS=("SPOILED_LOCAL_API_HOST=$HOST" "SPOILED_LOCAL_API_PORT=$PORT")
    echo "Using the local worker at $HOST:$PORT"
fi

echo "Building the app..."
# We use a custom derivedDataPath so we know exactly where the .app file ends up
xcodebuild -project $PROJECT_NAME \
           -scheme $SCHEME_NAME \
           -configuration Debug \
           -destination "id=$DEVICE_ID" \
           -derivedDataPath ./build \
           -allowProvisioningUpdates \
           ${LOCAL_SETTINGS[@]+"${LOCAL_SETTINGS[@]}"} \
           build

echo "Installing to iPhone..."
APP_PATH="./build/Build/Products/Debug-iphoneos/${SCHEME_NAME}.app"
xcrun devicectl device install app --device $DEVICE_ID $APP_PATH

echo "Launching app..."
xcrun devicectl device process launch --device $DEVICE_ID $BUNDLE_ID

echo "Deployment complete!"

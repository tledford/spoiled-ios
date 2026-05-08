#!/bin/bash

DEVICE_ID="00008150-000C69961A42401C"
PROJECT_NAME="Spoiled.xcodeproj"
SCHEME_NAME="Spoiled"
BUNDLE_ID="dev.tomled.Spoiled"

echo "Building the app..."
# We use a custom derivedDataPath so we know exactly where the .app file ends up
xcodebuild -project $PROJECT_NAME \
           -scheme $SCHEME_NAME \
           -configuration Debug \
           -destination "id=$DEVICE_ID" \
           -derivedDataPath ./build \
           -allowProvisioningUpdates \
           build

echo "Installing to iPhone..."
APP_PATH="./build/Build/Products/Debug-iphoneos/${SCHEME_NAME}.app"
xcrun devicectl device install app --device $DEVICE_ID $APP_PATH

echo "Launching app..."
xcrun devicectl device process launch --device $DEVICE_ID $BUNDLE_ID

echo "Deployment complete!"
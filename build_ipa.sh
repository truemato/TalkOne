#!/bin/bash

# Navigate to project directory
cd /Users/hundlename/TALKONE_WITHCLAUDE/TalkOne-Project

echo "Starting IPA build process..."

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build iOS app
echo "Building iOS app..."
flutter build ios --release

# Navigate to iOS directory
cd ios

# Archive the app
echo "Creating archive..."
xcodebuild -workspace Runner.xcworkspace \
           -scheme Runner \
           -configuration Release \
           -archivePath ../build/TalkOne.xcarchive \
           archive \
           DEVELOPMENT_TEAM=658363YSD7

# Export IPA
echo "Exporting IPA..."
xcodebuild -exportArchive \
           -archivePath ../build/TalkOne.xcarchive \
           -exportPath ../build/ipa \
           -exportOptionsPlist ExportOptions.plist

# Copy IPA to desktop
echo "Copying IPA to desktop..."
cp ../build/ipa/Runner.ipa ~/Desktop/TalkOne_v0.9.1_iOS_20250703.ipa

echo "IPA build complete! File saved to ~/Desktop/TalkOne_v0.9.1_iOS_20250703.ipa"
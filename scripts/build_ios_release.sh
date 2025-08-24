#!/bin/bash

# CycleAvatar iOS Release Build Script

set -e

echo "🚀 Building CycleAvatar for iOS Release..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: iOS builds require macOS"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Generate code
echo "🔧 Generating code..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Build iOS release
echo "📱 Building iOS release..."
flutter build ios --release --no-codesign

# Build iOS archive (requires Xcode project configuration)
echo "📦 Building iOS archive..."
cd ios
xcodebuild -workspace Runner.xcworkspace \
           -scheme Runner \
           -configuration Release \
           -destination generic/platform=iOS \
           -archivePath build/Runner.xcarchive \
           archive

echo "✅ iOS build completed!"
echo "📁 Archive location: ios/build/Runner.xcarchive"

cd ..

echo "📊 Build completed. Use Xcode Organizer to upload to App Store Connect."
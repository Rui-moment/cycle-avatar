#!/bin/bash

# CycleAvatar Android Release Build Script

set -e

echo "🚀 Building CycleAvatar for Android Release..."

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
    echo "❌ Error: android/key.properties not found!"
    echo "Please copy android/key.properties.template to android/key.properties and configure your signing keys."
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

# Build release APK
echo "📱 Building release APK..."
flutter build apk --release --target-platform android-arm,android-arm64,android-x64

# Build release App Bundle (recommended for Play Store)
echo "📦 Building release App Bundle..."
flutter build appbundle --release

echo "✅ Android build completed!"
echo "📁 APK location: build/app/outputs/flutter-apk/app-release.apk"
echo "📁 App Bundle location: build/app/outputs/bundle/release/app-release.aab"

# Display file sizes
echo "📊 Build sizes:"
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo "APK: $(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)"
fi
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "AAB: $(du -h build/app/outputs/bundle/release/app-release.aab | cut -f1)"
fi
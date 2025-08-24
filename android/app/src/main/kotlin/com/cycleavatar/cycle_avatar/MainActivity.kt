package com.cycleavatar.cycle_avatar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register accessibility plugin
        flutterEngine.plugins.add(AccessibilityPlugin())
        
        // Register voice input plugin
        flutterEngine.plugins.add(VoiceInputPlugin())
    }
}
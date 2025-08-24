package com.cycleavatar.cycle_avatar

import android.content.Context
import android.view.accessibility.AccessibilityManager
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AccessibilityPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cycle_avatar/accessibility")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isScreenReaderEnabled" -> {
                result.success(isScreenReaderEnabled())
            }
            "isHighContrastEnabled" -> {
                result.success(isHighContrastEnabled())
            }
            "isLargeTextEnabled" -> {
                result.success(isLargeTextEnabled())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun isScreenReaderEnabled(): Boolean {
        val accessibilityManager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return accessibilityManager.isEnabled && accessibilityManager.isTouchExplorationEnabled
    }

    private fun isHighContrastEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val accessibilityManager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
            accessibilityManager.isHighTextContrastEnabled
        } else {
            false
        }
    }

    private fun isLargeTextEnabled(): Boolean {
        val configuration = context.resources.configuration
        return configuration.fontScale > 1.0f
    }
}
package com.cycleavatar.cycle_avatar

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.*

class VoiceInputPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null
    
    companion object {
        private const val SPEECH_REQUEST_CODE = 100
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cycle_avatar/voice_input")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isVoiceInputAvailable" -> {
                result.success(isVoiceInputAvailable())
            }
            "startVoiceInput" -> {
                val prompt = call.argument<String>("prompt")
                val language = call.argument<String>("language") ?: "en"
                startVoiceInput(prompt, language, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun isVoiceInputAvailable(): Boolean {
        return activity?.let { 
            SpeechRecognizer.isRecognitionAvailable(it)
        } ?: false
    }

    private fun startVoiceInput(prompt: String?, language: String, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        if (!isVoiceInputAvailable()) {
            result.error("NOT_AVAILABLE", "Voice input not available", null)
            return
        }

        pendingResult = result

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PROMPT, prompt ?: "Speak now")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        try {
            currentActivity.startActivityForResult(intent, SPEECH_REQUEST_CODE)
        } catch (e: Exception) {
            pendingResult = null
            result.error("SPEECH_ERROR", "Failed to start speech recognition", e.message)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == SPEECH_REQUEST_CODE) {
            val result = pendingResult
            pendingResult = null
            
            if (result != null) {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                    if (results != null && results.isNotEmpty()) {
                        result.success(results[0])
                    } else {
                        result.success(null)
                    }
                } else {
                    result.success(null)
                }
            }
            return true
        }
        return false
    }
}
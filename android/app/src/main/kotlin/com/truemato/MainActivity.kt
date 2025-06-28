package com.truemato

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.truemato.talkone.AndroidSpeechRecognizer
import com.google.firebase.Firebase
import com.google.firebase.vertexai.vertexAI

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.talkone.app/ai_filter"
    private val SPEECH_CHANNEL = "android_speech_recognizer"
    
    private lateinit var androidSpeechRecognizer: AndroidSpeechRecognizer
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Android音声認識チャンネルの設定
        val speechMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        androidSpeechRecognizer = AndroidSpeechRecognizer(this, speechMethodChannel)
        
        // Firebase AI Logic SDK でVertex AIバックエンドを初期化
        try {
            val model = Firebase.vertexAI.generativeModel("gemini-2.0-flash-lite-001")
            // Vertex AI バックエンドの初期化完了
            println("Android Firebase AI with Vertex AI backend initialized successfully")
        } catch (e: Exception) {
            // Firebase AI Logic初期化エラーをログに出力
            println("Firebase AI Logic initialization error: ${e.message}")
        }
        
        // Set up method channel (temporary implementation without AI filter)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeAIFilter" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                "enableAIFilter" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                "setFilterParams" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                "releaseAIFilter" -> {
                    // Temporary stub implementation
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

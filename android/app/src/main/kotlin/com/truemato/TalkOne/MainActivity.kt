package com.truemato.TalkOne

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.content.Intent
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.Manifest

class MainActivity: FlutterActivity() {
    private val SPEECH_CHANNEL = "android_speech_recognizer"
    private var speechRecognizer: SpeechRecognizer? = null
    private val PERMISSION_REQUEST_CODE = 1001
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Android音声認識チャンネルの設定
        val speechMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        
        speechMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    if (checkPermissions()) {
                        val success = initializeSpeechRecognizer()
                        result.success(success)
                    } else {
                        requestPermissions()
                        result.success(false)
                    }
                }
                "startListening" -> {
                    if (checkPermissions()) {
                        startListening()
                        result.success(null)
                    } else {
                        result.error("PERMISSION_DENIED", "音声録音権限が必要です", null)
                    }
                }
                "stopListening" -> {
                    stopListening()
                    result.success(null)
                }
                "dispose" -> {
                    disposeSpeechRecognizer()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun initializeSpeechRecognizer(): Boolean {
        return try {
            if (SpeechRecognizer.isRecognitionAvailable(this)) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    
                    override fun onError(error: Int) {
                        val errorMessage = when (error) {
                            SpeechRecognizer.ERROR_AUDIO -> "音声録音エラーです。マイクを確認してください。"
                            SpeechRecognizer.ERROR_CLIENT -> "音声認識でエラーが発生しました。"
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "音声録音の権限が必要です。"
                            SpeechRecognizer.ERROR_NETWORK -> "ネットワーク接続エラーです。"
                            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ネットワークがタイムアウトしました。"
                            SpeechRecognizer.ERROR_NO_MATCH -> "音声を認識できませんでした。もう一度お試しください。"
                            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "音声認識サービスが利用中です。しばらく待ってからお試しください。"
                            SpeechRecognizer.ERROR_SERVER -> "音声認識サーバーでエラーが発生しました。"
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "音声が検出されませんでした。もう一度お話しください。"
                            else -> "音声認識で予期しないエラーが発生しました。"
                        }
                        
                        val speechMethodChannel = MethodChannel(
                            flutterEngine?.dartExecutor?.binaryMessenger!!, 
                            SPEECH_CHANNEL
                        )
                        speechMethodChannel.invokeMethod("onError", mapOf(
                            "errorCode" to error,
                            "errorMessage" to errorMessage
                        ))
                    }
                    
                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (matches != null && matches.isNotEmpty()) {
                            val speechMethodChannel = MethodChannel(
                                flutterEngine?.dartExecutor?.binaryMessenger!!, 
                                SPEECH_CHANNEL
                            )
                            speechMethodChannel.invokeMethod("onResults", mapOf(
                                "results" to matches
                            ))
                        }
                    }
                    
                    override fun onPartialResults(partialResults: Bundle?) {}
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
                true
            } else {
                false
            }
        } catch (e: Exception) {
            println("SpeechRecognizer initialization error: ${e.message}")
            false
        }
    }
    
    private fun startListening() {
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ja-JP")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            println("SpeechRecognizer start error: ${e.message}")
        }
    }
    
    private fun stopListening() {
        try {
            speechRecognizer?.stopListening()
        } catch (e: Exception) {
            println("SpeechRecognizer stop error: ${e.message}")
        }
    }
    
    private fun disposeSpeechRecognizer() {
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (e: Exception) {
            println("SpeechRecognizer dispose error: ${e.message}")
        }
    }
    
    private fun checkPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun requestPermissions() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_CODE
        )
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                println("✅ 音声録音権限が許可されました")
                // 権限が許可された後、初期化を再試行
                val speechMethodChannel = MethodChannel(
                    flutterEngine?.dartExecutor?.binaryMessenger!!, 
                    SPEECH_CHANNEL
                )
                speechMethodChannel.invokeMethod("onPermissionGranted", null)
            } else {
                println("❌ 音声録音権限が拒否されました")
                val speechMethodChannel = MethodChannel(
                    flutterEngine?.dartExecutor?.binaryMessenger!!, 
                    SPEECH_CHANNEL
                )
                speechMethodChannel.invokeMethod("onPermissionDenied", null)
            }
        }
    }
}
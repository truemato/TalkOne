package com.truemato.talkone

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

class AndroidSpeechRecognizer(private val context: Context, private val channel: MethodChannel) : MethodCallHandler {

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                initialize(result)
            }
            "startListening" -> {
                val locale = call.argument<String>("locale") ?: "ja-JP"
                val maxResults = call.argument<Int>("maxResults") ?: 1
                val partialResults = call.argument<Boolean>("partialResults") ?: true
                startListening(locale, maxResults, partialResults, result)
            }
            "stopListening" -> {
                stopListening(result)
            }
            "dispose" -> {
                dispose(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initialize(result: Result) {
        try {
            if (SpeechRecognizer.isRecognitionAvailable(context)) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
                speechRecognizer?.setRecognitionListener(createRecognitionListener())
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("INITIALIZATION_FAILED", "音声認識の初期化に失敗しました: ${e.message}", null)
        }
    }

    private fun startListening(locale: String, maxResults: Int, partialResults: Boolean, result: Result) {
        try {
            if (isListening) {
                stopListening(null)
            }

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, maxResults)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, partialResults)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000L)
            }

            speechRecognizer?.startListening(intent)
            isListening = true
            result.success(true)
        } catch (e: Exception) {
            result.error("START_LISTENING_FAILED", "音声認識の開始に失敗しました: ${e.message}", null)
        }
    }

    private fun stopListening(result: Result?) {
        try {
            speechRecognizer?.stopListening()
            isListening = false
            result?.success(true)
        } catch (e: Exception) {
            result?.error("STOP_LISTENING_FAILED", "音声認識の停止に失敗しました: ${e.message}", null)
        }
    }

    private fun dispose(result: Result) {
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
            isListening = false
            result.success(true)
        } catch (e: Exception) {
            result.error("DISPOSE_FAILED", "音声認識の解放に失敗しました: ${e.message}", null)
        }
    }

    private fun createRecognitionListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                channel.invokeMethod("onReadyForSpeech", null)
            }

            override fun onBeginningOfSpeech() {
                channel.invokeMethod("onBeginningOfSpeech", null)
            }

            override fun onRmsChanged(rmsdB: Float) {
                // 音声レベル変化（必要に応じて）
            }

            override fun onBufferReceived(buffer: ByteArray?) {
                // 音声バッファ（通常は使用しない）
            }

            override fun onEndOfSpeech() {
                channel.invokeMethod("onEndOfSpeech", null)
                isListening = false
            }

            override fun onError(error: Int) {
                val errorMessage = getErrorMessage(error)
                val errorData = mapOf(
                    "errorCode" to error,
                    "errorMessage" to errorMessage
                )
                channel.invokeMethod("onError", errorData)
                isListening = false
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (matches != null && matches.isNotEmpty()) {
                    val resultData = mapOf("results" to matches)
                    channel.invokeMethod("onResults", resultData)
                }
                isListening = false
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (matches != null && matches.isNotEmpty()) {
                    val resultData = mapOf("results" to matches)
                    channel.invokeMethod("onPartialResults", resultData)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {
                // イベント処理（必要に応じて）
            }
        }
    }

    private fun getErrorMessage(errorCode: Int): String {
        return when (errorCode) {
            SpeechRecognizer.ERROR_AUDIO -> "音声エラー"
            SpeechRecognizer.ERROR_CLIENT -> "クライアントエラー"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "権限不足"
            SpeechRecognizer.ERROR_NETWORK -> "ネットワークエラー"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ネットワークタイムアウト"
            SpeechRecognizer.ERROR_NO_MATCH -> "音声が認識されませんでした"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "音声認識エンジンがビジー状態です"
            SpeechRecognizer.ERROR_SERVER -> "サーバーエラー"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "音声入力タイムアウト"
            else -> "不明なエラー (コード: $errorCode)"
        }
    }
}
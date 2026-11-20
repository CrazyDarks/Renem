package com.languagema.languagema

import android.annotation.SuppressLint
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "com.languagema/external_launcher"

    private val sampleRate = 16000
    @Volatile
    private var isCapturingVoice = false
    private var audioRecord: AudioRecord? = null
    private var activeTrack: AudioTrack? = null
    private var activeMediaPlayer: MediaPlayer? = null
    private var lastVoiceBytes: ByteArray = ByteArray(0)
    private val recordedSlots = HashMap<String, ByteArray>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableImmersiveStickyNavigation()
    }

    override fun onResume() {
        super.onResume()
        enableImmersiveStickyNavigation()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            enableImmersiveStickyNavigation()
        }
    }

    private fun enableImmersiveStickyNavigation() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                )
        }
    }

    @SuppressLint("MissingPermission")
    private fun startVoiceCapture(slotKey: String) {
        stopVoiceCapture(slotKey)
        try {
            val minBuf = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuf <= 0) return
            val recorder = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuf * 2
            )
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                recorder.release()
                return
            }
            audioRecord = recorder
            isCapturingVoice = true
            recorder.startRecording()

            thread(start = true, name = "RemanVoiceCapture") {
                val out = ByteArrayOutputStream()
                val buf = ByteArray(2048)
                val maxBytes = sampleRate * 2 * 20 // max 20 seconds
                try {
                    while (isCapturingVoice && out.size() < maxBytes) {
                        val read = recorder.read(buf, 0, buf.size)
                        if (read > 0) {
                            out.write(buf, 0, read)
                        } else {
                            break
                        }
                    }
                } catch (_: Exception) {
                } finally {
                    try {
                        recorder.stop()
                    } catch (_: Exception) {
                    }
                    try {
                        recorder.release()
                    } catch (_: Exception) {
                    }
                    val captured = out.toByteArray()
                    if (captured.isNotEmpty()) {
                        synchronized(recordedSlots) {
                            lastVoiceBytes = captured
                            recordedSlots[slotKey] = captured
                        }
                    }
                }
            }
        } catch (_: Exception) {
            isCapturingVoice = false
        }
    }

    private fun stopVoiceCapture(slotKey: String): Boolean {
        isCapturingVoice = false
        audioRecord = null
        // Brief pause to let capture thread flush buffer
        try {
            Thread.sleep(60)
        } catch (_: Exception) {
        }
        synchronized(recordedSlots) {
            if (lastVoiceBytes.isNotEmpty() && !recordedSlots.containsKey(slotKey)) {
                recordedSlots[slotKey] = lastVoiceBytes
            }
            return (recordedSlots[slotKey]?.isNotEmpty() == true) || lastVoiceBytes.isNotEmpty()
        }
    }

    private fun hasVoiceRecording(slotKey: String): Boolean {
        synchronized(recordedSlots) {
            val bytes = recordedSlots[slotKey] ?: lastVoiceBytes
            return bytes.size > 1600
        }
    }

    private fun playVoiceCapture(slotKey: String): Boolean {
        val data: ByteArray
        synchronized(recordedSlots) {
            data = recordedSlots[slotKey] ?: lastVoiceBytes
        }
        if (data.size <= 1600) return false

        stopPlayingVoice()

        thread(start = true, name = "RemanVoicePlayback") {
            try {
                val track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(data.size.coerceAtLeast(4096))
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                activeTrack = track
                track.write(data, 0, data.size)
                track.play()
                val durationMs = ((data.size.toLong() * 1000L) / (sampleRate * 2)).coerceIn(300L, 20000L)
                Thread.sleep(durationMs + 150L)
                track.stop()
                track.release()
            } catch (_: Exception) {
            }
        }
        return true
    }

    private fun stopPlayingVoice() {
        try {
            activeTrack?.stop()
            activeTrack?.release()
        } catch (_: Exception) {
        }
        activeTrack = null
    }

    private fun stopEncodedAudio() {
        try {
            activeMediaPlayer?.stop()
            activeMediaPlayer?.release()
        } catch (_: Exception) {
        }
        activeMediaPlayer = null
    }

    private fun playEncodedAudio(bytes: ByteArray): Boolean {
        if (bytes.isEmpty()) return false
        stopEncodedAudio()
        return try {
            val tmpFile = File(cacheDir, "reman_ai_tts_${System.currentTimeMillis()}.mp3")
            tmpFile.writeBytes(bytes)
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                setDataSource(tmpFile.absolutePath)
                setOnCompletionListener { mp ->
                    try {
                        mp.release()
                    } catch (_: Exception) {
                    }
                    if (activeMediaPlayer === mp) {
                        activeMediaPlayer = null
                    }
                    tmpFile.delete()
                }
                prepare()
                start()
            }
            activeMediaPlayer = player
            true
        } catch (_: Exception) {
            stopEncodedAudio()
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openExternalUrl" -> {
                        val url = call.argument<String>("url")
                        if (!url.isNullOrBlank()) {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("LAUNCH_ERROR", e.localizedMessage, null)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "startVoiceCapture" -> {
                        val slot = call.argument<String>("slot") ?: "default"
                        startVoiceCapture(slot)
                        result.success(true)
                    }
                    "stopVoiceCapture" -> {
                        val slot = call.argument<String>("slot") ?: "default"
                        val hasAudio = stopVoiceCapture(slot)
                        result.success(hasAudio)
                    }
                    "playVoiceCapture" -> {
                        val slot = call.argument<String>("slot") ?: "default"
                        val played = playVoiceCapture(slot)
                        result.success(played)
                    }
                    "hasVoiceRecording" -> {
                        val slot = call.argument<String>("slot") ?: "default"
                        result.success(hasVoiceRecording(slot))
                    }
                    "playEncodedAudio" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes != null && bytes.isNotEmpty()) {
                            result.success(playEncodedAudio(bytes))
                        } else {
                            result.success(false)
                        }
                    }
                    "stopEncodedAudio" -> {
                        stopEncodedAudio()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

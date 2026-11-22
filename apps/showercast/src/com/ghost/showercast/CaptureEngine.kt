package com.ghost.showercast

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import com.opus.airvia.LogBus
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * The generic, sink-agnostic capture core. Opens the panel's post-mix submix
 * (REMOTE_SUBMIX — DRM included, granted by platform-signing), applies gain + a soft
 * limiter, and feeds [ring]. It knows nothing about where the audio goes; sinks drain
 * [ring] independently. Only started when at least one non-passthrough sink is active.
 */
class CaptureEngine(private val gain: Float) {

    companion object {
        const val RATE = 48000            // native submix rate; served as-is (no resample)
        const val CH = AudioFormat.CHANNEL_IN_STEREO
        const val BYTES_PER_SEC = RATE * 2 * 2   // 48000 * ch2 * s16
        /** 4 s of audio in the ring so a slow/reconnecting consumer stays live. */
        private const val RING_BYTES = BYTES_PER_SEC * 4
    }

    val ring = RingBuffer(RING_BYTES)
    private var record: AudioRecord? = null
    private var capThread: Thread? = null
    private val running = AtomicBoolean(false)

    fun start() {
        if (!running.getAndSet(true)) return
        val fmt = AudioFormat.Builder()
            .setSampleRate(RATE)
            .setChannelMask(CH)
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .build()
        val minBuf = AudioRecord.getMinBufferSize(RATE, CH, AudioFormat.ENCODING_PCM_16BIT)
        val bufSize = maxOf(minBuf, RATE * 4)
        try {
            record = AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.REMOTE_SUBMIX)
                .setAudioFormat(fmt)
                .setBufferSizeInBytes(bufSize)
                .build()
            record!!.startRecording()
            LogBus.log("[cap] REMOTE_SUBMIX open ok bufSize=$bufSize gain=${gain}x")
        } catch (e: Exception) {
            LogBus.log("[cap] REMOTE_SUBMIX FAILED: $e")
            running.set(false)
            return
        }

        capThread = thread(name = "showercap") {
            val raw = ShortArray(RATE / 20)         // 25 ms batch -> smooth ring top-up (no 0.5s lumps)
            val out = ByteArray((RATE / 20) * 2)    // interleaved bytes
            var winPeak = 0
            var winStart = System.currentTimeMillis()
            while (running.get()) {
                val n = try { record?.read(raw, 0, raw.size) ?: -1 } catch (_: Exception) { -1 }
                if (n < 0) { try { Thread.sleep(20) } catch (_: Exception) {}; continue }
                val frames = n / 2
                for (f in 0 until frames) {
                    var l = raw[f * 2].toInt()
                    var r = raw[f * 2 + 1].toInt()
                    if (gain != 1.0f) { l = softClip(l * gain); r = softClip(r * gain) }
                    val o = f * 4
                    out[o] = (l and 0xFF).toByte(); out[o + 1] = ((l shr 8) and 0xFF).toByte()
                    out[o + 2] = (r and 0xFF).toByte(); out[o + 3] = ((r shr 8) and 0xFF).toByte()
                    var a = l; if (a < 0) a = -a; if (a > winPeak) winPeak = a
                    a = r; if (a < 0) a = -a; if (a > winPeak) winPeak = a
                }
                ring.write(out, 0, frames * 4)
                val now = System.currentTimeMillis()
                if (now - winStart >= 5000) {
                    LogBus.log("[cap] peak=$winPeak (0=silent)")
                    winPeak = 0; winStart = now
                }
            }
        }
    }

    fun stop() {
        running.set(false)
        capThread?.interrupt()
        try { record?.stop(); record?.release() } catch (_: Exception) {}
        record = null
    }

    private fun clamp(v: Int): Int = if (v > 32767) 32767 else if (v < -32768) -32768 else v

    /** Soft limiter: gentle tanh knee so loud passages compress instead of hard-clipping. */
    private fun softClip(v: Float): Int {
        val y = kotlin.math.tanh(v / 32768f * 1.5f) * 32767f
        return y.toInt().coerceIn(-32768, 32767)
    }
}

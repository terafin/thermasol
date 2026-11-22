package com.ghost.showercast

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import com.opus.airvia.LogBus
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * Thin orchestrator. Resolves which sink(s) are selected, runs the generic capture
 * core only when a real (non-passthrough) sink needs audio, and hands the shared ring
 * to each selected sink.
 *
 * Selection model (persisted in SharedPreferences, overridable per-start via intent
 * extras):
 *   "local" (default) -> no capture, no added output. The panel plays through its own
 *                        amp exactly as stock. This is what every fleet unit gets when
 *                        the option is left off — zero footprint.
 *   "sonos"           -> capture + SonosSink. Local still plays (REMOTE_SUBMIX is a tap);
 *                        the Sonos amp additionally pulls the stream over UPnP/WAV.
 *
 * Nothing here is hardcoded to Sonos: sinks are pluggable and selected at runtime.
 */
class ShowerCastService : Service() {

    companion object {
        const val TAG = "ShowerCast"
        const val NOTIF_ID = 42
        const val DEFAULT_HOST = "10.0.1.179"   // Atrium (test)
        const val WAVE_PORT = 8090
        const val PREFS = "showercast"
        const val KEY_SEL = "sink_sel"          // "local" | "sonos"
        const val KEY_HOST = "sonos_host"
        const val KEY_GAIN = "sonos_gain"
        const val DEF_GAIN = 24.0f              // submix runs hot-low; 24x lands near full scale
    }

    private var engine: CaptureEngine? = null
    private val sinks = mutableListOf<AudioSink>()
    private val running = AtomicBoolean(false)
    private var curMode = "local"
    private var curHost = DEFAULT_HOST

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val p = prefs()
        val sel = if (intent?.hasExtra("sinks") == true) intent.getStringExtra("sinks")!!
                  else (p.getString(KEY_SEL, "local") ?: "local")
        val host = if (intent?.hasExtra("host") == true) intent.getStringExtra("host")!!.ifEmpty { DEFAULT_HOST }
                   else (p.getString(KEY_HOST, DEFAULT_HOST) ?: DEFAULT_HOST)
        val gain = if (intent?.hasExtra("gain") == true) intent.getFloatExtra("gain", DEF_GAIN)
                   else p.getFloat(KEY_GAIN, DEF_GAIN)

        curMode = sel; curHost = host
        startForeground(NOTIF_ID, buildNotification(sel, host))

        if (!running.getAndSet(true)) {
            thread(name = "shower-start") { startPipeline(sel, host, gain) }
        }
        return START_STICKY
    }

    private fun startPipeline(sel: String, host: String, gain: Float) {
        sinks.clear()
        for (id in sel.split(',').map { it.trim() }.filter { it.isNotEmpty() }) {
            when (id) {
                "sonos" -> sinks.add(SonosSink(host, gain))
                "local" -> sinks.add(LocalPassthroughSink())
                else -> LogBus.log("[cfg] unknown sink '$id' (ignored)")
            }
        }
        if (sinks.isEmpty()) sinks.add(LocalPassthroughSink())

        val needsCapture = sinks.any { it !is LocalPassthroughSink }
        if (needsCapture) {
            val e = CaptureEngine(gain)
            e.start()
            engine = e
            for (s in sinks) s.start(e.ring)
        } else {
            for (s in sinks) s.start(RingBuffer(64))
            LogBus.log("[cfg] local-only: no capture, panel plays via its own amp (stock behavior)")
        }
        LogBus.log("[cfg] active sinks: ${sinks.joinToString(", ") { it.id }} host=$host gain=${gain}x")
    }

    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun buildNotification(sel: String, host: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel("showercast", "Shower Cast", NotificationManager.IMPORTANCE_LOW))
        }
        val pi = PendingIntent.getActivity(this, 0, Intent(this, BootActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val text = if (sel.contains("sonos")) "Routing to Sonos $host (UPnP :$WAVE_PORT)"
                   else "Local amp only (no added output)"
        return Notification.Builder(this, "showercast")
            .setContentTitle("Shower Cast")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        running.set(false)
        for (s in sinks) try { s.stop() } catch (_: Exception) {}
        engine?.stop()
        super.onDestroy()
    }
}

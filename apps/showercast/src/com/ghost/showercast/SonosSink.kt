package com.ghost.showercast

import android.media.AudioFormat
import com.opus.airvia.LogBus
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.NetworkInterface
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

/**
 * The Sonos sink: serves the captured PCM as an endless chunked WAV on [WAVE_PORT] and
 * tells the amp to pull it via UPnP SetAVTransportURI + Play (fire-once; re-fires only if
 * the amp drops off our server and stays gone >15s). No AirPlay, no PTP. This is the
 * "shower" output — a selectable extra destination, not the default.
 */
class SonosSink(
    private val host: String,
    private val gain: Float
) : AudioSink {

    companion object {
        const val WAVE_PORT = 8090
        const val SONOS_CTRL = 1400
        const val AVT = "urn:schemas-upnp-org:service:AVTransport:1"
        const val RATE = 48000
        const val BYTES_PER_SEC = RATE * 2 * 2   // 48000 * ch2 * s16
    }

    override val id = "sonos"
    override val label = "Sonos (UPnP)"

    private var ring: RingBuffer? = null
    private var server: ServerSocket? = null
    private var serverThread: Thread? = null
    private var ctrlThread: Thread? = null
    private val running = AtomicBoolean(false)
    private val clients = AtomicInteger(0)

    override fun start(ring: RingBuffer) {
        this.ring = ring
        running.set(true)
        LogBus.log("[sink] sonos start host=$host wavPort=$WAVE_PORT gain=${gain}x")

        try {
            server = ServerSocket()
            server!!.bind(InetSocketAddress(WAVE_PORT), 64)
            LogBus.log("[sink] sonos WAV server listening on :$WAVE_PORT")
        } catch (e: Exception) {
            LogBus.log("[sink] sonos WAV bind FAILED: $e")
        }

        serverThread = thread(name = "wavserve") {
            val ss = server ?: return@thread
            while (running.get()) {
                val sock = try { ss.accept() } catch (e: Exception) {
                    if (running.get()) { try { Thread.sleep(100) } catch (_: Exception) {} }; continue
                }
                thread(name = "wavclient") { handleClient(sock) }
            }
        }

        // Fire-once transport control: point the amp at us once; it holds the URI as a
        // persistent source and keeps pulling. Re-fire only after a real disconnect.
        ctrlThread = thread(name = "sonosctrl") {
            val url = "http://${localIp()}:$WAVE_PORT/live.wav"
            fun fire() {
                try {
                    soap("SetAVTransportURI",
                        "<InstanceID>0</InstanceID><CurrentURI>${esc(url)}</CurrentURI>" +
                            "<CurrentURIMetaData>${esc(didl(url))}</CurrentURIMetaData>",
                        AVT, tmo = 4000)
                    Thread.sleep(250)
                    try { soap("Play", "<InstanceID>0</InstanceID><Speed>1</Speed>", AVT, tmo = 3000) }
                    catch (_: Exception) { /* Play may hold until buffered; the pull proves it's live */ }
                    LogBus.log("[ctrl] fired SetAVTransportURI+Play ($url)")
                } catch (e: Exception) { LogBus.log("[ctrl] fire err ${e.message}") }
            }
            fire()
            var goneSince = 0L
            while (running.get()) {
                try { Thread.sleep(5000) } catch (_: Exception) { break }
                if (clients.get() == 0) {
                    if (goneSince == 0L) goneSince = System.currentTimeMillis()
                    if (System.currentTimeMillis() - goneSince > 15000) {
                        LogBus.log("[ctrl] no client 15s -> re-firing")
                        fire(); goneSince = 0L
                    }
                } else goneSince = 0L
            }
        }
        LogBus.log("[sink] sonos pipeline up: ring->:$WAVE_PORT->UPnP($host)")
    }

    override fun stop() {
        running.set(false)
        serverThread?.interrupt(); ctrlThread?.interrupt()
        try { server?.close() } catch (_: Exception) {}
        LogBus.log("[sink] sonos stopped")
    }

    // ---- per-client streaming --------------------------------------------

    private fun handleClient(sock: Socket) {
        var counted = false
        try {
            sock.soTimeout = 15000
            val os = sock.getOutputStream()
            val ins = sock.getInputStream()
            val reqLine = readLine(ins) ?: return
            LogBus.log("[client] ${reqLine.take(60)} from ${sock.inetAddress}")
            while (true) { val l = readLine(ins); if (l == null || l.isEmpty()) break }
            if (!reqLine.startsWith("GET")) { os.close(); return }
            val head = httpHead()
            fun csend(data: ByteArray, off: Int, len: Int) {
                if (len <= 0) return
                os.write((len.toString(16) + "\r\n").toByteArray(Charsets.US_ASCII))
                os.write(data, off, len)
                os.write("\r\n".toByteArray(Charsets.US_ASCII))
            }
            val riff = headerBytes()
            os.write(head); os.flush()
            csend(riff, 0, riff.size); os.flush()
            clients.incrementAndGet()
            counted = true
            val r = ring
            val tone = gain < 0f
            val myPos = arrayOf(r?.pos() ?: 0L)
            var sent = 0L
            val tickNs = 20_000_000L                       // 20 ms
            val bytesPerTick = RATE * 2 * 2 * 20 / 1000    // 3840 for 48k/stereo/s16
            val buf = ByteArray(bytesPerTick)
            var phase = 0.0
            fun fillTone() {
                for (i in 0 until bytesPerTick step 4) {
                    val v = (12000 * kotlin.math.sin(phase)).toInt()
                    phase += 2.0 * Math.PI * 440.0 / RATE
                    if (phase > 2.0 * Math.PI) phase -= 2.0 * Math.PI
                    buf[i] = (v and 0xFF).toByte(); buf[i+1] = ((v shr 8) and 0xFF).toByte()
                    buf[i+2] = (v and 0xFF).toByte(); buf[i+3] = ((v shr 8) and 0xFF).toByte()
                }
            }
            var next = System.nanoTime() + tickNs
            while (running.get() && !sock.isClosed) {
                if (tone) {
                    fillTone()
                } else {
                    java.util.Arrays.fill(buf, 0.toByte())
                    if (r != null) {
                        val avail = r.available(myPos[0])
                        if (avail > bytesPerTick * 8L) {
                            myPos[0] += (avail - bytesPerTick).toInt()   // far behind -> stay ~1 tick off head
                        }
                        val got = r.read(myPos[0], buf, bytesPerTick)
                        if (got > 0) myPos[0] += got                     // shortfall stays zero-padded
                    }
                }
                csend(buf, 0, bytesPerTick); sent += bytesPerTick
                // Pace to an absolute wall-clock deadline: sleep most of the gap, then spin
                // to the exact instant so sleep-resolution jitter can't accumulate into
                // underruns. Always emits one tick per 20ms.
                next += tickNs
                val wait = next - System.nanoTime()
                if (wait > 5_000_000L) try { Thread.sleep((wait - 5_000_000L) / 1_000_000L) } catch (_: Exception) {}
                while (System.nanoTime() < next) { /* spin to deadline */ }
                if (next < System.nanoTime() - tickNs) next = System.nanoTime() + tickNs  // reset if badly behind
            }
            LogBus.log("[client] closed after ${sent / 1024} KB")
        } catch (e: Exception) {
            LogBus.log("[client] dropped: ${e.message}")
        } finally {
            if (counted) clients.decrementAndGet()
            try { sock.close() } catch (_: Exception) {}
        }
    }

    private fun readLine(ins: java.io.InputStream): String? {
        val sb = StringBuilder()
        while (true) {
            val b = ins.read()
            if (b < 0) return if (sb.isEmpty()) null else sb.toString()
            if (b == '\n'.code) break
            if (b != '\r'.code) sb.append(b.toChar())
        }
        return sb.toString()
    }

    private fun headerBytes(): ByteArray {
        val o = java.io.ByteArrayOutputStream()
        fun wstr(s: String) { for (c in s) o.write(c.code) }
        fun wint(v: Int) { o.write(v and 0xFF); o.write((v shr 8) and 0xFF); o.write((v shr 16) and 0xFF); o.write((v shr 24) and 0xFF) }
        fun wshort(v: Int) { o.write(v and 0xFF); o.write((v shr 8) and 0xFF) }
        wstr("RIFF"); wint(0x7FFFFFFF)
        wstr("WAVE"); wstr("fmt ")
        wint(16); wshort(1); wshort(2); wint(RATE); wint(BYTES_PER_SEC); wshort(4); wshort(16)
        wstr("data"); wint(0x7FFFFFFF)
        return o.toByteArray()
    }

    // ---- UPnP control -----------------------------------------------------

    private fun localIp(): String {
        try {
            for (ni in NetworkInterface.getNetworkInterfaces()) {
                for (a in ni.inetAddresses) {
                    if (a is Inet4Address && !a.isLoopbackAddress && a.hostAddress?.startsWith("10.0.") == true)
                        return a.hostAddress
                }
            }
        } catch (_: Exception) {}
        return "10.0.1.32"
    }

    private fun soap(action: String, body: String, service: String, tmo: Int = 8): String {
        val env = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
            "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" " +
            "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" +
            "<s:Body><u:$action xmlns:u=\"$service\">$body</u:$action></s:Body></s:Envelope>"
        val conn = (java.net.URL("http://$host:$SONOS_CTRL/MediaRenderer/AVTransport/Control").openConnection()
            as java.net.HttpURLConnection).apply {
            requestMethod = "POST"
            setRequestProperty("Content-Type", "text/xml; charset=\"utf-8\"")
            setRequestProperty("SOAPACTION", "\"$service#$action\"")
            connectTimeout = 4000; readTimeout = tmo; doOutput = true
        }
        conn.outputStream.use { it.write(env.toByteArray(Charsets.UTF_8)) }
        val code = conn.responseCode
        val text = (if (code in 200..299) conn.inputStream else conn.errorStream)?.bufferedReader()?.use { it.readText() } ?: ""
        conn.disconnect()
        if (code !in 200..299) throw Exception("$action HTTP $code ${text.take(120)}")
        return text
    }

    /** XML-escape for embedding in the SOAP envelope. */
    private fun esc(s: String): String = s
        .replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        .replace("\"", "&quot;").replace("'", "&apos;")

    /** DIDL-Lite metadata so the renderer commits to the stream (Sunus "wav-length" profile). */
    private fun didl(url: String): String =
        "<DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\" " +
            "xmlns:dc=\"http://purl.org/dc/elements/1.1/\" " +
            "xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\">" +
            "<item id=\"0\" parentID=\"-1\" restricted=\"1\">" +
            "<dc:title>ShowerCast</dc:title>" +
            "<upnp:class>object.item.audioItem.musicTrack</upnp:class>" +
            "<res protocolInfo=\"http-get:*:audio/wav:*\">$url</res>" +
            "</item></DIDL-Lite>"

    /** HTTP response head: chunked transfer so an endless stream never needs a length. */
    private fun httpHead(): ByteArray {
        val h = "HTTP/1.1 200 OK\r\n" +
            "Content-Type: audio/wav\r\n" +
            "Transfer-Encoding: chunked\r\n" +
            "Cache-Control: no-cache, no-store\r\n" +
            "Pragma: no-cache\r\n" +
            "Connection: close\r\n\r\n"
        return h.toByteArray(Charsets.US_ASCII)
    }
}

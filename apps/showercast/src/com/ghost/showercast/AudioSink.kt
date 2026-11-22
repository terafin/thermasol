package com.ghost.showercast

/**
 * A pluggable destination for the captured post-mix PCM. The capture engine is
 * sink-agnostic: it fills [ring] and each active sink drains it however it likes.
 *
 * Local audio always plays through the panel's own amp via normal Android routing
 * (REMOTE_SUBMIX is a tap, not a hijack) — so the "local" case needs no sink at all.
 * Sinks exist to ADD an extra output (today: Sonos over UPnP/WAV). Nothing here is
 * hardcoded to any particular sink; the service starts whichever ones are selected.
 */
interface AudioSink {
    /** Stable id used in config/logs, e.g. "sonos". */
    val id: String
    /** Human label shown in the selector, e.g. "Sonos (UPnP)". */
    val label: String

    /** Begin delivering. Called once after the capture engine is live. */
    fun start(ring: RingBuffer)
    /** Stop delivering and release threads/sockets. Idempotent. */
    fun stop()
}

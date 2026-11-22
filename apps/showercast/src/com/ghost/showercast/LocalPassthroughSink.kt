package com.ghost.showercast

import com.opus.airvia.LogBus

/**
 * The default sink: do nothing extra. Audio already reaches the panel's own amp via
 * normal Android routing, so "local" is simply the absence of any added output.
 *
 * This is what every fleet panel gets when the Sonos option is left off — byte-for-byte
 * today's behavior, no new threads, no sockets, no network. Selecting only this sink is
 * equivalent to not running an external sink at all.
 */
class LocalPassthroughSink : AudioSink {
    override val id = "local"
    override val label = "Local amp (default)"

    override fun start(ring: RingBuffer) {
        LogBus.log("[sink] local passthrough active (no added output)")
    }

    override fun stop() {
        LogBus.log("[sink] local passthrough stopped")
    }
}

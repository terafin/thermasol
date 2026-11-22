package com.ghost.showercast

/**
 * Single-producer / multi-consumer live ring of interleaved s16 PCM bytes. The capture
 * engine is the only writer; each sink's client(s) read independently from their own
 * cursor, so one slow consumer can't stall the others or the producer.
 */
class RingBuffer(val capacity: Int) {
    private val buf = ByteArray(capacity)
    private val lock = Any()
    @Volatile private var wp = 0L
    fun write(data: ByteArray, off: Int, len: Int) {
        synchronized(lock) { for (i in 0 until len) { buf[(wp % capacity).toInt()] = data[off + i]; wp++ } }
    }
    fun pos(): Long = wp
    fun available(from: Long): Long = (wp - from).coerceAtLeast(0)
    fun read(from: Long, out: ByteArray, maxLen: Int): Int {
        synchronized(lock) {
            val avail = ((wp - from).toInt()).coerceAtMost(out.size).coerceAtMost(maxLen)
            if (avail <= 0) return 0
            for (i in 0 until avail) out[i] = buf[((from + i) % capacity).toInt()]
            return avail
        }
    }
}

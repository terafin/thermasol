/* playback_control.c -- pure decision core for media-aware idle suppression.
 * No syscalls, no globals, no clock: the daemon supplies bytes and time. */
#include "playback_control.h"
#include <string.h>

/* ---- line parser -------------------------------------------------------- */

void playback_parser_init(playback_parser_t *p)
{
    if (!p) return;
    p->len = 0;
    p->over = 0;
}

playback_line_t playback_parser_byte(playback_parser_t *p, unsigned char c)
{
    if (!p) return PLAYBACK_LINE_NONE;

    if (c == '\n') {
        playback_line_t r;
        if (p->over) {
            r = PLAYBACK_LINE_OVERSIZE;
        } else {
            p->buf[p->len] = '\0';
            if (p->len == 7 && memcmp(p->buf, "PLAYING", 7) == 0)
                r = PLAYBACK_LINE_PLAYING;
            else if (p->len == 4 && memcmp(p->buf, "IDLE", 4) == 0)
                r = PLAYBACK_LINE_IDLE;
            else
                r = PLAYBACK_LINE_INVALID;
        }
        p->len = 0;
        p->over = 0;
        return r;
    }

    if (p->over) return PLAYBACK_LINE_NONE;    /* still discarding the excess */

    if (p->len < PLAYBACK_LINE_MAX - 1)
        p->buf[p->len++] = (char)c;
    else
        p->over = 1;                            /* one byte too many: overflow */
    return PLAYBACK_LINE_NONE;
}

/* ---- lease / state machine ---------------------------------------------- */

void playback_lease_init(playback_lease_t *l, int enabled)
{
    if (!l) return;
    l->enabled = enabled ? 1 : 0;
    l->state = l->enabled ? PLAYBACK_UNKNOWN : PLAYBACK_DISABLED;
    l->heartbeat_ms = -1;
}

void playback_lease_line(playback_lease_t *l, playback_line_t line, long long now_ms)
{
    if (!l || !l->enabled) return;
    switch (line) {
    case PLAYBACK_LINE_PLAYING:
        l->state = PLAYBACK_PLAYING;
        l->heartbeat_ms = now_ms;
        break;
    case PLAYBACK_LINE_IDLE:
        l->state = PLAYBACK_IDLE;
        l->heartbeat_ms = now_ms;
        break;
    case PLAYBACK_LINE_INVALID:
    case PLAYBACK_LINE_OVERSIZE:
        /* A line we cannot read is worse than silence: we no longer know what
         * the parent is doing, so distrust it AND the stamp it left. */
        l->state = PLAYBACK_UNKNOWN;
        l->heartbeat_ms = -1;
        break;
    case PLAYBACK_LINE_NONE:
    default:
        break;
    }
}

void playback_lease_fault(playback_lease_t *l)
{
    if (!l || !l->enabled) return;
    l->state = PLAYBACK_UNKNOWN;
    l->heartbeat_ms = -1;
}

void playback_lease_tick(playback_lease_t *l, long long now_ms)
{
    if (!l || !l->enabled) return;
    if (l->state == PLAYBACK_UNKNOWN) return;   /* already inhibited */
    if (l->heartbeat_ms < 0 || now_ms - l->heartbeat_ms > PLAYBACK_HEARTBEAT_MS) {
        l->state = PLAYBACK_UNKNOWN;
        l->heartbeat_ms = -1;
    }
}

int playback_inhibits(const playback_lease_t *l)
{
    /* Everything except a KNOWN idle inhibits. In particular the very first
     * seconds, before a single line has arrived, are UNKNOWN -- and must not
     * dim, or a panel could blank before the parent ever speaks. */
    if (!l || !l->enabled) return 0;
    return (l->state != PLAYBACK_IDLE) ? 1 : 0;
}

const char *playback_state_name(playback_state_t s)
{
    switch (s) {
    case PLAYBACK_DISABLED: return "disabled";
    case PLAYBACK_PLAYING:  return "playing";
    case PLAYBACK_IDLE:     return "idle";
    case PLAYBACK_UNKNOWN:
    default:                return "unknown";
    }
}

const char *playback_lease_name(const playback_lease_t *l)
{
    if (!l || !l->enabled) return "disabled";
    return playback_state_name(l->state);
}

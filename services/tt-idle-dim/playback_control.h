/* playback_control.h -- pure, syscall-free media-aware idle suppression.
 *
 * The daemon tee's one extra, opt-in input: a parent "playback controller"
 * writes exactly "PLAYING\n" or "IDLE\n" to our stdin once a second. Nothing
 * here trusts that. A missing, malformed or unreadable heartbeat degrades to
 * UNKNOWN, and UNKNOWN inhibits dimming -- a panel blanked over live video is
 * the failure this whole file exists to prevent.
 *
 * No syscalls, no globals, no timers: the daemon owns all I/O and the clock, so
 * this is unit-testable natively (x86_64) and cross-built for Android unchanged.
 */
#ifndef PLAYBACK_CONTROL_H
#define PLAYBACK_CONTROL_H

#include <stddef.h>

/* Heartbeat older than this on the control channel means the parent is no
 * longer telling us the truth: fall back to UNKNOWN (inhibit). */
#define PLAYBACK_HEARTBEAT_MS 5000
/* Longest line held for a single command, including the terminating newline.
 * Anything longer is discarded up to its newline and reported OVERSIZE. */
#define PLAYBACK_LINE_MAX 64

typedef enum {
    PLAYBACK_DISABLED = 0,  /* --playback-stdin absent: the feature is inert */
    PLAYBACK_UNKNOWN,       /* no trustworthy parent state -> inhibit dimming */
    PLAYBACK_PLAYING,       /* parent says video is live   -> inhibit dimming */
    PLAYBACK_IDLE           /* parent says video stopped   -> idle/tap logic runs */
} playback_state_t;

/* ---- line parser -------------------------------------------------------- */

/* What one call to playback_parser_byte() yielded. */
typedef enum {
    PLAYBACK_LINE_NONE = 0, /* a partial line is buffered: need more bytes */
    PLAYBACK_LINE_PLAYING,  /* a complete "PLAYING" line */
    PLAYBACK_LINE_IDLE,     /* a complete "IDLE" line */
    PLAYBACK_LINE_INVALID,  /* a complete line that is not PLAYING/IDLE */
    PLAYBACK_LINE_OVERSIZE  /* a complete line too long to hold */
} playback_line_t;

typedef struct {
    char   buf[PLAYBACK_LINE_MAX];
    size_t len;             /* bytes buffered for the line in progress */
    int    over;            /* the line in progress has overflowed */
} playback_parser_t;

void playback_parser_init(playback_parser_t *p);

/* Feed a single byte. Returns PLAYBACK_LINE_NONE until a newline completes the
 * line. Handles partial reads (a command split across read()s), combined lines
 * (several complete commands in one read) and over-long lines (excess bytes are
 * discarded up to the newline, which then reports PLAYBACK_LINE_OVERSIZE once).
 * The command text must be exactly "PLAYING" or "IDLE"; anything else, including
 * a bare newline, is INVALID. */
playback_line_t playback_parser_byte(playback_parser_t *p, unsigned char c);

/* ---- lease / state machine ---------------------------------------------- */

typedef struct {
    int              enabled;       /* feature on for this daemon instance? */
    playback_state_t state;         /* current classified parent state */
    long long        heartbeat_ms;  /* monotonic ms of the last trustworthy
                                     * line, or -1 for "none". Non-secret; this
                                     * is what the status file reports. */
} playback_lease_t;

/* enabled=0 leaves the lease DISABLED and every later call a no-op, so a daemon
 * run without --playback-stdin behaves exactly as it always did. */
void playback_lease_init(playback_lease_t *l, int enabled);

/* Apply one parsed line. PLAYING/IDLE set the state and refresh the heartbeat;
 * INVALID/OVERSIZE treat the parent as untrustworthy and drop to UNKNOWN. A
 * disabled lease ignores everything. */
void playback_lease_line(playback_lease_t *l, playback_line_t line, long long now_ms);

/* EOF or a read error on the control channel: the parent is gone -> UNKNOWN. */
void playback_lease_fault(playback_lease_t *l);

/* Heartbeat expiry. Call once per loop tick: a state whose heartbeat is older
 * than PLAYBACK_HEARTBEAT_MS drops to UNKNOWN. */
void playback_lease_tick(playback_lease_t *l, long long now_ms);

/* 1 when the current state forbids dimming: PLAYING or UNKNOWN. Always 0 on a
 * disabled lease, so an unopted daemon is unchanged. */
int playback_inhibits(const playback_lease_t *l);

/* Stable, non-secret status tokens: disabled|unknown|playing|idle. */
const char *playback_state_name(playback_state_t s);
const char *playback_lease_name(const playback_lease_t *l);

#endif /* PLAYBACK_CONTROL_H */

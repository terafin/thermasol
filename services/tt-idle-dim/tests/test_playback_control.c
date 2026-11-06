/* Unit tests for the pure media-aware idle-suppression core.
 * Simulated monotonic clock and simulated byte stream: no syscalls. */
#include "../playback_control.h"
#include <stdio.h>
#include <string.h>

static int g_tests = 0, g_fails = 0;
#define CHECK(cond) do {                                        \
        g_tests++;                                              \
        if (!(cond)) { g_fails++;                               \
            printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); } \
    } while (0)

/* Feed a whole string; return the list of complete lines produced. */
static size_t feed(playback_parser_t *p, const char *s, playback_line_t *out, size_t cap) {
    size_t n = 0;
    for (const char *q = s; *q; q++) {
        playback_line_t l = playback_parser_byte(p, (unsigned char)*q);
        if (l != PLAYBACK_LINE_NONE && n < cap) out[n++] = l;
    }
    return n;
}

/* ---- disabled feature is inert ------------------------------------------ */
static void test_disabled_is_inert(void) {
    playback_lease_t l;
    playback_lease_init(&l, 0);
    CHECK(l.state == PLAYBACK_DISABLED);
    CHECK(playback_inhibits(&l) == 0);
    /* even a PLAYING line must not turn the feature on */
    playback_lease_line(&l, PLAYBACK_LINE_PLAYING, 1000);
    CHECK(l.state == PLAYBACK_DISABLED);
    CHECK(playback_inhibits(&l) == 0);
    playback_lease_fault(&l);
    playback_lease_tick(&l, 999999);
    CHECK(l.state == PLAYBACK_DISABLED);
    CHECK(playback_inhibits(&l) == 0);
    CHECK(strcmp(playback_lease_name(&l), "disabled") == 0);
}

/* ---- initial state is UNKNOWN and inhibits ------------------------------ */
static void test_initial_unknown_inhibits(void) {
    playback_lease_t l;
    playback_lease_init(&l, 1);
    CHECK(l.state == PLAYBACK_UNKNOWN);
    CHECK(l.heartbeat_ms == -1);
    CHECK(playback_inhibits(&l) == 1);        /* fail safe: never dim with no word */
    CHECK(strcmp(playback_lease_name(&l), "unknown") == 0);
}

/* ---- parser: exact lines, partial reads, combined lines ----------------- */
static void test_parser_exact_lines(void) {
    playback_parser_t p; playback_line_t out[8];
    playback_parser_init(&p);
    CHECK(feed(&p, "PLAYING\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_PLAYING);
    CHECK(feed(&p, "IDLE\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_IDLE);
    /* trailing partial line yields nothing until completed */
    CHECK(feed(&p, "PLAY", out, 8) == 0);
    CHECK(feed(&p, "ING\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_PLAYING);
    /* several commands delivered in one buffer */
    CHECK(feed(&p, "IDLE\nPLAYING\nIDLE\n", out, 8) == 3);
    CHECK(out[0] == PLAYBACK_LINE_IDLE && out[1] == PLAYBACK_LINE_PLAYING &&
          out[2] == PLAYBACK_LINE_IDLE);
}

/* ---- parser: anything that is not exactly PLAYING/IDLE is INVALID -------- */
static void test_parser_invalid_lines(void) {
    playback_parser_t p; playback_line_t out[8];
    playback_parser_init(&p);
    CHECK(feed(&p, "\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_INVALID);
    CHECK(feed(&p, "PLAYING \n", out, 8) == 1 && out[0] == PLAYBACK_LINE_INVALID);
    CHECK(feed(&p, "playing\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_INVALID);
    CHECK(feed(&p, "IDLEZ\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_INVALID);
    CHECK(feed(&p, "PAUSE\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_INVALID);
    CHECK(feed(&p, "PLAYING\r\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_INVALID);
}

/* ---- parser: over-long lines are discarded up to their newline ---------- */
static void test_parser_oversize(void) {
    playback_parser_t p; playback_line_t out[8];
    playback_parser_init(&p);
    char big[PLAYBACK_LINE_MAX + 32];
    memset(big, 'A', sizeof big - 2); big[sizeof big - 2] = '\n'; big[sizeof big - 1] = 0;
    CHECK(feed(&p, big, out, 8) == 1 && out[0] == PLAYBACK_LINE_OVERSIZE);
    /* the parser recovers: the next good command still parses */
    CHECK(feed(&p, "PLAYING\n", out, 8) == 1 && out[0] == PLAYBACK_LINE_PLAYING);
}

/* ---- lease transitions -------------------------------------------------- */
static void test_lease_transitions(void) {
    playback_lease_t l;
    playback_lease_init(&l, 1);
    playback_lease_line(&l, PLAYBACK_LINE_PLAYING, 1000);
    CHECK(l.state == PLAYBACK_PLAYING);
    CHECK(l.heartbeat_ms == 1000);
    CHECK(playback_inhibits(&l) == 1);
    CHECK(strcmp(playback_lease_name(&l), "playing") == 0);

    playback_lease_line(&l, PLAYBACK_LINE_IDLE, 2000);
    CHECK(l.state == PLAYBACK_IDLE);
    CHECK(l.heartbeat_ms == 2000);
    CHECK(playback_inhibits(&l) == 0);         /* known IDLE permits idle logic */
    CHECK(strcmp(playback_lease_name(&l), "idle") == 0);

    /* invalid line drops straight to UNKNOWN and distrusts the old stamp */
    playback_lease_line(&l, PLAYBACK_LINE_IDLE, 2100);
    playback_lease_line(&l, PLAYBACK_LINE_INVALID, 2200);
    CHECK(l.state == PLAYBACK_UNKNOWN);
    CHECK(l.heartbeat_ms == -1);
    CHECK(playback_inhibits(&l) == 1);

    playback_lease_line(&l, PLAYBACK_LINE_IDLE, 2300);
    playback_lease_line(&l, PLAYBACK_LINE_OVERSIZE, 2400);
    CHECK(l.state == PLAYBACK_UNKNOWN);

    /* fault (EOF / read error) -> UNKNOWN */
    playback_lease_line(&l, PLAYBACK_LINE_PLAYING, 2500);
    playback_lease_fault(&l);
    CHECK(l.state == PLAYBACK_UNKNOWN);
    CHECK(l.heartbeat_ms == -1);
    CHECK(playback_inhibits(&l) == 1);
}

/* ---- heartbeat expiry --------------------------------------------------- */
static void test_heartbeat_expiry(void) {
    playback_lease_t l;
    playback_lease_init(&l, 1);
    playback_lease_line(&l, PLAYBACK_LINE_IDLE, 10000);
    CHECK(l.state == PLAYBACK_IDLE);

    /* exactly at the boundary nothing has expired yet */
    playback_lease_tick(&l, 10000 + PLAYBACK_HEARTBEAT_MS);
    CHECK(l.state == PLAYBACK_IDLE);
    /* one millisecond past it, the parent is stale -> UNKNOWN */
    playback_lease_tick(&l, 10000 + PLAYBACK_HEARTBEAT_MS + 1);
    CHECK(l.state == PLAYBACK_UNKNOWN);
    CHECK(playback_inhibits(&l) == 1);

    /* and a fresh line revives it */
    playback_lease_line(&l, PLAYBACK_LINE_PLAYING, 20000);
    CHECK(l.state == PLAYBACK_PLAYING);
    CHECK(playback_inhibits(&l) == 1);
    playback_lease_line(&l, PLAYBACK_LINE_IDLE, 20001);
    CHECK(l.state == PLAYBACK_IDLE);
    CHECK(playback_inhibits(&l) == 0);
}

int main(void) {
    test_disabled_is_inert();
    test_initial_unknown_inhibits();
    test_parser_exact_lines();
    test_parser_invalid_lines();
    test_parser_oversize();
    test_lease_transitions();
    test_heartbeat_expiry();
    printf("%d assertions, %d failures\n", g_tests, g_fails);
    return g_fails ? 1 : 0;
}

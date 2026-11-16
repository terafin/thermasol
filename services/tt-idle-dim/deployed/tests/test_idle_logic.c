/* Unit tests for the pure idle/dim decision core (simulated monotonic + event state). */
#include "../idle_logic.h"
#include <linux/input.h>
#include <stdio.h>

static int g_tests = 0, g_fails = 0;
#define CHECK(cond) do {                                        \
        g_tests++;                                              \
        if (!(cond)) { g_fails++;                               \
            printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); } \
    } while (0)

/* timeout dim: crosses threshold -> DIM, idempotent once dimmed */
static void test_timeout_dim(void) {
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 119999, 0, 120000, 0) == IDLE_ACT_NONE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 120000, 0, 120000, 0) == IDLE_ACT_DIM);
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 500000, 0, 120000, 0) == IDLE_ACT_DIM);
    CHECK(idle_step(IDLE_ST_DIM,    1, 1, 999999, 0, 120000, 0) == IDLE_ACT_NONE);
}

/* touch restore: physical touch while dimmed -> RESTORE; while active -> no-op */
static void test_touch_restore(void) {
    CHECK(idle_step(IDLE_ST_DIM,    1, 1, 200000, 0, 120000, 1) == IDLE_ACT_RESTORE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 200000, 0, 120000, 1) == IDLE_ACT_NONE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 900000, 899000, 120000, 1) == IDLE_ACT_NONE);
}

/* no dim while initial brightness is unknown */
static void test_no_dim_bright_unknown(void) {
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 0, 600000, 0, 120000, 0) == IDLE_ACT_NONE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 0, 120000, 0, 120000, 0) == IDLE_ACT_NONE);
}

/* DURABILITY: never dim blind while the evdev listener is closed */
static void test_no_dim_input_not_ready(void) {
    CHECK(idle_step(IDLE_ST_ACTIVE, 0, 1, 999999, 0, 120000, 0) == IDLE_ACT_NONE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 0, 1, 120000, 0, 120000, 0) == IDLE_ACT_NONE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 0, 0, 999999, 0, 120000, 0) == IDLE_ACT_NONE);
}

/* DURABILITY: input lost while dimmed -> restore now (no wait for a touch) */
static void test_lost_input_while_dim_restores(void) {
    CHECK(idle_step(IDLE_ST_DIM, 0, 1, 200000, 0, 120000, 0) == IDLE_ACT_RESTORE);
    CHECK(idle_step(IDLE_ST_DIM, 0, 1, 1,      0, 120000, 0) == IDLE_ACT_RESTORE);
    /* and it must not re-dim after the restore write, listener still closed */
    CHECK(idle_step(IDLE_ST_ACTIVE, 0, 1, 999999, 0, 120000, 0) == IDLE_ACT_NONE);
}

/* DURABILITY: after a rebind the listener reopens and is stamped active, so the
 * daemon must not immediately re-dim on stale idle history */
static void test_rebind_no_immediate_redim(void) {
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 500000, 500000, 120000, 0) == IDLE_ACT_NONE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 619999, 500000, 120000, 0) == IDLE_ACT_NONE);
    CHECK(idle_step(IDLE_ST_ACTIVE, 1, 1, 620000, 500000, 120000, 0) == IDLE_ACT_DIM);
}

/* a failed sysfs write must not let the daemon claim a new state */
static void test_sysfs_failure_no_claim(void) {
    CHECK(idle_commit(IDLE_ST_ACTIVE, IDLE_ACT_DIM,     0) == IDLE_ST_ACTIVE);
    CHECK(idle_commit(IDLE_ST_ACTIVE, IDLE_ACT_DIM,     1) == IDLE_ST_DIM);
    CHECK(idle_commit(IDLE_ST_DIM,    IDLE_ACT_RESTORE, 0) == IDLE_ST_DIM);
    CHECK(idle_commit(IDLE_ST_DIM,    IDLE_ACT_RESTORE, 1) == IDLE_ST_ACTIVE);
    CHECK(idle_commit(IDLE_ST_ACTIVE, IDLE_ACT_NONE,    0) == IDLE_ST_ACTIVE);
}

/* restore value must be validated against the panel maximum */
static void test_bright_valid(void) {
    CHECK(idle_bright_valid(71, 255)  == 1);
    CHECK(idle_bright_valid(0, 255)   == 1);
    CHECK(idle_bright_valid(255, 255) == 1);
    CHECK(idle_bright_valid(256, 255) == 0);
    CHECK(idle_bright_valid(-1, 255)  == 0);
    CHECK(idle_bright_valid(300, -1)  == 1);   /* max unknown: accept any >= 0 */
    CHECK(idle_bright_valid(-1, -1)   == 0);
}

/* simulated input_event classification */
static void test_touch_classify(void) {
    CHECK(idle_is_touch_event(EV_ABS, ABS_MT_POSITION_X, 100) == 1);
    CHECK(idle_is_touch_event(EV_ABS, ABS_MT_TRACKING_ID, 5) == 1);
    CHECK(idle_is_touch_event(EV_ABS, ABS_X, 5)              == 1);
    CHECK(idle_is_touch_event(EV_KEY, BTN_TOUCH, 1)          == 1);
    CHECK(idle_is_touch_event(EV_KEY, BTN_TOOL_FINGER, 1)    == 1);
    CHECK(idle_is_touch_event(EV_SYN, SYN_REPORT, 0)         == 0);
    CHECK(idle_is_touch_event(EV_MSC, MSC_SCAN, 0)           == 0);
    CHECK(idle_is_touch_event(EV_KEY, KEY_POWER, 1)          == 0);
    CHECK(idle_is_touch_event(EV_REL, REL_X, 3)              == 0);
}

/* =====================================================================
 * Named-device attach policy.
 * Bug: with --input-name set, an unmatched name still fell back to the fixed
 * path (/dev/input/event1). After a rebind that can bind the daemon to a
 * different device, whose panel it then dims blind.
 * ===================================================================== */
static void test_named_input_never_uses_path_fallback(void) {
    CHECK(idle_may_attach(1, 0) == 0);   /* name required, not matched -> refuse */
    CHECK(idle_may_attach(1, 1) == 1);   /* name required, matched      -> attach */
    CHECK(idle_may_attach(0, 0) == 1);   /* no name asked: the path is fine */
    CHECK(idle_may_attach(0, 1) == 1);
}

/* =====================================================================
 * Restart safety: parse the previous run's status record.
 * ===================================================================== */
static void test_prior_status_parse(void) {
    idle_prior_t p;
    const char *good =
        "state=dim\nlast_activity_ms=1\nbright_known=1\nrestore_bright=71\n"
        "dim_bright=8\nmax_bright=255\nrunning_bright=8\ntouch_events=3\n"
        "input=/dev/input/event1\ninput_open=1\npid=42\nboot_id=00aa11bb\n";
    CHECK(idle_parse_prior(good, &p) == 1);
    CHECK(p.valid == 1);
    CHECK(p.state_dim == 1);
    CHECK(p.restore_bright == 71);
    CHECK(p.dim_bright == 8);
    CHECK(p.boot_id == 0x00aa11bbLL);

    /* state=active means the daemon was holding the panel bright, so its cached
     * restore value is not a claim about a dim it owned */
    const char *active = "state=active\nrestore_bright=71\nboot_id=00aa11bb\n";
    CHECK(idle_parse_prior(active, &p) == 1);
    CHECK(p.state_dim == 0);
    CHECK(p.dim_bright == -1);        /* absent from this record */

    /* an old-format record with no boot_id cannot be trusted across a restart */
    const char *noboot = "state=dim\nrestore_bright=71\npid=42\n";
    CHECK(idle_parse_prior(noboot, &p) == 0);
    CHECK(p.valid == 0);

    CHECK(idle_parse_prior("", &p) == 0);
}

/* =====================================================================
 * Restart safety: same-boot crash while dimmed restores the cached value.
 * ===================================================================== */
static void test_restart_same_boot_restores_cached(void) {
    idle_prior_t p;
    CHECK(idle_parse_prior("state=dim\nrestore_bright=71\ndim_bright=8\n"
                           "boot_id=00000006\n", &p) == 1);
    CHECK(p.dim_bright == 8);
    /* live reads 8 because we are still dimmed, so the cached 71 must win AND the
     * record must be recognised as ours (the daemon then enters DIMMED, not
     * ACTIVE -- which is what made the real daemon lose the value) */
    CHECK(idle_prior_owned(&p, 6, 255, 8) == 1);
    CHECK(idle_startup_restore(&p, 6, 255, 8) == 71);

    /* a record with no dim_bright cannot prove the panel is still where we left
     * it, so it must never be treated as ours */
    CHECK(idle_parse_prior("state=dim\nrestore_bright=71\nboot_id=00000006\n", &p) == 1);
    CHECK(idle_prior_owned(&p, 6, 255, 8) == 0);
}

/* a record from a DIFFERENT boot is ignored */
static void test_restart_prior_from_other_boot_ignored(void) {
    idle_prior_t p;
    CHECK(idle_parse_prior("state=dim\nrestore_bright=71\nboot_id=00000005\n", &p) == 1);
    CHECK(idle_startup_restore(&p, 6, 255, 42) == 42);
}

/* a legitimate startup brightness is not overridden, and a user's own dim is
 * never confused with a daemon-owned one */
static void test_legit_startup_brightness_not_overridden(void) {
    idle_prior_t p;
    CHECK(idle_parse_prior("state=active\nrestore_bright=71\nboot_id=00000006\n", &p) == 1);
    CHECK(idle_startup_restore(&p, 6, 255, 42) == 42);

    p.valid = 0;
    CHECK(idle_startup_restore(&p, 6, 255, 100) == 100);
    /* live 8 with no daemon-owned prior is a legitimate value: adopt it as-is,
     * never fabricate 71 */
    CHECK(idle_startup_restore(&p, 6, 255, 8) == 8);
}

/* nothing is fabricated when there is no usable value */
static void test_startup_no_fabricated_brightness(void) {
    idle_prior_t p;
    p.valid = 0;
    CHECK(idle_startup_restore(&p, 6, 255, -1) == -1);

    /* same-boot dim record whose restore fails validation (max 50): fall
     * through to live, and with no live reading, to -1 -- never a made-up value */
    CHECK(idle_parse_prior("state=dim\nrestore_bright=71\nboot_id=00000006\n", &p) == 1);
    CHECK(idle_startup_restore(&p, 6, 50, -1) == -1);
    CHECK(idle_startup_restore(&p, 6, 50, 30) == 30);
}

/* a brightness the user changed after our dim is theirs: it wins */
static void test_user_changed_brightness_wins(void) {
    idle_prior_t p;
    CHECK(idle_parse_prior("state=dim\nrestore_bright=71\ndim_bright=8\n"
                           "boot_id=00000006\n", &p) == 1);
    /* live is 50 now: what we dimmed to is gone, so we no longer own it */
    CHECK(idle_prior_owned(&p, 6, 255, 50) == 0);
    CHECK(idle_startup_restore(&p, 6, 255, 50) == 50);
}

/* an unknown boot id must never match an unknown prior boot id */
static void test_unknown_boot_never_matches_unknown_prior(void) {
    idle_prior_t p;
    p.valid = 1; p.boot_id = -1; p.state_dim = 1;
    p.restore_bright = 71; p.dim_bright = 8;
    CHECK(idle_prior_owned(&p, -1, 255, 8) == 0);
    CHECK(idle_startup_restore(&p, -1, 255, 8) == 8);

    /* nor may a known current boot match an unknown prior boot */
    CHECK(idle_prior_owned(&p, 6, 255, 8) == 0);

    /* an unknown live or dim value is not ownership either */
    p.boot_id = 6; p.dim_bright = -1;
    CHECK(idle_prior_owned(&p, 6, 255, -1) == 0);
    CHECK(idle_prior_owned(&p, 6, 255, 8) == 0);
}

/* an external write while we own the dim is adopted, never fought */
static void test_external_write_while_dim(void) {
    /* we dimmed to 8; the node now reads 71: someone else wrote it */
    CHECK(idle_external_write_seen(IDLE_ST_DIM, 71, 8) == 1);
    /* a user's own value, not ours */
    CHECK(idle_external_write_seen(IDLE_ST_DIM, 50, 8) == 1);
    /* the node still holds what we wrote: still ours */
    CHECK(idle_external_write_seen(IDLE_ST_DIM, 8, 8) == 0);
    /* we are not dimmed: nothing of ours to release */
    CHECK(idle_external_write_seen(IDLE_ST_ACTIVE, 71, 8) == 0);
    /* a failed read is never proof of an external write */
    CHECK(idle_external_write_seen(IDLE_ST_DIM, -1, 8) == 0);
    CHECK(idle_external_write_seen(IDLE_ST_DIM, 71, -1) == 0);
}

int main(void) {
    test_timeout_dim();
    test_touch_restore();
    test_no_dim_bright_unknown();
    test_no_dim_input_not_ready();
    test_lost_input_while_dim_restores();
    test_rebind_no_immediate_redim();
    test_sysfs_failure_no_claim();
    test_bright_valid();
    test_touch_classify();
    test_named_input_never_uses_path_fallback();
    test_prior_status_parse();
    test_restart_same_boot_restores_cached();
    test_restart_prior_from_other_boot_ignored();
    test_legit_startup_brightness_not_overridden();
    test_startup_no_fabricated_brightness();
    test_user_changed_brightness_wins();
    test_unknown_boot_never_matches_unknown_prior();
    test_external_write_while_dim();
    printf("%d assertions, %d failures\n", g_tests, g_fails);
    return g_fails ? 1 : 0;
}

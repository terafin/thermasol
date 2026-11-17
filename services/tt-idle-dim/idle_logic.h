/* idle_logic.h -- pure, side-effect-free decision core for tt-idle-dim.
 * No syscalls here: the daemon owns all I/O so this can be unit-tested
 * natively (x86_64) and cross-built for aarch64-linux-android unchanged.
 */
#ifndef IDLE_LOGIC_H
#define IDLE_LOGIC_H

typedef enum {
    IDLE_ACT_NONE = 0,   /* nothing to do */
    IDLE_ACT_DIM,        /* idle threshold crossed -> dim panel */
    IDLE_ACT_RESTORE     /* touch (or lost input) while dimmed -> restore */
} idle_action_t;

typedef enum {
    IDLE_ST_ACTIVE = 0,  /* fully bright */
    IDLE_ST_DIM          /* currently dimmed by us */
} idle_state_t;

/* Decide the next action.
 *   state             current dim state (NOT mutated here)
 *   input_ready       the evdev listener is currently open (1) or not (0)
 *   bright_known      we hold a restorable brightness value
 *   now_ms            CLOCK_MONOTONIC milliseconds
 *   last_activity_ms  CLOCK_MONOTONIC ms of the last physical touch
 *   idle_ms           idle threshold in ms
 *   activity          1 if this call follows a physical touch event
 *
 * Contract: never dim while the listener is closed (we would be blind to the
 * gesture that must restore it); if the listener drops while dimmed, restore.
 */
idle_action_t idle_step(idle_state_t state, int input_ready, int bright_known,
                        long long now_ms, long long last_activity_ms,
                        long long idle_ms, int activity);

/* Adopt a proposed state change ONLY if the backing sysfs write succeeded.
 * A failed write must never let the daemon believe it changed the panel. */
idle_state_t idle_commit(idle_state_t state, idle_action_t act, int write_ok);

/* Classify a raw input_event as a physical touch gesture.
 * EV_ABS (any) and BTN_TOUCH/TOOL_* count; SYN/MSC/other keys do not. */
int idle_is_touch_event(unsigned short type, unsigned short code, int value);

/* Validate a candidate restore brightness against the panel maximum.
 * max < 0 means the maximum is unknown; then any value >= 0 is accepted. */
int idle_bright_valid(int value, int max_brightness);

/* ---- input-attach policy ------------------------------------------------ */

/* May the daemon attach to a node it just opened?
 *   name_required : 1 when --input-name was given (a specific device was asked for)
 *   matched_name  : 1 when the ACTUAL opened fd's EVIOCGNAME equalled that name
 * Returns 1 to attach, 0 to close the node and keep retrying.
 *
 * Contract: when a name is required, a node that did not match it must never be
 * attached. Otherwise the fixed-path fallback can bind the daemon to an unrelated
 * device, and it would dim that device's panel blind. */
int idle_may_attach(int name_required, int matched_name);

/* Did someone ELSE write the backlight while we own the dim?
 *   state    current dim state
 *   actual   brightness read from the node now, or -1 if unreadable
 *   our_dim  the value we wrote when we dimmed
 * Returns 1 when the node no longer holds the value we set, i.e. a framework
 * theme change or a user brightness change has landed on top of our dim. That
 * value is theirs: the daemon must adopt it and stand down (state ACTIVE, idle
 * clock reset) rather than overwrite it, and must never mistake it for the
 * "user brightness" it re-dims over 120 s later.
 * A failed read (actual < 0) is never proof of an external write. */
int idle_external_write_seen(idle_state_t state, int actual, int our_dim);

/* ---- restart safety ----------------------------------------------------- */

/* A previous run's status record. */
typedef struct {
    int       valid;          /* carried state + restore_bright + boot_id */
    long long boot_id;        /* boot the record was written in; <0 if absent */
    int       state_dim;      /* record says this daemon owned the dim */
    int       restore_bright; /* brightness the record says to restore to */
    int       dim_bright;     /* value this daemon dimmed to; <0 if absent */
} idle_prior_t;

/* Parse a status file body (the format the daemon writes). Returns 1 iff it
 * carried a usable record (state, restore_bright and boot_id all present). */
int idle_parse_prior(const char *text, idle_prior_t *out);

/* Does the prior record prove that THIS daemon still owns the current dim?
 *   prior        parsed previous status
 *   cur_boot     current boot id (<0 when unreadable)
 *   max_bright   panel maximum, or -1 if unknown
 *   live         brightness read from sysfs now, or -1 if unreadable
 * True only when: the record is valid; it says we dimmed; BOTH boot ids are
 * known and equal; the live brightness still equals the value we dimmed to (so
 * a brightness the user has since changed is never treated as ours); and the
 * value we would restore to is itself writable.
 *
 * An unknown boot id never matches an unknown prior boot id. */
int idle_prior_owned(const idle_prior_t *prior, long long cur_boot,
                     int max_bright, int live);

/* Choose the brightness to adopt at startup.
 * Returns >= 0 to adopt, or -1 meaning "no trustworthy value" (the daemon then
 * must not dim until it learns one).
 *   - if idle_prior_owned() holds, the cached restore value is adopted;
 *   - otherwise the live reading stands, so a legitimate user brightness is
 *     never overridden and a user's own dim is never mistaken for ours;
 *   - nothing is fabricated: the result is the validated cached value or the
 *     validated live reading, else -1. */
int idle_startup_restore(const idle_prior_t *prior, long long cur_boot,
                         int max_bright, int live);

/* HydroVive send gating. desired < 0 means "no opinion"; bus_state < 0 means
 * the unit's state is unknown (a send is always attempted then). A mismatch is
 * sent at once, and re-attempted only after next_ms -- the back-off a failed
 * send sets, so a broken bus is not hammered once per tick. */
#define IDLE_HV_RETRY_MS 2000
int idle_hv_needs_send(int desired, int bus_state, long long now, long long next_ms);

#endif /* IDLE_LOGIC_H */

/* idle_logic.c -- pure decision core for tt-idle-dim. No syscalls, no globals. */
#include "idle_logic.h"
#include <linux/input.h>
#include <stdlib.h>
#include <string.h>

idle_action_t idle_step(idle_state_t state, int input_ready, int bright_known,
                        long long now_ms, long long last_activity_ms,
                        long long idle_ms, int activity)
{
    if (activity)
        /* A physical touch restores immediately if we dimmed the panel. */
        return (state == IDLE_ST_DIM) ? IDLE_ACT_RESTORE : IDLE_ACT_NONE;

    if (!input_ready)
        /* Listener closed: we are blind to the restoring gesture, so never dim;
         * and if we were dimmed, un-dim at once rather than wait for a touch. */
        return (state == IDLE_ST_DIM) ? IDLE_ACT_RESTORE : IDLE_ACT_NONE;

    if (!bright_known)              /* unknown => could not restore reliably */
        return IDLE_ACT_NONE;

    if (state == IDLE_ST_ACTIVE && idle_ms > 0 &&
        (now_ms - last_activity_ms) >= idle_ms)
        return IDLE_ACT_DIM;
    return IDLE_ACT_NONE;
}

idle_state_t idle_commit(idle_state_t state, idle_action_t act, int write_ok)
{
    if (!write_ok)                  /* sysfs refused: do not claim a change */
        return state;
    if (act == IDLE_ACT_DIM)     return IDLE_ST_DIM;
    if (act == IDLE_ACT_RESTORE) return IDLE_ST_ACTIVE;
    return state;
}

int idle_is_touch_event(unsigned short type, unsigned short code, int value)
{
    (void)value;
    if (type == EV_ABS)
        return 1;                   /* any absolute axis: position / MT slot / tracking */
    if (type == EV_KEY &&
        (code == BTN_TOUCH || code == BTN_TOOL_FINGER ||
         code == BTN_TOOL_DOUBLETAP || code == BTN_TOOL_TRIPLETAP ||
         code == BTN_TOOL_QUADTAP || code == BTN_TOOL_QUINTTAP))
        return 1;
    return 0;                       /* EV_SYN / EV_MSC / EV_REL / other keys: ignore */
}

int idle_bright_valid(int value, int max_brightness)
{
    if (value < 0) return 0;
    if (max_brightness >= 0 && value > max_brightness) return 0;
    return 1;
}

/* ---- input-attach policy ------------------------------------------------ */

int idle_may_attach(int name_required, int matched_name)
{
    /* With --input-name, an unmatched node is refused rather than accepted via
     * the fixed-path fallback: attaching to a different device would let the
     * daemon dim a panel whose restoring gesture it cannot see. */
    if (name_required && !matched_name) return 0;
    return 1;
}

/* ---- restart safety ----------------------------------------------------- */

/* Find "<key><number>" at the start of a line. key includes the '='. */
static int field_ll(const char *text, const char *key, int base, long long *out)
{
    size_t kl = strlen(key);
    const char *p = text;
    while ((p = strstr(p, key)) != NULL) {
        if (p == text || p[-1] == '\n') {
            char *end = NULL;
            long long v = strtoll(p + kl, &end, base);
            if (end != p + kl) { *out = v; return 1; }
        }
        p += kl;
    }
    return 0;
}

int idle_parse_prior(const char *text, idle_prior_t *out)
{
    long long restore, boot, dim = -1;
    int state_dim = 0, have_state = 0;
    const char *p;

    if (!text || !out) return 0;
    out->valid = 0;
    out->boot_id = -1;
    out->state_dim = 0;
    out->restore_bright = -1;
    out->dim_bright = -1;

    /* state= is a bare word, not a number */
    for (p = text; (p = strstr(p, "state=")) != NULL; p += 6) {
        if (p != text && p[-1] != '\n') continue;
        have_state = 1;
        state_dim = (strncmp(p + 6, "dim", 3) == 0);
        break;
    }
    if (!have_state) return 0;

    if (!field_ll(text, "restore_bright=", 10, &restore)) return 0;
    if (!field_ll(text, "boot_id=", 16, &boot))           return 0;
    (void)field_ll(text, "dim_bright=", 10, &dim);        /* optional */

    out->boot_id = boot;
    out->restore_bright = (int)restore;
    out->dim_bright = (int)dim;
    out->state_dim = state_dim;
    out->valid = 1;
    return 1;
}

int idle_prior_owned(const idle_prior_t *prior, long long cur_boot,
                     int max_bright, int live)
{
    if (!prior || !prior->valid)              return 0;
    if (!prior->state_dim)                    return 0;
    /* an unknown boot id must never match an unknown prior boot id */
    if (cur_boot < 0 || prior->boot_id < 0)   return 0;
    if (prior->boot_id != cur_boot)           return 0;
    /* the panel must still be where we left it: if the user has changed the
     * brightness since, that value is theirs and must win */
    if (live < 0 || prior->dim_bright < 0)    return 0;
    if (live != prior->dim_bright)            return 0;
    if (!idle_bright_valid(prior->restore_bright, max_bright)) return 0;
    return 1;
}

int idle_startup_restore(const idle_prior_t *prior, long long cur_boot,
                         int max_bright, int live)
{
    if (idle_prior_owned(prior, cur_boot, max_bright, live))
        return prior->restore_bright;

    if (idle_bright_valid(live, max_bright))
        return live;

    return -1;                      /* nothing trustworthy: do not invent a value */
}

int idle_external_write_seen(idle_state_t state, int actual, int our_dim)
{
    if (state != IDLE_ST_DIM) return 0;       /* we own no dim */
    if (actual < 0 || our_dim < 0) return 0;  /* a failed read proves nothing */
    return (actual != our_dim) ? 1 : 0;
}

int idle_hv_needs_send(int desired, int bus_state, long long now, long long next_ms)
{
    if (desired < 0)          return 0;   /* nothing declared yet */
    if (bus_state == desired) return 0;   /* already where it should be */
    return now >= next_ms;                /* honour a failed send's back-off */
}

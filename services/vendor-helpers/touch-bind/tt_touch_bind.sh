#!/system/bin/sh
# tt_touch_bind.sh -- bind the 2-004b maXTouch client to the POLLED driver tt_mxt_polled.
#
# Owner:   /vendor/bin/tt_touch_bind.sh   (0755, root:root, label u:object_r:vendor_file:s0)
# Caller:  init service `tt-touch-bind`, started from `on boot` as:
#              /system/bin/sh -c "exec /system/xbin/su 0 /system/bin/sh /vendor/bin/tt_touch_bind.sh"
#          so the WHOLE helper runs as root and every read under /sys is a root read (the shell
#          domain can be denied those). The su calls inside are then nested but harmless; they
#          stay only so the offline harness can intercept them.
#
# Timed to run after post-fs-data and before sys.boot_completed launches the shower UI. It does
# NOT race init.insmod.sh (early-init) or the built-in driver's probe (~2 s into boot): by the
# time `on boot` runs, 2-004b is already bound to the built-in driver.
#
# WHAT IT DOES, ONCE PER BOOT
#   * waits up to 20 s for /sys/bus/i2c/devices/2-004b to exist (bounded, never forever);
#   * if 2-004b is already on tt_mxt_polled with poll_interval_ms=20 -> SUCCESS, no churn;
#   * if 2-004b is on the built-in driver -> unbind ONLY the exact client "2-004b", then
#     insmod /vendor/lib/modules/tt_mxt_polled.ko poll_interval_ms=20 (the module's OF match
#     auto-attaches), an explicit sysfs bind once if it did not;
#   * reports the REAL outcome in vendor.tt.touch_driver.
#   Worst case wall time: 20 s (wait) + 3 s (auto-bind) + 3 s (explicit bind) = ~26 s, and that
#   only when the module never attaches; every normal path is instantaneous.
#
# FAIL-CLOSED, HONESTLY. The goal is that 2-004b always ends on a working driver -- the polled
# one, or whatever was bound before. The script ATTEMPTS that repair on every failure. It does
# NOT claim a safety it did not achieve: if the repair itself fails it logs "REBIND FAILED" and
# reports it in the property with a ":restore-failed" suffix -- and if the device is somehow left
# with no driver at all the trap says so. It never writes IRQ/CHG/NVM, never touches
# GPIO/mux/power, never writes a hard-coded IRQ number, and never loads the old poll-timer
# helper. A failure to write the property does NOT undo a correct bind.
#
# The ${TT_*} assignments below DEFAULT to the real device paths. They exist so the offline
# harness (test_tt_touch_bind.py) can redirect into a fake sysfs tree; they are NOT a device
# backdoor: init starts this service with a CLEAN environment, so on the panel every default is
# taken and nothing on the device can set them.

SYS="${TT_SYS:-/sys}"
MODULES="${TT_MODULES:-/vendor/lib/modules}"
SU="${TT_SU:-/system/xbin/su}"
SETPROP="${TT_SETPROP:-/system/bin/setprop}"
SLEEP="${TT_SLEEP:-sleep}"

DEV=2-004b
BUILTIN=atmel_mxt_ts
POLLED=tt_mxt_polled
INTERVAL=20

MOD="$MODULES/tt_mxt_polled.ko"
PROP=vendor.tt.touch_driver
DEV_DIR="$SYS/bus/i2c/devices/$DEV"
B_BIND="$SYS/bus/i2c/drivers/$BUILTIN/bind"
B_UNBIND="$SYS/bus/i2c/drivers/$BUILTIN/unbind"
P_BIND="$SYS/bus/i2c/drivers/$POLLED/bind"
P_UNBIND="$SYS/bus/i2c/drivers/$POLLED/unbind"
PARAM="$SYS/module/$POLLED/parameters/poll_interval_ms"

log() { echo "tt_touch_bind: $*"; }
# Informational only. A denied/short write here must NEVER cause a fallback, so it is the last
# action of every path and its status is dropped.
say() { "$SETPROP" "$PROP" "$1" >/dev/null 2>&1 || log "setprop $PROP=$1 DENIED (bind unchanged)"; }
# Every privileged operation goes through su:0 (nested when init already started us as root).
rsh() { "$SU" 0 /system/bin/sh -c "$1"; }

cur() {
    [ -L "$DEV_DIR/driver" ] || { echo ""; return; }
    d=$(readlink "$DEV_DIR/driver" 2>/dev/null)
    echo "${d##*/}"
}
param_ok() {
    [ -r "$PARAM" ] || return 1
    [ "$(cat "$PARAM" 2>/dev/null)" = "$INTERVAL" ]
}
# repair: put the device back on the built-in driver, exact client only. Returns non-zero and
# SAYS SO when the rebind does not take -- the caller must not report success on top of that.
restore_builtin() {
    log "recovery: rebinding $DEV to $BUILTIN"
    if rsh "echo $DEV > $B_BIND" >/dev/null 2>&1; then
        return 0
    fi
    log "recovery: REBIND FAILED -- $DEV may be left with no driver"
    return 1
}
# Remove the new module ONLY when it is not bound. If it is bound it is a working touch driver:
# unbind it first, and if it refuses to release, leave it alone -- never rmmod a busy driver.
remove_polled() {
    if [ "$(cur)" = "$POLLED" ]; then
        rsh "echo $DEV > $P_UNBIND" >/dev/null 2>&1
    fi
    if [ "$(cur)" != "$POLLED" ]; then
        "$SU" 0 /system/bin/rmmod "$POLLED" >/dev/null 2>&1
    fi
}
# report a failure: attempt the builtin repair, and if it does not take, say so in the property
# rather than reporting a bare failure that implies the device is fine.
fail() {
    if restore_builtin; then say "$1"; else say "$1:restore-failed"; fi
}

STARTED=0
cleanup() {
    [ "$STARTED" = 1 ] || return
    c=$(cur)
    case "$c" in
        "$POLLED"|"$BUILTIN") : ;;      # a working touch driver is bound; leave it
        "")                             # 2-004b left unbound -> repair, and be loud if it fails
            restore_builtin || log "recovery: LEFT UNBOUND -- see $PROP" ;;
        *) : ;;                         # foreign driver: preserve, not ours to fight
    esac
}
trap cleanup EXIT INT TERM HUP

# 1. bounded wait for the client (init.insmod.sh runs in early-init, so normally instant).
n=0
while [ "$n" -lt 20 ]; do
    [ -d "$DEV_DIR" ] && break
    "$SLEEP" 1
    n=$((n+1))
done
if [ ! -d "$DEV_DIR" ]; then
    log "no $DEV after ${n}s"
    say "failed:no-device"
    exit 0
fi
STARTED=1

c=$(cur)
case "$c" in
    "$POLLED")
        # already correct: verify the param, do NOT churn a live driver.
        if param_ok; then say "success:$POLLED"; else say "failed:param"; fi
        exit 0 ;;
    "$BUILTIN"|"") : ;;
    *)
        log "foreign driver '$c' bound -- leaving it"
        say "failed:foreign:$c"
        exit 0 ;;
esac

# 2. unbind ONLY the exact client. Never a wildcard, never another address on bus 2.
if [ "$c" = "$BUILTIN" ]; then
    if ! rsh "echo $DEV > $B_UNBIND" >/dev/null 2>&1; then
        say "failed:unbind:$BUILTIN"        # builtin is still bound: nothing to repair
        exit 0
    fi
fi

# 3. load the polled module; its OF match auto-attaches to the now-unbound client.
if ! "$SU" 0 /system/bin/insmod "$MOD" poll_interval_ms="$INTERVAL" >/dev/null 2>&1; then
    fail "failed:insmod"
    exit 0
fi

# 4. bounded wait for the auto-bind, then ONE explicit bind attempt if the OF match did not fire.
n=0
while [ "$n" -lt 3 ]; do
    [ "$(cur)" = "$POLLED" ] && break
    "$SLEEP" 1
    n=$((n+1))
done
if [ "$(cur)" != "$POLLED" ]; then
    rsh "echo $DEV > $P_BIND" >/dev/null 2>&1
    n=0
    while [ "$n" -lt 3 ]; do
        [ "$(cur)" = "$POLLED" ] && break
        "$SLEEP" 1
        n=$((n+1))
    done
fi
if [ "$(cur)" != "$POLLED" ]; then
    remove_polled
    fail "failed:nobind"
    exit 0
fi

# 5. success ONLY when the new driver is really bound AND its param is 20.
if param_ok; then say "success:$POLLED"; else say "failed:param"; fi
exit 0

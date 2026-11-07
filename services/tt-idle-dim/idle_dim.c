/*
 * tt-idle-dim -- ThermaTouch panel idle-dim / touch-restore daemon.
 *
 * Native arm64 binary (no APK, no Java). Behaviour:
 *   - read-only evdev listener (find-by-name preferred, retry every 2s)
 *   - NO EVIOCGRAB, NO SoC suspend, NO kernel power writes, NO input masking,
 *     NO CAN, NO Settings changes
 *   - never dims unless the listener is OPEN (blind dim can't be undone)
 *   - re-reads the real brightness immediately BEFORE every dim and restores
 *     that validated value (0..max_brightness), so user brightness changes are
 *     captured; if the read fails it does NOT dim
 *   - first physical EV_ABS / BTN touch restores at once; if the input node is
 *     lost while dimmed it restores at once too, and does not report dim again
 *     until the node reopens
 *   - SIGTERM/SIGINT restore brightness and exit
 *
 * Usage:
 *   idle_dim --input /dev/input/event1 \
 *            --brightness /sys/class/backlight/backlight/brightness \
 *            --idle-seconds 120 --dim 8 [--bright 71] \
 *            --status /data/local/tmp/tt-idle-dim.status
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <dirent.h>
#include <sys/epoll.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <linux/prctl.h>
#include <linux/input.h>
#include "idle_logic.h"
#include "hv_can.h"
#include "playback_control.h"

#define DEF_INPUT   "/dev/input/event1"
#define DEF_BRIGHT  "/sys/class/backlight/backlight/brightness"
#define DEF_STATUS  "/data/local/tmp/tt-idle-dim.status"
#define REOPEN_MS        2000
#define TICK_MS          1000
#define STATUS_MS        1000
#define BRIGHT_RETRY_MS  2000

static volatile sig_atomic_t g_stop;
static long long g_boot_id;

/* HydroVive follows the panel's dim state. File scope so the brightness
 * transition helper can reach them; only main() writes hv_fd. */
static int hv_enabled = 1;
static int hv_fd = -1;
static const char *hv_iface_arg = NULL;
static unsigned long hv_mutes, hv_unmutes;
static unsigned long hv_mute_fail, hv_unmute_fail;   /* failed dispatches */
static unsigned long hv_reasserts;   /* app lifted the mute, we put it back */
static int hv_lift_seen;             /* set while draining, acted on after the
                                      * state machine has run for this tick */
#define HV_REOPEN_MS 2000            /* retry the bus at most every 2 s */
static void on_signal(int sig) { (void)sig; g_stop = 1; }

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int read_int_file(const char *path, int *out) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    char b[32];
    ssize_t n = read(fd, b, sizeof b - 1);
    close(fd);
    if (n <= 0) return -1;
    b[n] = '\0';
    char *end = NULL;
    long v = strtol(b, &end, 10);
    if (end == b) return -1;
    *out = (int)v;
    return 0;
}

static int write_int_file(const char *path, int val) {
    /* O_TRUNC matters: a shorter value written over a longer one would otherwise
     * leave trailing digits (8 over 71 read back as 81). sysfs tolerates O_TRUNC --
     * the shell does exactly this -- and regular files need it. */
    int fd = open(path, O_WRONLY | O_TRUNC | O_CLOEXEC);
    if (fd < 0) return -1;
    char b[16];
    int n = snprintf(b, sizeof b, "%d", val);
    ssize_t w = write(fd, b, (size_t)n);
    int saved = errno;
    close(fd);
    if (w != (ssize_t)n) { errno = saved; return -1; }
    return 0;
}

static int read_text_file(const char *path, char *out, size_t n) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t r = read(fd, out, n - 1);
    close(fd);
    if (r <= 0) return -1;
    out[r] = '\0';
    return (int)r;
}

/* /proc/sys/kernel/random/boot_id -> FNV-1a over the WHOLE uuid (not a prefix),
 * masked to 63 bits so it is always >= 0 and can never collide with the -1
 * "unknown" sentinel. Two reads in one boot match; after a reboot they differ,
 * which is exactly the guard the restart-safety check needs. */
static long long read_boot_id(void) {
    int fd = open("/proc/sys/kernel/random/boot_id", O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    char b[64];
    ssize_t n = read(fd, b, sizeof b - 1);
    close(fd);
    if (n <= 0) return -1;
    unsigned long long h = 1469598103934665603ULL;
    for (int i = 0; i < (int)n; i++) {
        h ^= (unsigned char)b[i];
        h *= 1099511628211ULL;
    }
    return (long long)(h & 0x7fffffffffffffffULL);
}

/* max_brightness lives beside brightness in the same backlight dir. */
static void derive_max_path(const char *br, char *out, size_t n) {
    const char *slash = strrchr(br, '/');
    if (!slash) { snprintf(out, n, "max_brightness"); return; }
    snprintf(out, n, "%.*smax_brightness", (int)(slash - br + 1), br);
}

/* Atomic status: write <path>.tmp then rename() over <path>. */
static void write_status(const char *path, const char *state, long long lvl,
                         int bright_known, int restore, int dim, int max_bright,
                         int running_bright, int input_open,
                         unsigned long long evcount, const char *input,
                         const char *playback, long long pb_heartbeat,
                         unsigned long hv_m, unsigned long hv_u,
                         unsigned long hv_mf, unsigned long hv_uf) {
    char tmp[256];
    if (snprintf(tmp, sizeof tmp, "%s.tmp", path) >= (int)sizeof tmp) return;
    int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0) return;
    char b[800];
    int n = snprintf(b, sizeof b,
        "state=%s\n"
        "last_activity_ms=%lld\n"
        "bright_known=%d\n"
        "restore_bright=%d\n"
        "dim_bright=%d\n"
        "max_bright=%d\n"
        "running_bright=%d\n"
        "touch_events=%llu\n"
        "input=%s\n"
        "input_open=%d\n"
        "pid=%d\n"
        "boot_id=%016llx\n"
        "heartbeat_ms=%lld\n"
        "playback=%s\n"
        "playback_heartbeat_ms=%lld\n"
        "hv_mutes=%lu\n"
        "hv_unmutes=%lu\n"
        "hv_mute_fail=%lu\n"
        "hv_unmute_fail=%lu\n"
        "hv_reasserts=%lu\n",
        state, lvl, bright_known, restore, dim, max_bright,
        running_bright, evcount, input, input_open, (int)getpid(), g_boot_id,
        now_ms(), playback, pb_heartbeat,
        hv_m, hv_u, hv_mf, hv_uf, hv_reasserts);
    if (n > 0) { ssize_t w = write(fd, b, (size_t)n); (void)w; }
    close(fd);
    if (rename(tmp, path) != 0) unlink(tmp);
}

static int find_by_name(const char *want, char *out, size_t outsz) {
    DIR *d = opendir("/dev/input");
    if (!d) return -1;
    struct dirent *e;
    int rc = -1;
    while ((e = readdir(d)) != NULL) {
        if (strncmp(e->d_name, "event", 5) != 0) continue;
        char p[320];
        snprintf(p, sizeof p, "/dev/input/%s", e->d_name);
        int fd = open(p, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) continue;
        char nm[256] = {0};
        if (ioctl(fd, EVIOCGNAME(sizeof nm - 1), nm) >= 0 && strcmp(nm, want) == 0) {
            snprintf(out, outsz, "%s", p);
            rc = 0;
        }
        close(fd);
        if (rc == 0) break;
    }
    closedir(d);
    return rc;
}

static int drain_input(int fd, long long *last_act, int *touched,
                       unsigned long long *count) {
    struct input_event ev[64];
    for (;;) {
        ssize_t n = read(fd, ev, sizeof ev);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
            return -1;
        }
        if (n == 0) return -1;
        int cnt = (int)(n / (ssize_t)sizeof(struct input_event));
        for (int i = 0; i < cnt; i++) {
            if (idle_is_touch_event(ev[i].type, ev[i].code, ev[i].value)) {
                *touched = 1;
                *last_act = now_ms();
                (*count)++;
            }
        }
        if (n < (ssize_t)sizeof ev) return 0;
    }
}

/* Drain the opt-in playback-control channel (stdin). Returns 0 on EAGAIN or a
 * short read, -1 on EOF or a read error (the caller faults the lease and stops
 * watching, without closing fd 0). Complete lines refresh the lease; a partial
 * line stays buffered in *pp so a command split across reads is read whole. */
static int drain_playback(int fd, playback_parser_t *pp, playback_lease_t *lease) {
    char b[128];
    for (;;) {
        ssize_t n = read(fd, b, sizeof b);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
            return -1;
        }
        if (n == 0) return -1;                 /* EOF: the parent is gone */
        long long now = now_ms();

        for (ssize_t i = 0; i < n; i++) {
            playback_line_t ln = playback_parser_byte(pp, (unsigned char)b[i]);
            if (ln != PLAYBACK_LINE_NONE) playback_lease_line(lease, ln, now);
        }
        if ((size_t)n < sizeof b) return 0;
    }
}

static const char *arg_val(const char *a, const char *key,
                           int argc, char **argv, int *i) {
    size_t kl = strlen(key);
    if (strncmp(a, key, kl) != 0) return NULL;
    if (a[kl] == '=') return a + kl + 1;
    if (a[kl] == '\0' && *i + 1 < argc) return argv[++(*i)];
    return NULL;
}

/* HydroVive: send the frame matching a brightness transition that SUCCEEDED.
 * going_dim 1 = panel dimmed, 0 = panel restored. Best effort; a failed send is
 * counted and logged, never retried here. */
static void hv_after_brightness_change(int going_dim)
{
    if (!hv_enabled || hv_fd < 0) return;
    int ok = (hv_can_send_b5(hv_fd, going_dim) == 0);
    if (ok) { if (going_dim) hv_mutes++; else hv_unmutes++; }
    else    { if (going_dim) hv_mute_fail++; else hv_unmute_fail++; }
    fprintf(stderr, "tt-idle-dim: hv: panel %s -> B5 %s %s\n",
            going_dim ? "dimmed" : "restored",
            going_dim ? "mute" : "unmute", ok ? "sent" : "FAILED");
}

int main(int argc, char **argv) {
    const char *in_path = DEF_INPUT, *br_path = DEF_BRIGHT, *st_path = DEF_STATUS;
    const char *want_name = "";
    long idle_seconds = 120;
    int dim = 8, bright_arg = -1, parent_death = 0, playback_stdin = 0;

    for (int i = 1; i < argc; i++) {
        const char *v;
        if ((v = arg_val(argv[i], "--input", argc, argv, &i)))            in_path = v;
        else if ((v = arg_val(argv[i], "--input-name", argc, argv, &i)))  want_name = v;
        else if ((v = arg_val(argv[i], "--brightness", argc, argv, &i)))  br_path = v;
        else if ((v = arg_val(argv[i], "--idle-seconds", argc, argv, &i))) idle_seconds = strtol(v, NULL, 10);
        else if ((v = arg_val(argv[i], "--dim", argc, argv, &i)))         dim = (int)strtol(v, NULL, 10);
        else if ((v = arg_val(argv[i], "--bright", argc, argv, &i)))      bright_arg = (int)strtol(v, NULL, 10);
        else if ((v = arg_val(argv[i], "--status", argc, argv, &i)))      st_path = v;
        else if (strcmp(argv[i], "--parent-death") == 0)                  parent_death = 1;
            else if (strcmp(argv[i], "--playback-stdin") == 0)            playback_stdin = 1;
            else if ((v = arg_val(argv[i], "--hv-iface", argc, argv, &i))) hv_iface_arg = v;
        else { fprintf(stderr, "tt-idle-dim: unknown arg '%s'\n", argv[i]); return 2; }
    }
    long long idle_ms = (long long)idle_seconds * 1000;

    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = on_signal;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);

    /* Opt-in parent-death signal, installed AFTER the SIGTERM handler above so a
     * death signal that arrives immediately is already handled. The init-managed
     * supervisor spawns this daemon as a child; if the supervisor is SIGKILLed at
     * runtime -- which init's cgroup teardown does not cover -- the daemon would be
     * orphaned, possibly holding the panel dimmed with nothing left to restore it.
     * PR_SET_PDEATHSIG delivers SIGTERM to us and the handler restores + exits.
     * Not enabled by default, so a daemon launched by hand from a shell survives
     * that shell exiting. */
    if (parent_death) {
        pid_t ppid_before = getppid();
        if (prctl(PR_SET_PDEATHSIG, SIGTERM, 0, 0, 0) != 0) {
            fprintf(stderr, "tt-idle-dim: PR_SET_PDEATHSIG failed: %s\n", strerror(errno));
        } else if (getppid() != ppid_before) {
            /* The parent died between the two calls, so the death signal may already
             * have been missed: do not linger as an orphan. */
            fprintf(stderr, "tt-idle-dim: parent changed during setup, exiting\n");
            return 0;
        } else {
            fprintf(stderr, "tt-idle-dim: parent-death armed (ppid %d)\n", (int)ppid_before);
        }
    }

    char max_path[256];
    derive_max_path(br_path, max_path, sizeof max_path);
    int max_bright = -1;
    read_int_file(max_path, &max_bright);          /* best effort; -1 == unknown */

    /* Read, never write, brightness at launch -- with one exception for restart
     * safety. A SIGKILL while dimmed leaves the backlight at --dim, and a plain
     * re-read would then mistake that dim value for the brightness to restore to,
     * losing the real value. If our own previous run in THIS boot recorded that it
     * owned the dim, adopt the brightness it cached instead. Otherwise the live
     * reading stands, so a legitimate user brightness is never overridden, and
     * nothing is fabricated. */
    g_boot_id = read_boot_id();
    idle_prior_t prior;
    memset(&prior, 0, sizeof prior);
    {
        char sbuf[1024];
        if (read_text_file(st_path, sbuf, sizeof sbuf) > 0)
            idle_parse_prior(sbuf, &prior);
    }

    int live = -1;
    if (read_int_file(br_path, &live) != 0) live = -1;
    int adopt = idle_startup_restore(&prior, g_boot_id, max_bright, live);

    /* If we still own the dim, we must enter the DIMMED state, not the active
     * one. Merely adopting the value wrote nothing, so the panel stayed at the
     * dim value and the first 120 s idle branch re-read it -- overwriting the
     * real brightness. In the DIMMED state the existing restore rule fires at
     * once (the listener is closed in the common case, so idle_step() returns
     * RESTORE immediately), and idle_commit() keeps us DIMMED until a write
     * actually succeeds, so a failure is retried rather than believed. */
    int owned_dim = idle_prior_owned(&prior, g_boot_id, max_bright, live);

    int restore = -1, bright_known = 0, running_bright = -1;
    if (adopt >= 0) {
        restore = adopt;
        running_bright = adopt;
        bright_known = 1;
    } else if (bright_arg >= 0) {
        restore = bright_arg;
        bright_known = 1;
    }

    idle_state_t state = owned_dim ? IDLE_ST_DIM : IDLE_ST_ACTIVE;
    long long now = now_ms();
    long long last_act = now, last_status = 0, last_bright_try = now;
    unsigned long long evcount = 0;

    int ep = epoll_create1(EPOLL_CLOEXEC);
    if (ep < 0) { perror("epoll_create1"); return 1; }

    int ifd = -1;
    char dev_name[256] = {0};
    long long next_open = 0;
    long long hv_next_open = 0;   /* bus reattach, mirrors the input's retry */

    /* --- opt-in playback-control channel (stdin) --- */
    playback_lease_t pb;
    playback_parser_t pbparse;
    playback_lease_init(&pb, playback_stdin);
    playback_parser_init(&pbparse);
    int sfd = -1;                    /* watched stdin, -1 when absent/closed */
    if (playback_stdin) {
        int fl = fcntl(STDIN_FILENO, F_GETFL, 0);
        if (fl >= 0) fcntl(STDIN_FILENO, F_SETFL, fl | O_NONBLOCK);
        struct epoll_event e3;
        memset(&e3, 0, sizeof e3);
        e3.events = EPOLLIN | EPOLLRDHUP;
        e3.data.fd = STDIN_FILENO;
        if (epoll_ctl(ep, EPOLL_CTL_ADD, STDIN_FILENO, &e3) == 0) {
            sfd = STDIN_FILENO;
        } else {
            /* Cannot watch the control channel: the lease stays UNKNOWN, which
             * inhibits dimming -- the safe answer. */
            fprintf(stderr, "tt-idle-dim: cannot watch playback stdin: %s\n",
                    strerror(errno));
        }
        fprintf(stderr, "tt-idle-dim: playback-stdin armed (initial unknown)\n");
    }

    fprintf(stderr, "tt-idle-dim: input=%s bright=%s max=%d idle=%lldms dim=%d "
                    "bright_known=%d restore=%d status=%s playback=%d\n",
            in_path, br_path, max_bright, idle_ms, dim, bright_known, restore, st_path,
            playback_stdin);

    /* HydroVive: open the speaker bus. tt-can0 is late_start+oneshot and this
     * daemon starts at sys.boot_completed, so the interface may not exist yet;
     * the loop below retries on its existing 1 Hz tick. */
    hv_fd = hv_can_open(hv_iface_arg);
    if (hv_fd >= 0) {
        struct epoll_event eh;
        memset(&eh, 0, sizeof eh);
        eh.events = EPOLLIN;
        eh.data.fd = hv_fd;
        if (epoll_ctl(ep, EPOLL_CTL_ADD, hv_fd, &eh) != 0) {
            fprintf(stderr, "tt-idle-dim: hv: epoll add failed (%s); "
                            "re-mute disabled\n", strerror(errno));
        }
        fprintf(stderr, "tt-idle-dim: hv: %s attached\n",
                hv_iface_arg ? hv_iface_arg : "can0");
    }
    else
        fprintf(stderr, "tt-idle-dim: hv: %s unavailable (%s), retrying\n",
                hv_iface_arg ? hv_iface_arg : "can0", strerror(errno));

    while (!g_stop) {
        /* --- (re)open input; find-by-name preferred, else path --- */
        if (ifd < 0 && now_ms() >= next_open) {
            int fd = -1;
            char found[320] = {0};
            if (want_name[0] && find_by_name(want_name, found, sizeof found) == 0)
                fd = open(found, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
            if (fd < 0 && dev_name[0] && find_by_name(dev_name, found, sizeof found) == 0)
                fd = open(found, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
            /* Only fall back to the fixed path when NO name was requested. With
             * --input-name, a silent path fallback could bind us to an unrelated
             * device, whose panel we would then dim blind. */
            if (fd < 0 && !want_name[0])
                fd = open(in_path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
            if (fd >= 0) {
                char nm[256] = {0};
                int got = (ioctl(fd, EVIOCGNAME(sizeof nm - 1), nm) >= 0 && nm[0]);
                /* Decide on the ACTUAL fd's name, not on what find_by_name saw:
                 * the node can change between the scan and the open. */
                int final_match = (got && want_name[0] && strcmp(nm, want_name) == 0);
                if (!idle_may_attach(want_name[0] ? 1 : 0, final_match)) {
                    close(fd);
                    fd = -1;
                } else if (got) {
                    snprintf(dev_name, sizeof dev_name, "%s", nm);
                }
            }
            if (fd >= 0) {
                struct epoll_event e2;
                memset(&e2, 0, sizeof e2);
                e2.events = EPOLLIN;
                e2.data.fd = fd;
                if (epoll_ctl(ep, EPOLL_CTL_ADD, fd, &e2) == 0) {
                    ifd = fd;
                    last_act = now_ms();   /* rebind: fresh stamp, no instant re-dim */
                    fprintf(stderr, "tt-idle-dim: opened %s (%s)\n", in_path, dev_name);
                } else {
                    close(fd);
                }
            }
            next_open = now_ms() + REOPEN_MS;
        }

        /* --- (re)attach the speaker bus; tt-can0 is late_start, and the bus
         * can also go away underneath us. Same cadence as the input retry. --- */
        if (hv_fd < 0 && hv_enabled && now_ms() >= hv_next_open) {
            int fd = hv_can_open(hv_iface_arg);
            if (fd >= 0) {
                struct epoll_event eh;
                memset(&eh, 0, sizeof eh);
                eh.events = EPOLLIN;
                eh.data.fd = fd;
                if (epoll_ctl(ep, EPOLL_CTL_ADD, fd, &eh) == 0) {
                    hv_fd = fd;
                    fprintf(stderr, "tt-idle-dim: hv: %s attached\n",
                            hv_iface_arg ? hv_iface_arg : "can0");
                } else {
                    close(fd);
                    fprintf(stderr, "tt-idle-dim: hv: epoll add failed (%s)\n",
                            strerror(errno));
                }
            } else {
                fprintf(stderr, "tt-idle-dim: hv: %s unavailable (%s), retrying\n",
                        hv_iface_arg ? hv_iface_arg : "can0", strerror(errno));
            }
            hv_next_open = now_ms() + HV_REOPEN_MS;
        }

        /* --- wait; tick at 1 Hz, or sooner when a reopen is due --- */
        int timeout = TICK_MS;
        if (hv_fd < 0 && hv_enabled) {
            long long d = hv_next_open - now_ms();
            if (d < 0) d = 0;
            if (d < timeout) timeout = (int)d;
        }
        if (ifd < 0) {
            long long d = next_open - now_ms();
            if (d < 0) d = 0;
            if (d < timeout) timeout = (int)d;
            if (timeout < 0) timeout = 0;
        }
        struct epoll_event out[4];
        int n = epoll_wait(ep, out, 4, timeout);

        int touched = 0;
        if (n > 0) {
            for (int i = 0; i < n; i++) {
                if (sfd >= 0 && out[i].data.fd == sfd) {
                    if (drain_playback(sfd, &pbparse, &pb) != 0) {
                        /* Do NOT close fd 0; stop watching and distrust the
                         * parent (EOF is a fault, not an IDLE). */
                        epoll_ctl(ep, EPOLL_CTL_DEL, sfd, NULL);
                        sfd = -1;
                        playback_lease_fault(&pb);
                        fprintf(stderr, "tt-idle-dim: playback stdin EOF/error -> UNKNOWN\n");
                    }
                    continue;
                }
                /* HydroVive: record that the app lifted the mute. The decision
                 * to re-assert is made AFTER the state machine below, so a
                 * touch arriving in the same batch (or a restore later in this
                 * tick) wins and we never mute a lit panel. */
                if (hv_fd >= 0 && out[i].data.fd == hv_fd) {
                    if (out[i].events & (EPOLLERR | EPOLLHUP)) {
                        epoll_ctl(ep, EPOLL_CTL_DEL, hv_fd, NULL);
                        close(hv_fd);
                        hv_fd = -1;
                        hv_next_open = now_ms() + HV_REOPEN_MS;
                        fprintf(stderr, "tt-idle-dim: hv: bus error, will reattach\n");
                    } else if (hv_can_recv_wake(hv_fd)) {
                        hv_lift_seen = 1;
                    }
                    continue;
                }
                if (out[i].data.fd != ifd) continue;
                if (drain_input(ifd, &last_act, &touched, &evcount) != 0) {
                    epoll_ctl(ep, EPOLL_CTL_DEL, ifd, NULL);
                    close(ifd);
                    ifd = -1;
                    next_open = now_ms() + REOPEN_MS;
                    fprintf(stderr, "tt-idle-dim: input lost, retry in %dms\n", REOPEN_MS);
                    /* lost while dimmed: un-dim at once, never wait for a touch */
                    if (state == IDLE_ST_DIM && bright_known &&
                        idle_bright_valid(restore, max_bright) &&
                        write_int_file(br_path, restore) == 0) {
                        state = idle_commit(state, IDLE_ACT_RESTORE, 1);
                        fprintf(stderr, "tt-idle-dim: input lost while dim -> RESTORE %d\n", restore);
                        hv_after_brightness_change(0);
                    }
                }
            }
        }

        long long t = now_ms();
        playback_lease_tick(&pb, t);

        /* --- retry the brightness read (and the declared --bright fallback) --- */
        if (!bright_known && t - last_bright_try >= BRIGHT_RETRY_MS) {
            int cur = -1;
            if (read_int_file(br_path, &cur) == 0 && idle_bright_valid(cur, max_bright)) {
                restore = cur; running_bright = cur; bright_known = 1;
            } else if (bright_arg >= 0) {
                restore = bright_arg; bright_known = 1;
            }
            last_bright_try = t;
        }

        /* While we own the dim, look at the node on the loop's natural 1 Hz -- no
         * extra polling. If it no longer holds what we wrote, someone else has taken
         * the backlight: the framework's own brightness/theme write, or the user.
         * That value is theirs. Adopt it, stand down to ACTIVE and reset the idle
         * clock so we do not immediately dim over it; the normal idle period then
         * re-dims. The node already holds the value, so no write is needed. */
        if (state == IDLE_ST_DIM) {
            int observed = -1;
            if (read_int_file(br_path, &observed) == 0 &&
                idle_external_write_seen(state, observed, dim)) {
                restore = observed;
                running_bright = observed;
                bright_known = 1;
                state = IDLE_ST_ACTIVE;
                last_act = t;
                fprintf(stderr, "tt-idle-dim: external write %d, adopt + ACTIVE\n", observed);
            }
        }

        /* Media-aware suppression, strictly additive: with the feature off,
         * playback_inhibits() is always 0 and this is exactly the old call. */
        int was_dim = (state == IDLE_ST_DIM);
        idle_action_t act;
        if (playback_inhibits(&pb)) {
            /* PLAYING, or no trustworthy word from the parent: never dim; if we
             * had dimmed, restore now rather than wait for a parent that may never
             * speak again. Keep the idle clock fresh while inhibited so that once
             * the parent reports a known IDLE the panel still gets its full idle
             * period before dimming. */
            last_act = t;
            act = (state == IDLE_ST_DIM) ? IDLE_ACT_RESTORE : IDLE_ACT_NONE;
        } else {
            act = idle_step(state, ifd >= 0, bright_known, t, last_act, idle_ms, touched);
        }

        if (act == IDLE_ACT_DIM) {
            /* capture the CURRENT brightness immediately before dimming */
            int cur = -1;
            if (read_int_file(br_path, &cur) == 0 && idle_bright_valid(cur, max_bright)) {
                restore = cur; running_bright = cur; bright_known = 1;
                int ok = (write_int_file(br_path, dim) == 0);
                state = idle_commit(state, act, ok);
                if (ok) {
                    fprintf(stderr, "tt-idle-dim: DIM %d (restore %d)\n", dim, restore);
                    hv_after_brightness_change(1);
                } else {
                    fprintf(stderr, "tt-idle-dim: DIM write failed; speaker untouched\n");
                }
            } else {
                bright_known = 0;          /* unreadable -> never dim blind */
                last_bright_try = t;
                fprintf(stderr, "tt-idle-dim: skip DIM (brightness unreadable)\n");
            }
        } else if (act == IDLE_ACT_RESTORE) {
            int ok = (bright_known && idle_bright_valid(restore, max_bright) &&
                      write_int_file(br_path, restore) == 0);
            state = idle_commit(state, act, ok);
            if (ok) {
                fprintf(stderr, "tt-idle-dim: RESTORE %d\n", restore);
                hv_after_brightness_change(0);
            } else {
                fprintf(stderr, "tt-idle-dim: RESTORE write failed; speaker untouched\n");
            }
        }

        /* HydroVive: the app can lift the mute without touching the backlight
         * (an MQTT "user one"/"user two" command reaches loadUserSettings ->
         * toggleMusicAndSource). Put it back -- but only if the panel was
         * dimmed at the start of this tick AND is still dimmed now: a touch or
         * a restore in the same tick wins, so we never mute a lit panel.
         * No time-based suppression: a second app unmute after our re-mute
         * must still end muted, and the drain in hv_can_recv_wake already
         * coalesces frames that arrived together. */
        if (hv_lift_seen) {
            hv_lift_seen = 0;
            if (hv_fd >= 0 && was_dim && state == IDLE_ST_DIM) {
                if (hv_can_send_b5(hv_fd, 1) == 0) {
                    hv_reasserts++;
                    fprintf(stderr, "tt-idle-dim: hv: app lifted the mute "
                                    "while dim -> B5 mute re-sent\n");
                } else {
                    hv_mute_fail++;
                    fprintf(stderr, "tt-idle-dim: hv: re-mute FAILED\n");
                }
            }
        }

        if (t - last_status >= STATUS_MS) {
            const char *st = (ifd < 0) ? "no_input"
                            : (state == IDLE_ST_DIM ? "dim" : "active");
            write_status(st_path, st, last_act, bright_known, restore, dim, max_bright,
                         running_bright, ifd >= 0, evcount, in_path,
                         playback_lease_name(&pb), pb.heartbeat_ms,
                 hv_mutes, hv_unmutes, hv_mute_fail, hv_unmute_fail);
            last_status = t;
        }
    }

    /* --- SIGTERM/SIGINT: leave the panel bright, then exit --- */
    if (state == IDLE_ST_DIM && bright_known && idle_bright_valid(restore, max_bright)) {
        /* Same rule as every other restore path: the speaker follows a
         * brightness transition that actually succeeded. If the write fails the
         * panel stays dim, so the speaker must stay muted -- leaving it alone is
         * the pre-existing behaviour and is preserved here. */
        if (write_int_file(br_path, restore) == 0)
            hv_after_brightness_change(0);
    }
    write_status(st_path, "exiting", last_act, bright_known, restore, dim, max_bright,
                 running_bright, ifd >= 0, evcount, in_path,
                 playback_lease_name(&pb), pb.heartbeat_ms,
                 hv_mutes, hv_unmutes, hv_mute_fail, hv_unmute_fail);
    if (ifd >= 0) close(ifd);
    close(ep);
    fprintf(stderr, "tt-idle-dim: exiting\n");
    return 0;
}

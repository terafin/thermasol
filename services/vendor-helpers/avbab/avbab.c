/*
 * avbab.c -- read/modify the panel's A/B slot metadata (libavb_ab AvbABData).
 *
 * This is the tool that flips the boot between slots and performs the
 * self-revert. It is deliberately self-contained: it does NOT go through
 * Android's boot HAL, and it does NOT use struct bootloader_control from
 * android_bootloader_message.h -- see WHY below.
 *
 * WHY NOT THE TREE'S STRUCT
 *   The build tree's U-Boot (and fsl_bootctrl.h) uses AOSP's
 *   `struct bootloader_control`, magic BOOT_CTRL_MAGIC 0x42414342.
 *   The PANEL's bootloader (2019, built 2022) uses libavb_ab's AvbABData,
 *   magic "\0AB0". Searching the panel's own bootloader binary for
 *   0x42414342 finds nothing; it contains "\0AB0". Writing the tree's struct
 *   would produce something the panel's bootloader ignores, and the fallback
 *   would silently do nothing. Hence this file's hand-rolled layout.
 *
 * ON-DISK LAYOUT -- offsets are 0-BASED WITHIN THE 32-BYTE BLOB at misc+0x800:
 *   0..4    magic "\0AB0"          (AVB_AB_MAGIC)
 *   4       version_major = 1
 *   5       version_minor = 0
 *   6..8    reserved1[2]
 *   8..12   slot a: priority, tries_remaining, successful_boot, reserved  (4 bytes)
 *   12..16  slot b: same
 *   16..28  reserved2[12]
 *   28..32  crc32, BIG-endian, over bytes 0..27
 * (So slot a is at misc+0x808 and slot b at misc+0x80C, if you're reading raw.)
 *
 * CRC: standard CRC-32 (poly 0xEDB88320 reflected), i.e. what zlib.crc32 and
 * AOSP avb_crc32 both compute, stored big-endian. Confirmed on the panel:
 * zlib.crc32(bytes[0:28]) == 0xdc9dd815 == big-endian read at offset 28;
 * the little-endian read of the same bytes gives 0x15d89ddc and does NOT match.
 *
 * SAFETY
 *   - never writes anything unless the on-disk blob already parses (magic + CRC)
 *   - exclusive flock; refuses to run concurrently
 *   - touches only misc[0x800..0x820); never the BCB at 0, never the U-Boot env
 *   - read-back + CRC re-verify after every write; non-zero exit on mismatch
 *   - mark-successful refuses unless the running slot is the one being marked
 *     (ro.boot.slot_suffix), so it cannot mark the wrong slot good
 *   - logs to /metadata/avbab.log
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/ioctl.h>

/* BLKFLSBUF: flush the block device's page cache. Needed because pwrite+fsync
 * then pread on a block device reads back through the SAME cache our own write
 * just filled -- so without this, "read-back verified" only proves the cache,
 * not the eMMC. Guarded so we don't have to pull in <linux/fs.h>, which
 * collides with other headers. */
#ifndef BLKFLSBUF
#define BLKFLSBUF _IO(0x12, 97)
#endif

#define MISC_DEV   "/dev/block/by-name/misc"
#define AB_OFFSET  0x800
#define AB_LEN     32
#define AB_MAGIC   "\x00\x41\x42\x30"     /* "\0AB0" */
#define AB_VER_MAJOR 1                    /* refuse anything else */
#define CRC_OFF    28
#define MAX_PRIO   15
#define MAX_TRIES  7

static const char *LOG = "/metadata/avbab.log";

static void logmsg(const char *fmt, ...) {
    /* /metadata may not be mounted (it isn't guaranteed on A10), in which case
     * fall back to stderr rather than silently dropping the record. */
    va_list ap; FILE *f = fopen(LOG, "a");
    FILE *out = f ? f : stderr;
    va_start(ap, fmt);
    vfprintf(out, fmt, ap); fputc('\n', out);
    va_end(ap);
    if (f) fclose(f);
}

/* ---- deployment state ------------------------------------------------------------
 * WHY THIS EXISTS AT ALL, and it is a correction to how the guard worked before.
 *
 * The guard used to stand down when slot B's `successful_boot` byte was 1, on the
 * reading that the host had marked it. That byte has a SECOND writer that runs
 * automatically on the panel and has nothing to do with the host:
 *
 *      system/core/rootdir/init.rc:1133-1134   exec_start update_verifier on zygote-start
 *      bootable/recovery/update_verifier/update_verifier.cpp:384
 *                                              module->MarkBootSuccessful()
 *      libboot_control.cpp (patched for \0AB0)  sets successful_boot=1, tries=0
 *
 * and that call at :384 is UNCONDITIONAL in practice: the only thing that can skip it
 * is vold reporting checkpoint support (:379-383), which needs virtual A/B, which this
 * panel does not have. The care-map verification above it (:360-367) is skipped with a
 * warning when no care map exists. So on EVERY boot the panel marks itself successful,
 * the guard sees successful_boot==1, and it stands down believing the host approved.
 *
 * Net effect: the guard could never fire for the case it exists for -- a slot that boots
 * but is unreachable. It was not a wrong idea, it was reading a flag with two writers.
 *
 * So approval is now a file the host writes, and it is scoped to ONE boot: it must name
 * the boot_id it approves, so an approval from an earlier boot cannot satisfy a later one.
 * Nothing that runs automatically on the panel writes this file.
 *
 * AND THE ARM. Outside a deployment the guard must be inert: a cable fault or any ordinary
 * reboot must not be able to disarm a healthy B, because disarming B falls back to A, and
 * A is blind. The host arms a deployment explicitly before it writes anything, and the
 * guard exits immediately if it finds no arm.
 */
/* /METADATA, NOT /DATA -- a correction to the first version of this fix.
 *
 * /data/tt looked obvious and is wrong on this panel, for a reason only the fstab shows:
 *
 *     fstab.nxp:7   /dev/block/by-name/userdata  /data  f2fs  ... latemount,wait,check,quota,
 *                   formattable,fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized,
 *                   keydirectory=/metadata/vold/metadata_encryption
 *
 * /data is file-based encrypted AND mounted late, while the guard starts at `on boot`. A guard that
 * cannot read its arm file does not fail loudly -- it stands down as if no deployment were armed, in
 * exactly the situation it exists for. Observed for real while testing this: a write to the deploy dir
 * returned "Permission denied", the arm file was therefore absent, and the guard printed
 * "no deployment armed -- standing down" and exited 0. Silent, and indistinguishable from a clean boot.
 *
 * /metadata is the right home, per the same file:
 *
 *     fstab.nxp:23  /dev/block/by-name/metadata /metadata ext4 noatime,nosuid,nodev,discard
 *                   wait,formattable,first_stage_mount,check
 *
 * first_stage_mount puts it up long before `on boot`; it is ext4 with no encryption; and there is ONE
 * of it rather than one per slot, which is what lets the old slot write the arm and the new slot read
 * it. 2 MiB is ample -- /metadata already carries ota, apex, bootstat, gsi and aconfig.
 */
#define DEPLOY_DIR    "/metadata/tt"
#define ARMED_FILE    "/metadata/tt/pending-deploy"
#define APPROVED_FILE "/metadata/tt/deploy-approved"
#define GUARD_LOCK_WAIT_SECS 30
#define GUARD_LOCK_FILE "/metadata/tt/guard.lock"

static int file_exists(const char *p) { struct stat st; return stat(p, &st) == 0; }

static int read_trim(const char *p, char *out, size_t n) {
    FILE *f = fopen(p, "r");
    if (!f) return -1;
    size_t got = fread(out, 1, n - 1, f);
    fclose(f);
    out[got] = '\0';
    while (got > 0 && (out[got-1] == '\n' || out[got-1] == '\r' || out[got-1] == ' '))
        out[--got] = '\0';
    return 0;
}

static int current_boot_id(char *out, size_t n) {
    return read_trim("/proc/sys/kernel/random/boot_id", out, n);
}

static int approved_this_boot(void) {
    char want[64] = "", have[64] = "";
    if (current_boot_id(want, sizeof want) != 0 || want[0] == '\0') return 0;
    if (read_trim(APPROVED_FILE, have, sizeof have) != 0) return 0;
    return strcmp(want, have) == 0;
}

/* ---- standard CRC-32 (reflected, poly 0xEDB88320), zlib-compatible ---- */
static uint32_t crc32_buf(const uint8_t *p, size_t n) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        c ^= p[i];
        for (int k = 0; k < 8; k++)
            c = (c >> 1) ^ (0xEDB88320u & (-(int32_t)(c & 1)));
    }
    return c ^ 0xFFFFFFFFu;
}

static uint32_t be32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8)  |  (uint32_t)p[3];
}
static void put_be32(uint8_t *p, uint32_t v) {
    p[0] = (v >> 24) & 0xFF; p[1] = (v >> 16) & 0xFF;
    p[2] = (v >> 8) & 0xFF;  p[3] = v & 0xFF;
}

struct slot { const char *name; int off; };
static const struct slot SLOTS[2] = { { "a", 8 }, { "b", 12 } };

static void decode(const uint8_t *b) {
    printf("  magic      = %02x %02x %02x %02x  (\"\\0AB0\" expected)\n",
           b[0], b[1], b[2], b[3]);
    printf("  version    = %u.%u   reserved1 = %02x %02x\n",
           b[4], b[5], b[6], b[7]);
    for (int i = 0; i < 2; i++) {
        int o = SLOTS[i].off;
        printf("  slot %s   : priority=%u tries_remaining=%u successful_boot=%u\n",
               SLOTS[i].name, b[o], b[o+1], b[o+2]);
    }
    printf("  crc32_be   = 0x%08x   (computed 0x%08x)  %s\n",
           be32(b + CRC_OFF), crc32_buf(b, CRC_OFF),
           be32(b + CRC_OFF) == crc32_buf(b, CRC_OFF) ? "VALID" : "MISMATCH");
}

static int valid(const uint8_t *b) {
    /* version_major is checked too: refuse an unknown future format rather
     * than writing through it. */
    return memcmp(b, AB_MAGIC, 4) == 0 &&
           b[4] == AB_VER_MAJOR &&
           be32(b + CRC_OFF) == crc32_buf(b, CRC_OFF);
}

static int current_slot(void) {
    FILE *f = fopen("/proc/cmdline", "r");
    char line[4096]; int r = -1;
    if (f) {
        if (fgets(line, sizeof line, f)) {
            char *p = strstr(line, "androidboot.slot_suffix=_");
            if (p) r = (p[26] == 'b') ? 1 : 0;
        }
        fclose(f);
    }
    return r;
}

static int read_ab(int fd, uint8_t *b) {
    if (pread(fd, b, AB_LEN, AB_OFFSET) != AB_LEN) {
        fprintf(stderr, "short read at 0x%x: %s\n", AB_OFFSET, strerror(errno));
        return -1;
    }
    return 0;
}

/* Drop the device's page cache for our range. Without this the read-back is
 * served from the cache our own pwrite just populated, so "verified" would
 * prove the cache and nothing about the eMMC. */
static int drop_cache(int fd) {
    if (ioctl(fd, BLKFLSBUF, 0) == 0) return 0;
    if (posix_fadvise(fd, AB_OFFSET, AB_LEN, POSIX_FADV_DONTNEED) == 0) return 0;
    return -1;
}

static int write_and_verify(int fd, const uint8_t *b) {
    uint8_t rb[AB_LEN];
    put_be32((uint8_t *)(b + CRC_OFF), crc32_buf(b, CRC_OFF));
    if (pwrite(fd, b, AB_LEN, AB_OFFSET) != AB_LEN) {
        fprintf(stderr, "write failed: %s\n", strerror(errno));
        return -1;
    }
    fsync(fd);
    /* If the cache can't be dropped we say so, rather than reporting a
     * verification we can't stand behind. */
    if (drop_cache(fd) != 0) {
        fprintf(stderr, "WARNING: could not drop page cache -- read-back is NOT "
                        "trustworthy\n");
        logmsg("WARNING: cache drop failed; read-back not trustworthy");
    }
    if (read_ab(fd, rb) != 0) return -1;
    if (memcmp(rb, b, AB_LEN) != 0 || !valid(rb)) {
        fprintf(stderr, "READ-BACK MISMATCH -- metadata is NOT verified\n");
        logmsg("READ-BACK MISMATCH");
        return -1;
    }
    return 0;
}

/* Make `keep` (0 = A, 1 = B) authoritative and the other slot unbootable.
 * successful_boot REQUIRES tries 0 -- successful with tries>0 is the illegal state that
 * libavb_ab's normalisation treats as unbootable -- and the other slot at {0,0,0} is its
 * canonical unbootable state. */
static int make_authoritative(int fd, uint8_t *b, int keep) {
    int other = 1 - keep;
    memset(&b[SLOTS[keep].off], 0, 4);
    b[SLOTS[keep].off + 0] = MAX_PRIO;
    b[SLOTS[keep].off + 1] = 0;
    b[SLOTS[keep].off + 2] = 1;
    memset(&b[SLOTS[other].off], 0, 4);
    return write_and_verify(fd, b);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr,
          "usage: avbab <cmd>\n"
          "  check                 read, decode, verify CRC (no write)\n"
          "  identical-rewrite     write the SAME bytes back with recomputed CRC\n"
          "  flip-b [tries]        A -> 14, B := priority 15, tries (default 4), unsuccessful\n"
          "  revert-a              A := {15, 0, successful}; B := unbootable  (self-revert)\n"
          "  revert-b              B := {15, 0, successful}; A := unbootable  (self-revert)\n"
          "  mark-successful       mark the RUNNING slot successful (tries->0)\n"
          "  arm-deploy <a|b>      host: arm a deployment window for that slot (default b)\n"
          "  approve               host: approve THIS boot after verifying eth0/adbd/\n"
          "                        ThermaSol/can0 -- this is what disarms the guard\n"
          "  guard <slot> <secs>   INERT unless a deployment for THIS slot is armed: after\n"
          "                        <secs>, disarm the running slot unless the host wrote an\n"
          "                        approval naming this boot's boot_id. Reverts to the OTHER slot.\n");
        return 2;
    }

    /* AVBAB_MISC allows running against a dumped image for offline testing.
     * Unset on the panel, so the real partition is used there. */
    const char *dev = getenv("AVBAB_MISC");
    if (!dev || !*dev) dev = MISC_DEV;
    int fd = open(dev, O_RDWR);
    if (fd < 0) { fprintf(stderr, "open %s: %s\n", dev, strerror(errno)); return 1; }
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
        fprintf(stderr, "another avbab run holds the lock -- refusing\n");
        close(fd); return 1;
    }

    uint8_t b[AB_LEN];
    if (read_ab(fd, b) != 0) { close(fd); return 1; }

    printf("=== current misc[0x800..0x820) ===\n");
    decode(b);
    if (!valid(b)) {
        /* Refuse to touch anything we cannot parse: overwriting an
         * unrecognised blob is how you lose a fallback. */
        fprintf(stderr, "REFUSING: on-disk metadata does not parse "
                        "(magic / version_major / CRC32). Not writing.\n");
        logmsg("REFUSING: unparseable metadata");
        close(fd); return 1;
    }

    if (strcmp(argv[1], "check") == 0) { close(fd); return 0; }

    if (strcmp(argv[1], "identical-rewrite") == 0) {
        printf("--- step 2: byte-identical rewrite (CRC should recompute to the same value)\n");
        uint8_t copy[AB_LEN]; memcpy(copy, b, AB_LEN);
        if (write_and_verify(fd, copy) != 0) { close(fd); return 1; }
        printf("identical rewrite verified; CRC unchanged = %s\n",
               be32(copy + CRC_OFF) == 0xdc9dd815u ? "yes (0xdc9dd815)" : "NO -- STOP, decode is wrong");
        logmsg("identical-rewrite ok");
        close(fd); return 0;
    }

    if (strcmp(argv[1], "flip-b") == 0) {
        /* One semantic change only: B becomes higher priority than A by one.
         * A is left exactly as it is, still marked successful, so it remains
         * the fallback. If B never marks itself successful, its 2 tries are
         * consumed and U-Boot returns to A. */
        int tries = (argc > 2) ? atoi(argv[2]) : 4;
        if (tries < 1 || tries > MAX_TRIES) {
            fprintf(stderr, "tries must be 1..%d (got %d)\n", MAX_TRIES, tries);
            close(fd); return 2;
        }
        b[SLOTS[1].off + 0] = MAX_PRIO;         /* b.priority        */
        b[SLOTS[1].off + 1] = (uint8_t)tries;   /* b.tries_remaining */
        b[SLOTS[1].off + 2] = 0;             /* b.successful_boot       */
        b[SLOTS[1].off + 3] = 0;             /* b.reserved              */
        if (b[SLOTS[0].off + 0] >= MAX_PRIO) /* ensure A is strictly lower */
            b[SLOTS[0].off + 0] = MAX_PRIO - 1;
        printf("--- flip-b: writing B{pri %u, tries %u, successful 0}, A{pri %u}\n",
               b[SLOTS[1].off], b[SLOTS[1].off + 1], b[SLOTS[0].off]);
        if (write_and_verify(fd, b) != 0) { close(fd); return 1; }
        printf("flip-b written and verified\n");
        logmsg("flip-b written");
        close(fd); return 0;
    }

    if (strcmp(argv[1], "arm-deploy") == 0) {
        /* The host calls this BEFORE it writes anything, so the guard knows the next boot
         * of B is a deployment attempt rather than an ordinary reboot. */
        char bid[64] = "";
        const char *target = (argc > 2) ? argv[2] : "b";
        mkdir(DEPLOY_DIR, 0755);
        unlink(APPROVED_FILE);          /* a stale approval must not satisfy a new arm */
        FILE *f = fopen(ARMED_FILE, "w");
        if (!f) { fprintf(stderr, "cannot write %s: %s\n", ARMED_FILE, strerror(errno)); close(fd); return 1; }
        fprintf(f, "%s\n", target);
        fclose(f);
        current_boot_id(bid, sizeof bid);
        printf("--- arm-deploy: %s written for slot %s (arming from boot %s)\n",
               ARMED_FILE, target, bid);
        logmsg("arm-deploy: deployment armed by host");
        close(fd); return 0;
    }

    if (strcmp(argv[1], "approve") == 0) {
        /* The host calls this AFTER it has verified the new slot: eth0, adbd, ThermaSol,
         * can0. That verification is the whole point -- it is the judgement the panel cannot
         * make about itself. The file names THIS boot, so it cannot be replayed later. */
        char bid[64] = "";
        mkdir(DEPLOY_DIR, 0755);
        if (current_boot_id(bid, sizeof bid) != 0 || bid[0] == '\0') {
            fprintf(stderr, "cannot read boot_id\n"); close(fd); return 1;
        }
        FILE *f = fopen(APPROVED_FILE, "w");
        if (!f) { fprintf(stderr, "cannot write %s: %s\n", APPROVED_FILE, strerror(errno)); close(fd); return 1; }
        fprintf(f, "%s\n", bid);
        fclose(f);
        printf("--- approve: %s now approves boot %s\n", APPROVED_FILE, bid);
        logmsg("approve: boot %s approved by host", bid);
        close(fd); return 0;
    }

    if (strcmp(argv[1], "revert-a") == 0 || strcmp(argv[1], "revert-b") == 0) {
        /* revert-x makes slot x authoritative and the other slot unbootable.
         * revert-b matters as much as revert-a now that a deployment can target either slot:
         * a deployment to A that comes up unreachable has to be able to hand the record back
         * to B, which is the known-good. */
        int keep = (argv[1][7] == 'b') ? 1 : 0;
        printf("--- %s: %s{pri %u, tries 0, successful 1}, %s unbootable\n",
               argv[1], SLOTS[keep].name, MAX_PRIO, SLOTS[1 - keep].name);
        if (make_authoritative(fd, b, keep) != 0) { close(fd); return 1; }
        printf("%s written and verified\n", argv[1]);
        logmsg("%s written", argv[1]);
        close(fd); return 0;
    }

    if (strcmp(argv[1], "mark-successful") == 0) {
        int cur = current_slot();
        if (cur < 0) {
            fprintf(stderr, "cannot determine running slot -- refusing\n");
            close(fd); return 1;
        }
        /* libavb_ab: successful==1 WITH tries>0 is an ILLEGAL state that makes
         * the slot unbootable. mark_slot_successful clears tries when setting
         * the flag. Do exactly that, and nothing else. */
        printf("--- mark-successful: running slot is %s\n", SLOTS[cur].name);
        if (b[SLOTS[cur].off] == 0) {
            fprintf(stderr, "slot %s is unbootable (priority 0) -- refusing\n", SLOTS[cur].name);
            close(fd); return 1;
        }
        b[SLOTS[cur].off + 1] = 0;   /* tries_remaining = 0   */
        b[SLOTS[cur].off + 2] = 1;   /* successful_boot = 1   */
        if (write_and_verify(fd, b) != 0) { close(fd); return 1; }
        printf("slot %s marked successful and verified\n", SLOTS[cur].name);
        logmsg("marked slot %s successful", SLOTS[cur].name);
        close(fd); return 0;
    }

    if (strcmp(argv[1], "guard") == 0) {
        /* THE SELF-REVERT. Runs from init, on slot B only.
         *
         * It does NOT judge health. It cannot see the network, and a booting
         * device deciding whether it is reachable is the wrong shape anyway.
         * Instead it WITHHOLDS THE ARM: the host marks B successful once its
         * gates pass, and if that has not happened by the deadline, B is
         * disarmed so the next boot goes to A.
         *
         * ONE-WAY BY DESIGN. tries=0 with successful=0 makes libavb_ab treat
         * the slot as unbootable, and mark_slot_successful refuses an
         * unbootable slot. A guard that fires ENDS THAT ATTEMPT: recovery is a
         * re-flip (avbab flip-b) from the host or from A -- NOT marking it
         * successful. Do not try to rescue a disarmed B by marking it good and
         * then conclude the tool is broken.
         *
         * The deadline must EXCEED time-to-healthy, because a first boot
         * includes dex2oat and the host still has to verify eth0 + adbd +
         * ThermaSol + can0 before it marks successful. A short deadline
         * punishes a healthy B by disarming it.
         */
        int secs = (argc > 3) ? atoi(argv[3]) : 0;
        const char *slot = (argc > 2) ? argv[2] : "";
        if (secs < 1) { fprintf(stderr, "guard needs a positive deadline\n"); close(fd); return 2; }

        /* ONE GUARD PER BOOT.
         *
         * The record lock is released across sleep() so approve/flip-b can run
         * while the guard waits. That would otherwise let a second `guard`
         * start concurrently. This advisory lock covers the guard's whole
         * lifetime and is unrelated to the record: a different resource with a
         * different lifetime, which is what the original code conflated. */
        mkdir(DEPLOY_DIR, 0755);
        int glock = open(GUARD_LOCK_FILE, O_RDWR | O_CREAT, 0644);
        if (glock >= 0 && flock(glock, LOCK_EX | LOCK_NB) != 0) {
            printf("--- guard: another guard is already running (%s) -- refusing\n",
                   GUARD_LOCK_FILE);
            close(glock); close(fd); return 0;
        }
        /* WHICH SLOT WE ARE ON. Guarding only B was right while A held the vendor's Android 10
         * and B was the only deployment target. It is wrong now that either slot can be the one
         * being deployed: a guard that stands down on A leaves an A deployment with no net. */
        int running;
        if (strcmp(slot, "_b") == 0 || strcmp(slot, "b") == 0) running = 1;
        else if (strcmp(slot, "_a") == 0 || strcmp(slot, "a") == 0) running = 0;
        else { printf("--- guard: unrecognised slot (%s) -- standing down\n", slot); close(fd); return 0; }
        /* INERT UNLESS A DEPLOYMENT IS ARMED. Without this gate an ordinary reboot during
         * a cable fault would disarm a healthy B after the deadline, and the fallback is
         * A -- which is blind. The guard exists to judge a deployment, not to police boots. */
        if (!file_exists(ARMED_FILE)) {
            printf("--- guard: no deployment armed (%s absent) -- standing down\n", ARMED_FILE);
            close(fd); return 0;
        }
        /* An arm for the OTHER slot must not be acted on by this boot: if A was the target and A
         * never booted, we are on the known-good B, and B needs no reverting. The tries ladder
         * covers the never-booted case; this guard covers the booted-but-unreachable one. */
        {
            char armed[64] = "";
            read_trim(ARMED_FILE, armed, sizeof armed);
            if (armed[0] != '\0') {
                int want = (armed[0] == 'b' || armed[0] == 'B') ? 1 : 0;
                if (want != running) {
                    printf("--- guard: armed for slot %s but running %s -- standing down\n",
                           SLOTS[want].name, SLOTS[running].name);
                    close(fd); return 0;
                }
            }
        }
        printf("--- guard: slot %s, deployment ARMED for %s (%s), deadline %ds\n",
               SLOTS[running].name, SLOTS[running].name, ARMED_FILE, secs);
        fflush(stdout);

        /* RELEASE THE LOCK WHILE WAITING.
         *
         * Holding an exclusive flock across the whole deadline made every other
         * verb fail with "another avbab run holds the lock", including the
         * `approve` this guard is waiting for and the `flip-b` used to return
         * to the other slot. The lock protects a read-modify-write of the
         * record; it does not need to be held while sleeping.
         *
         * Nothing is written between here and the re-read below, so dropping it
         * cannot lose an update. */
        if (flock(fd, LOCK_UN) != 0) {
            fprintf(stderr, "--- guard: could not release the lock: %s\n", strerror(errno));
            close(fd); return 1;
        }
        sleep((unsigned)secs);

        /* RE-ACQUIRE, then decide from the CURRENT record.
         *
         * BOUNDED RETRY, NOT ONE NON-BLOCKING ATTEMPT.
         *
         * A single LOCK_NB attempt here means an unrelated short holder -- an
         * `approve`, a `flip-b`, a `check` -- makes the guard silently abandon
         * the deadline and leave the deployment armed. That is the one outcome
         * this verb exists to prevent, so losing the race must not be silent.
         *
         * Try immediately (the common case), then poll for a bounded time.
         * If the bound expires the holder is genuinely stuck, and that is
         * reported as a failure rather than swallowed. */
        int lk_rc = flock(fd, LOCK_EX | LOCK_NB);
        if (lk_rc != 0) {
            printf("--- guard: record lock busy at the deadline; waiting up to %ds\n",
                   GUARD_LOCK_WAIT_SECS);
            fflush(stdout);
            logmsg("guard: lock busy at deadline; waiting up to %ds",
                   GUARD_LOCK_WAIT_SECS);
            /* Bounded poll rather than a blocking flock: a blocking call has no
             * timeout, so a holder that dies without releasing would hang the
             * guard past its deadline indefinitely. Polling keeps the bound
             * explicit and lets us report a real failure. */
            int waited_ms = 0;
            while (lk_rc != 0 && waited_ms < GUARD_LOCK_WAIT_SECS * 1000) {
                usleep(100 * 1000);
                waited_ms += 100;
                lk_rc = flock(fd, LOCK_EX | LOCK_NB);
            }
        }
        if (lk_rc != 0) {
            fprintf(stderr,
                    "--- guard: could NOT acquire the record lock within %ds -- "
                    "the deployment is still armed and nothing was reverted\n"
                    "    (this is a failure, not an idle stand-down; the host must "
                    "run the guard again or revert by hand)\n",
                    GUARD_LOCK_WAIT_SECS);
            logmsg("guard: FAILED to acquire the lock within %ds; nothing reverted",
                   GUARD_LOCK_WAIT_SECS);
            close(fd); return 1;
        }
        if (read_ab(fd, b) != 0 || !valid(b)) {
            fprintf(stderr, "--- guard: no valid blob -- refusing to write\n");
            close(fd); return 1;
        }
        /* THE APPROVAL IS A FILE, NOT THE RECORD'S FLAG. Reading successful_boot here was
         * the bug: update_verifier sets it on every boot (:384), so it says nothing about
         * whether the host could reach this slot. */
        if (approved_this_boot()) {
            printf("--- guard: host approved THIS boot (%s names it) -- standing down\n", APPROVED_FILE);
            logmsg("guard: host approved this boot; standing down");
            unlink(APPROVED_FILE);
            unlink(ARMED_FILE);
            close(fd); return 0;
        }
        /* HAS THE RECORD ALREADY MOVED AWAY FROM US?
         *
         * flip-b, revert-b, or another guard may have rewritten the record while
         * this one slept. If our slot is no longer the higher priority, the host
         * has already made a decision and this guard must not overwrite it --
         * otherwise an approval-then-return sequence would be clobbered by a
         * late fire. */
        {
            int my_prio   = b[SLOTS[running].off + 0];
            int peer_prio = b[SLOTS[1 - running].off + 0];
            if (peer_prio > my_prio) {
                printf("--- guard: record already moved to %s (prio %d > %d) -- "
                       "standing down without writing\n",
                       SLOTS[1 - running].name, peer_prio, my_prio);
                logmsg("guard: record already redirected to %s; stood down",
                       SLOTS[1 - running].name);
                unlink(ARMED_FILE);
                close(fd); return 0;
            }
        }
        printf("--- guard: no host approval for this boot after %ds -- DISARMING %s\n"
               "    (the host approves by running: avbab approve, after it has verified\n"
               "     eth0 + adbd + ThermaSol + can0 on the NEW slot. If you are reading this\n"
               "     because a deployment failed, recovery is a re-flip from A or the host --\n"
               "     NOT marking it successful, which mark-successful will refuse anyway.)\n",
               secs, SLOTS[running].name);
        if (make_authoritative(fd, b, 1 - running) != 0) { close(fd); return 1; }
        printf("--- guard: self-revert written and verified -- %s authoritative, %s unbootable\n",
               SLOTS[1 - running].name, SLOTS[running].name);
        logmsg("guard fired: %s disarmed, %s authoritative",
               SLOTS[running].name, SLOTS[1 - running].name);
        unlink(ARMED_FILE);
        close(fd); return 0;
    }

    fprintf(stderr, "unknown command: %s\n", argv[1]);
    close(fd); return 2;
}

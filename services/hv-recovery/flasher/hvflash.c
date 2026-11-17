/* hvflash — HydroVive ceiling-unit firmware writer, mirroring the vendor
 * libthermacan-android.so update path (hvlsr_start_bootloader,
 * hvlsr_bootloader_load_firmware, send_flash_page/hvlsr_program_page,
 * hvlsr_complete_update_and_restart). Dry run by default: prints every frame.
 * Writing needs BOTH --write and a sha256 of the image as --expect (checked
 * by the caller) so a wrong file cannot be flashed by accident. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <linux/can.h>
#include <linux/can/raw.h>

#define PAGE 2048
static int s = -1, dry = 1;

static void msleep(int ms) { struct timespec t = { ms / 1000, (ms % 1000) * 1000000L }; nanosleep(&t, NULL); }
static long now_ms(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000 + t.tv_nsec / 1000000; }

static int tx(unsigned id, const unsigned char *d, int n) {
    struct can_frame f; memset(&f, 0, sizeof f); f.can_id = id; f.can_dlc = n; memcpy(f.data, d, n);
    if (dry) { printf("TX %03X [%d]", id, n); for (int i = 0; i < n; i++) printf(" %02X", d[i]); printf("\n"); return 0; }
    for (int tries = 0; tries < 50; tries++) {
        if (write(s, &f, sizeof f) == sizeof f) return 0;
        if (errno != ENOBUFS && errno != EAGAIN) break;
        msleep(1);
    }
    fprintf(stderr, "tx %03X failed: %s\n", id, strerror(errno)); return -1;
}

/* bootloader state from 0x100 frames, exactly as process_msg decodes them */
static int st_status = -1, st_resend = 0, st_ack = 0;
static void pump(int ms) {
    long end = now_ms() + ms;
    if (dry) { msleep(0); return; }
    for (;;) {
        long left = end - now_ms(); if (left < 0) left = 0;
        struct timeval tv = { left / 1000, (left % 1000) * 1000 };
        setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
        struct can_frame f;
        ssize_t r = read(s, &f, sizeof f);
        if (r == sizeof f && (f.can_id & CAN_SFF_MASK) == 0x100) {
            printf("RX 100 [%d]", f.can_dlc); for (int i = 0; i < f.can_dlc; i++) printf(" %02X", f.data[i]); printf("\n");
            if (f.data[0] == 4) st_resend = 1;
            else { st_status = f.data[2]; if (f.data[7]) st_ack = 1; }
        }
        if (now_ms() >= end) return;
    }
}
static int wait_status(int want, int ms) {
    long end = now_ms() + ms;
    if (dry) { printf("   (wait for bootloader status %d)\n", want); return 0; }
    while (now_ms() < end) { if (st_status == want) return 0; pump(50); }
    fprintf(stderr, "timeout waiting for bootloader status %d (last %d)\n", want, st_status); return -1;
}

static int send_page(const unsigned char *img, int len, int page) {
    unsigned crc = 0; unsigned char d[8];
    for (int off = 0; off < PAGE; off += 4) {
        d[0] = page; d[1] = off >> 8; d[2] = off & 0xff; d[3] = 0x69;
        for (int i = 0; i < 4; i++) { int p = page * PAGE + off + i; d[4 + i] = p < len ? img[p] : 0; }
        if (tx(0x102, d, 8)) return -1;
        crc ^= (unsigned)d[4] << 24 | (unsigned)d[5] << 16 | (unsigned)d[6] << 8 | d[7];
        if (!dry) msleep(2);
        if (dry && off >= 8 && off < PAGE - 8) { if (off == 8) printf("   ... %d more 0x102 frames ...\n", PAGE / 4 - 4); }
    }
    d[0] = 5; d[1] = page; d[2] = crc >> 24; d[3] = crc >> 16; d[4] = crc >> 8; d[5] = crc;
    st_ack = 0; st_resend = 0;
    return tx(0x101, d, 6);
}

int main(int argc, char **argv) {
    const char *path = NULL; int write_mode = 0, resume = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--write")) write_mode = 1;
        else if (!strcmp(argv[i], "--resume")) resume = 1;
        else path = argv[i];
    }
    /* --probe: send ONE bootloader handshake frame (0x101 01) and print every 0x100 reply for 5 s */
    for (int i = 1; i < argc; i++) if (!strcmp(argv[i], "--probe")) {
        dry = 0;
        s = socket(PF_CAN, SOCK_RAW, CAN_RAW); if (s < 0) { perror("socket"); return 4; }
        struct ifreq ifr; memset(&ifr, 0, sizeof ifr); strcpy(ifr.ifr_name, "can0");
        if (ioctl(s, SIOCGIFINDEX, &ifr) < 0) { perror("can0"); return 4; }
        struct can_filter flt = { 0x100, CAN_SFF_MASK }; setsockopt(s, SOL_CAN_RAW, CAN_RAW_FILTER, &flt, sizeof flt);
        struct sockaddr_can a; memset(&a, 0, sizeof a); a.can_family = AF_CAN; a.can_ifindex = ifr.ifr_ifindex;
        if (bind(s, (struct sockaddr *)&a, sizeof a) < 0) { perror("bind"); return 4; }
        pump(1500); unsigned char d = 1; tx(0x101, &d, 1); pump(5000);
        printf("probe: last status %d ack %d resend %d\n", st_status, st_ack, st_resend); return 0;
    }
    if (!path) { fprintf(stderr, "usage: hvflash [--write|--resume|--probe] image.bin\n"); return 2; }
    FILE *fp = fopen(path, "rb"); if (!fp) { perror(path); return 2; }
    static unsigned char img[256 * 1024]; int len = fread(img, 1, sizeof img, fp); fclose(fp);
    /* sanity: an STM32 image for this unit — SP in SRAM, reset vector in bank-1 flash, thumb */
    unsigned sp = img[0] | img[1] << 8 | img[2] << 16 | (unsigned)img[3] << 24;
    unsigned rv = img[4] | img[5] << 8 | img[6] << 16 | (unsigned)img[7] << 24;
    if (len < 4096 || (sp & 0xFFF00000) != 0x20000000 || (rv & 0xFFF00001) != 0x08000001 || (rv & ~1u) >= 0x08000000u + len) {
        fprintf(stderr, "refusing: not a HydroVive application image (len %d sp %08x reset %08x)\n", len, sp, rv); return 3;
    }
    int pages = len / PAGE + 2;          /* the vendor count: hvlsr_bootloader_load_firmware returns 2 + len/2048 */
    printf("image %s: %d bytes, sp %08x, reset %08x, %d pages\n", path, len, sp, rv, pages);
    dry = !write_mode;
    if (!dry) {
        s = socket(PF_CAN, SOCK_RAW, CAN_RAW); if (s < 0) { perror("socket"); return 4; }
        struct ifreq ifr; memset(&ifr, 0, sizeof ifr); strcpy(ifr.ifr_name, "can0");
        if (ioctl(s, SIOCGIFINDEX, &ifr) < 0) { perror("can0"); return 4; }
        struct can_filter flt = { 0x100, CAN_SFF_MASK }; setsockopt(s, SOL_CAN_RAW, CAN_RAW_FILTER, &flt, sizeof flt);
        struct sockaddr_can a; memset(&a, 0, sizeof a); a.can_family = AF_CAN; a.can_ifindex = ifr.ifr_ifindex;
        if (bind(s, (struct sockaddr *)&a, sizeof a) < 0) { perror("bind"); return 4; }
    }
    /* hvlsr_start_bootloader */
    static const unsigned char bc[4] = { 0xA5, 0xBC, 0x7B, 0x01 };
    if (!resume) {
        if (tx(0x101, bc, 4) || tx(0x131, bc, 4)) return 5;
        pump(250);
        if (wait_status(1, 10000)) return 6;
    } else {
        /* resume/catch: the unit is (or is about to be) in its bootloader. Wait for its
         * status-1 announcement for up to CATCH_S seconds, then continue the handshake. */
        int catch_s = getenv("CATCH_S") ? atoi(getenv("CATCH_S")) : 2;
        if (wait_status(1, catch_s * 1000)) { printf("resume: no bootloader status (last %d)\n", st_status); return 6; }
        printf("resume: bootloader status 1 seen\n");
    }
    /* hvlsr_bootloader_load_firmware handshake */
    { unsigned char d = 1; tx(0x101, &d, 1); }
    if (wait_status(2, 10000)) return 6;
    { unsigned char d = 2; tx(0x101, &d, 1); }
    if (wait_status(3, 30000)) return 6;
    /* hvlsr_program_page: 10 x 40 ms for the ack, resend on request */
    for (int p = 0; p < pages; p++) {
        if (send_page(img, len, p)) return 7;
        int ok = dry;
        for (int t = 0; t < 10 && !ok; t++) {
            pump(40);
            if (st_ack) { ok = 1; break; }
            if (st_resend) { printf("   page %d: resend requested\n", p); if (send_page(img, len, p)) return 7; }
        }
        if (!ok) { fprintf(stderr, "page %d: no ack — stopping BEFORE complete/restart\n", p); return 8; }
        if (!dry) printf("page %d/%d ok\n", p + 1, pages);
    }
    /* hvlsr_complete_update_and_restart */
    { unsigned char d = 3; tx(0x101, &d, 1); d = 4; tx(0x101, &d, 1); }
    printf(dry ? "dry run complete — nothing was sent\n" : "update complete; unit restarting\n");
    return 0;
}

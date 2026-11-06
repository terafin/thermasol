/* hv_can.c -- HydroVive CAN transport. See hv_can.h. */
#include <string.h>
#include <stddef.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/can.h>
#include <linux/can/raw.h>

#include "hv_can.h"

#define HV_CAN_ID     0x131
#define HV_DEFAULT_IF "can0"

int hv_can_open(const char *ifname)
{
    if (!ifname || !*ifname) ifname = HV_DEFAULT_IF;
    int fd = socket(PF_CAN, SOCK_RAW, CAN_RAW);
    if (fd < 0) return -1;
    struct ifreq ifr;
    memset(&ifr, 0, sizeof ifr);
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ - 1);
    if (ioctl(fd, SIOCGIFINDEX, &ifr) < 0) { int e = errno; close(fd); errno = e; return -1; }
    struct sockaddr_can addr;
    memset(&addr, 0, sizeof addr);
    addr.can_family  = AF_CAN;
    addr.can_ifindex = ifr.ifr_ifindex;
    if (bind(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        int e = errno; close(fd); errno = e; return -1;
    }

    /* Watch only the panel's command id, and never our own transmissions:
     * the whole re-mute check depends on not hearing ourselves. */
    struct can_filter flt;
    flt.can_id   = HV_CAN_ID;
    flt.can_mask = CAN_SFF_MASK;
    if (setsockopt(fd, SOL_CAN_RAW, CAN_RAW_FILTER, &flt, sizeof flt) < 0) {
        int e = errno; close(fd); errno = e; return -1;
    }
    int own = 0;
    if (setsockopt(fd, SOL_CAN_RAW, CAN_RAW_RECV_OWN_MSGS, &own, sizeof own) < 0) {
        int e = errno; close(fd); errno = e; return -1;
    }
    return fd;
}

int hv_can_send_b5(int fd, int mute)
{
    if (fd < 0) { errno = EBADF; return -1; }
    struct can_frame f;
    memset(&f, 0, sizeof f);
    f.can_id  = HV_CAN_ID;
    f.can_dlc = 8;
    f.data[0] = 0xA5;
    f.data[1] = 0xB5;
    f.data[2] = 0x7B;
    f.data[3] = mute ? 0x01 : 0x00;     /* data[4..7] stay 0: no volume, no source */
    return (write(fd, &f, sizeof f) == (ssize_t)sizeof f) ? 0 : -1;
}

int hv_can_recv_wake(int fd)
{
    if (fd < 0) return 0;
    int woke = 0;
    for (;;) {
        struct can_frame f;
        ssize_t n = recv(fd, &f, sizeof f, MSG_DONTWAIT);
        if (n < 0) break;                      /* EAGAIN: queue drained */
        if (n < (ssize_t)(offsetof(struct can_frame, data) + 4)) continue;
        if ((f.can_id & CAN_SFF_MASK) != HV_CAN_ID) continue;
        if (f.data[0] != 0xA5 || f.data[2] != 0x7B) continue;
        if (f.data[1] == 0xB5 && f.data[3] == 0x00) woke = 1;   /* unmute */
        else if (f.data[1] == 0xB6)                woke = 1;   /* unmutes, then gain */
    }
    return woke;
}

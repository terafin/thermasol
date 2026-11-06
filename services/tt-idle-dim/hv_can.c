/* hv_can.c -- HydroVive CAN transport. See hv_can.h. */
#include <string.h>
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

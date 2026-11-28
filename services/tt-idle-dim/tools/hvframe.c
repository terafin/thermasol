/* hvframe.c -- emit ONE HydroVive frame and exit.
 *
 * Deliberately not a general CAN tool: the frame is compiled in, so this
 * binary cannot be talked into sending a heat, water, flush or firmware frame.
 * Rebuild it to change the frame.
 */
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/can.h>
#include <linux/can/raw.h>

/* A5 BB 7B 03 6D 00 61 00 -- BB, data[3]=3 (the vendor app's standby),
 * then "ma". Captured from the app itself on 2026-11-06. */
static const unsigned char kFrame[8] = { 0xA5, 0xBB, 0x7B, 0x03, 0x6D, 0x00, 0x61, 0x00 };

int main(void)
{
    int fd = socket(PF_CAN, SOCK_RAW, CAN_RAW);
    if (fd < 0) { write(2, "socket failed\n", 14); return 1; }
    struct ifreq ifr;
    memset(&ifr, 0, sizeof ifr);
    strcpy(ifr.ifr_name, "can0");
    if (ioctl(fd, SIOCGIFINDEX, &ifr) < 0) { write(2, "ifindex failed\n", 15); return 1; }
    struct sockaddr_can a;
    memset(&a, 0, sizeof a);
    a.can_family = AF_CAN;
    a.can_ifindex = ifr.ifr_ifindex;
    if (bind(fd, (struct sockaddr *)&a, sizeof a) < 0) { write(2, "bind failed\n", 12); return 1; }
    struct can_frame f;
    memset(&f, 0, sizeof f);
    f.can_id = 0x131; f.can_dlc = 8;
    memcpy(f.data, kFrame, 8);
    if (write(fd, &f, sizeof f) != (ssize_t)sizeof f) { write(2, "write failed\n", 13); return 1; }
    write(1, "sent 131#A5BB7B036D006100\n", 26);
    return 0;
}

/* hv_can.h -- HydroVive CAN transport for tt-idle-dim.
 *
 * Send-only. Two frames, nothing else: the daemon cannot emit volume,
 * standby, light or heat/water frames through this API.
 */
#ifndef HV_CAN_H
#define HV_CAN_H

int hv_can_open(const char *ifname);   /* ifname NULL -> "can0"; fd or -1 */
int hv_can_send_b5(int fd, int mute);  /* 0x131 A5 B5 7B (mute?01:00) 00 00 00 00 */

#endif

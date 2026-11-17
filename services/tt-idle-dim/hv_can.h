/* hv_can.h -- HydroVive CAN transport for tt-idle-dim.
 *
 * Emits exactly one kind of frame: B5 mute/unmute on the panel's own command
 * id. It cannot emit volume, standby, light or heat/water frames.
 *
 * It also *reads* id 0x131, filtered, for one purpose only: to notice when the
 * ThermaSol app lifts the mute while the panel is dimmed, so the daemon can
 * re-assert it. Own messages are never received (CAN_RAW_RECV_OWN_MSGS off), so
 * the daemon cannot react to its own frames.
 */
#ifndef HV_CAN_H
#define HV_CAN_H

int hv_can_open(const char *ifname);   /* ifname NULL -> "can0"; fd or -1 */
int hv_can_send_b5(int fd, int mute);  /* 0x131 A5 B5 7B (mute?01:00) 00 00 00 00 */

/* Drain queued 0x131 frames; return 1 if any of them would lift the mute
 * (B5 with 0x00, or any B6 -- the firmware unmutes before it writes gain).
 * Never blocks. */
int hv_can_recv_wake(int fd);

#endif

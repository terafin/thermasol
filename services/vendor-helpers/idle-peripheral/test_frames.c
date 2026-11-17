#include <assert.h>
#include <stdio.h>
#include "idle_frames.h"
int main(void){struct can_frame f[3];
 assert(idle_frames(0,f)==3);assert(f[0].can_id==0x131 && f[0].can_dlc==8 && f[0].data[1]==0xb5 && f[0].data[3]==1);
 assert(f[1].can_id==0x131 && f[1].can_dlc==8 && f[1].data[1]==0xb4 && f[1].data[3]==0);
 assert(f[2].can_id==0x131 && f[2].can_dlc==4 && f[2].data[1]==0x5f && f[2].data[3]==255);
 assert(idle_frames(1,f)==1);assert(f[0].data[1]==0xb5&&f[0].data[3]==0);
 assert(idle_frames(3,f)==0);assert(idle_frames(-1,f)==0);
 puts("Strict idle CAN frame whitelist PASS");return 0;}

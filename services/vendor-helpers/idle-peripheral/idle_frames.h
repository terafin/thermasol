#ifndef IDLE_FRAMES_H
#define IDLE_FRAMES_H
#include <linux/can.h>
#include <string.h>
/* Only commands already emitted by the shipped native library and verified on CAN. */
static int idle_frames(int resume,struct can_frame out[3]) {
 if(resume!=0&&resume!=1)return 0;
 memset(out,0,sizeof(struct can_frame)*3);
 out[0].can_id=0x131;out[0].can_dlc=8;out[0].data[0]=0xa5;out[0].data[1]=0xb5;out[0].data[2]=0x7b;out[0].data[3]=resume?0:1;
 if(resume)return 1;
 out[1].can_id=0x131;out[1].can_dlc=8;out[1].data[0]=0xa5;out[1].data[1]=0xb4;out[1].data[2]=0x7b;
 out[2].can_id=0x131;out[2].can_dlc=4;out[2].data[0]=0xa5;out[2].data[1]=0x5f;out[2].data[2]=0x7b;out[2].data[3]=0xff;
 return 3;
}
#endif

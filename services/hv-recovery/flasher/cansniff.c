/* cansniff <ms>: print EVERY frame on can0 (SFF/EFF/RTR) and every error frame, with ms timestamps.
 * Receive-only: never transmits. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <linux/can.h>
#include <linux/can/raw.h>
#include <linux/can/error.h>
static long now_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
int main(int argc,char**argv){
  int ms=argc>1?atoi(argv[1]):10000, quiet120=argc>2;
  int s=socket(PF_CAN,SOCK_RAW,CAN_RAW); struct ifreq ifr; memset(&ifr,0,sizeof ifr); strcpy(ifr.ifr_name,"can0");
  if(ioctl(s,SIOCGIFINDEX,&ifr)<0){perror("can0");return 4;}
  can_err_mask_t em=CAN_ERR_MASK; setsockopt(s,SOL_CAN_RAW,CAN_RAW_ERR_FILTER,&em,sizeof em);
  struct sockaddr_can a; memset(&a,0,sizeof a); a.can_family=AF_CAN; a.can_ifindex=ifr.ifr_ifindex;
  if(bind(s,(struct sockaddr*)&a,sizeof a)<0){perror("bind");return 4;}
  long t0=now_ms(), end=t0+ms; int n=0,e=0;
  while(now_ms()<end){
    long left=end-now_ms(); struct timeval tv={left/1000,(left%1000)*1000}; setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    struct can_frame f; if(read(s,&f,sizeof f)!=sizeof f) continue;
    long t=now_ms()-t0;
    if(f.can_id&CAN_ERR_FLAG){ e++; printf("%6ld ERR id=%08X d=",t,f.can_id&CAN_ERR_MASK); for(int k=0;k<8;k++)printf("%02X",f.data[k]); printf("\n"); continue; }
    n++;
    if(quiet120 && (f.can_id&CAN_SFF_MASK)==0x120 && !(f.can_id&CAN_EFF_FLAG)) continue;
    if(f.can_id&CAN_EFF_FLAG) printf("%6ld %08X%s [%d]",t,f.can_id&CAN_EFF_MASK,(f.can_id&CAN_RTR_FLAG)?"R":"",f.can_dlc);
    else printf("%6ld %03X%s [%d]",t,f.can_id&CAN_SFF_MASK,(f.can_id&CAN_RTR_FLAG)?"R":"",f.can_dlc);
    for(int k=0;k<f.can_dlc&&k<8;k++)printf(" %02X",f.data[k]); printf("\n");
  }
  printf("total frames %d, error frames %d\n",n,e); return 0;
}

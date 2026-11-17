/* hvwatch <logfile>: passive, receive-only CAN watcher for hours. Logs (wall-clock + boottime ms) every
 * frame not from the generator (0x120) or the panel (0x131 / own 0x101 0x102 RTR 0x100), and error
 * frames rate-limited to one summary line per 10 s. Never transmits, never reconfigures can0. */
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
static long bt(void){struct timespec t;clock_gettime(CLOCK_BOOTTIME,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
int main(int argc,char**argv){
  FILE*f=fopen(argc>1?argv[1]:"/data/local/tmp/hvwatch.log","a"); if(!f) return 1; setvbuf(f,NULL,_IOLBF,0);
  int s=-1; long last_err_report=bt(); int errs=0, e_stuff=0, e_form=0, e_bit=0, e_other=0; long frames=0, dev=0;
  for(;;){
    if(s<0){ s=socket(PF_CAN,SOCK_RAW,CAN_RAW); struct ifreq ifr; memset(&ifr,0,sizeof ifr); strcpy(ifr.ifr_name,"can0");
      if(s<0||ioctl(s,SIOCGIFINDEX,&ifr)<0){ if(s>=0)close(s); s=-1; sleep(2); continue; }
      can_err_mask_t em=CAN_ERR_MASK; setsockopt(s,SOL_CAN_RAW,CAN_RAW_ERR_FILTER,&em,sizeof em);
      int z=0; setsockopt(s,SOL_CAN_RAW,CAN_RAW_LOOPBACK,&z,sizeof z);
      struct sockaddr_can a; memset(&a,0,sizeof a); a.can_family=AF_CAN; a.can_ifindex=ifr.ifr_ifindex;
      if(bind(s,(struct sockaddr*)&a,sizeof a)<0){ close(s); s=-1; sleep(2); continue; }
      fprintf(f,"%ld %ld start\n",(long)time(NULL),bt()); }
    struct timeval tv={1,0}; setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    struct can_frame r; ssize_t n=read(s,&r,sizeof r);
    if(n==sizeof r){
      if(r.can_id&CAN_ERR_FLAG){ errs++; if(r.data[2]&0x04) e_stuff++; else if(r.data[2]&0x02) e_form++; else if(r.data[2]&0x18) e_bit++; else e_other++; }
      else { frames++; unsigned id=r.can_id&CAN_SFF_MASK;
        if(!(id==0x120||id==0x131||id==0x101||id==0x102||(id==0x100&&(r.can_id&CAN_RTR_FLAG)))){ dev++;
          fprintf(f,"%ld %ld RX %03X%s [%d]",(long)time(NULL),bt(),id,(r.can_id&CAN_RTR_FLAG)?"R":"",r.can_dlc); for(int i=0;i<r.can_dlc;i++) fprintf(f," %02X",r.data[i]); fprintf(f,"\n"); } }
    }
    if(bt()-last_err_report>=10000){ if(errs) fprintf(f,"%ld %ld errs %d (stuff %d form %d bit %d other %d) frames %ld dev %ld\n",(long)time(NULL),bt(),errs,e_stuff,e_form,e_bit,e_other,frames,dev);
      errs=e_stuff=e_form=e_bit=e_other=0; last_err_report=bt(); }
  }
}

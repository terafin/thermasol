/* hvpoll <secs>: active host-first probe on can0 at whatever rate is configured (100k stock).
 * Every 200 ms: 101#01 (vendor handshake step), every 1 s: 101#A5BC7B01 + 131#A5BC7B01 (vendor
 * bootloader entry) and RTR 0x100. Logs to kmsg every non-0x120/0x131 frame and every error frame.
 * If a 0x100 status-1 arrives, runs the vendor v5 update from /vendor/etc/hv-v5.bin (hvflash logic). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <stdarg.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <linux/can.h>
#include <linux/can/raw.h>
#include <linux/can/error.h>
static int kfd=-1;
static long ms(void){struct timespec t;clock_gettime(CLOCK_BOOTTIME,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
static void klog(const char*f,...){ char b[200]; int n=snprintf(b,sizeof b,"hvpoll: %ld ",ms()); va_list ap; va_start(ap,f); n+=vsnprintf(b+n,sizeof b-n,f,ap); va_end(ap); if(n>(int)sizeof b-2)n=sizeof b-2; b[n++]='\n'; if(kfd<0) kfd=open("/dev/kmsg",O_WRONLY|O_CLOEXEC); if(kfd>=0) write(kfd,b,n); }
int main(int argc,char**argv){
  int secs=argc>1?atoi(argv[1]):140;
  int s=socket(PF_CAN,SOCK_RAW|SOCK_CLOEXEC,CAN_RAW); struct ifreq ifr; memset(&ifr,0,sizeof ifr); strcpy(ifr.ifr_name,"can0");
  if(s<0||ioctl(s,SIOCGIFINDEX,&ifr)<0){ klog("no can0 (%d)",errno); return 1; }
  can_err_mask_t em=CAN_ERR_MASK; setsockopt(s,SOL_CAN_RAW,CAN_RAW_ERR_FILTER,&em,sizeof em);
  struct sockaddr_can a; memset(&a,0,sizeof a); a.can_family=AF_CAN; a.can_ifindex=ifr.ifr_ifindex;
  if(bind(s,(struct sockaddr*)&a,sizeof a)<0){ klog("bind failed %d",errno); return 1; }
  klog("active probe start, %d s",secs);
  long end=ms()+secs*1000L, next=0; int k=0, txfail=0, logged=0, heard=0;
  while(ms()<end){
    if(ms()>=next){ next=ms()+200; k++;
      struct can_frame f; memset(&f,0,sizeof f); f.can_id=0x101; f.can_dlc=1; f.data[0]=1; if(write(s,&f,sizeof f)!=sizeof f) txfail++;
      if(k%5==0){ static const unsigned char bc[4]={0xA5,0xBC,0x7B,0x01}; memset(&f,0,sizeof f); f.can_dlc=4; memcpy(f.data,bc,4);
        f.can_id=0x101; if(write(s,&f,sizeof f)!=sizeof f) txfail++; f.can_id=0x131; if(write(s,&f,sizeof f)!=sizeof f) txfail++;
        memset(&f,0,sizeof f); f.can_id=0x100|CAN_RTR_FLAG; if(write(s,&f,sizeof f)!=sizeof f) txfail++; }
      if(k%50==0) klog("k=%d txfail=%d heard=%d",k,txfail,heard);
    }
    struct timeval tv={0,20000}; setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    struct can_frame r; if(read(s,&r,sizeof r)!=sizeof r) continue;
    if(r.can_id&CAN_ERR_FLAG){ if(logged<60){logged++; klog("ERR %08X %02X%02X%02X%02X",r.can_id&CAN_ERR_MASK,r.data[0],r.data[1],r.data[2],r.data[3]);} continue; }
    unsigned id=r.can_id&CAN_SFF_MASK; if(id==0x120||id==0x131) continue;
    heard++; if(logged<200){ logged++; char b[64]; int n=snprintf(b,sizeof b,"%03X%s [%d]",id,(r.can_id&CAN_RTR_FLAG)?"R":"",r.can_dlc); for(int i=0;i<r.can_dlc;i++) n+=snprintf(b+n,sizeof b-n," %02X",r.data[i]); klog("RX %s",b); }
    if(id==0x100 && r.data[0]!=4 && r.data[2]==1){ klog("BOOTLOADER STATUS 1 -- handing to hvflash"); close(s);
      execl("/vendor/bin/tt_hvflash","tt_hvflash","--write","--resume","/vendor/etc/hv-v5.bin",(char*)0); klog("exec hvflash failed %d",errno); return 2; }
  }
  klog("done: k=%d txfail=%d heard=%d -- switching to passive watch (/data/local/tmp/hvwatch.log)",k,txfail,heard);
  close(s);
  execl("/vendor/bin/tt_hvwatch","tt_hvwatch","/data/local/tmp/hvwatch.log",(char*)0);
  klog("exec tt_hvwatch failed %d",errno); return 0;
}

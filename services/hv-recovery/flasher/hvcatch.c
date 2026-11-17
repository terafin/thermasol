/* hvcatch: run from boot. Logs every CAN frame and error frame with CLOCK_BOOTTIME ms to a file.
 * If a bootloader frame (ID 0x100) is seen, answers with the vendor handshake step 101#01 once per
 * distinct status, exactly as hvlsr_bootloader_load_firmware does, so the unit stays in its
 * bootloader instead of timing out. Sends nothing else. Exits after <secs>. */
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
static long bt_ms(void){struct timespec t;clock_gettime(CLOCK_BOOTTIME,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
int main(int argc,char**argv){
  const char*out=argc>1?argv[1]:"/dev/kmsg"; int secs=argc>2?atoi(argv[2]):180;
  FILE*f=fopen(out,"a"); if(!f) return 1; setvbuf(f,NULL,_IOLBF,0);
  const int km=!strcmp(out,"/dev/kmsg");
  (void)km;
  int s=-1; long end=bt_ms()+secs*1000L; int answered=-1;
  fprintf(f,"hvcatch: %ld start\n",bt_ms());
  while(bt_ms()<end){
    if(s<0){
      s=socket(PF_CAN,SOCK_RAW,CAN_RAW); struct ifreq ifr; memset(&ifr,0,sizeof ifr); strcpy(ifr.ifr_name,"can0");
      if(s<0||ioctl(s,SIOCGIFINDEX,&ifr)<0){ if(s>=0)close(s); s=-1; usleep(20000); continue; }
      can_err_mask_t em=CAN_ERR_MASK; setsockopt(s,SOL_CAN_RAW,CAN_RAW_ERR_FILTER,&em,sizeof em);
      int on=1; setsockopt(s,SOL_CAN_RAW,CAN_RAW_FD_FRAMES,&on,sizeof on);
      struct sockaddr_can a; memset(&a,0,sizeof a); a.can_family=AF_CAN; a.can_ifindex=ifr.ifr_ifindex;
      if(bind(s,(struct sockaddr*)&a,sizeof a)<0){close(s);s=-1;usleep(20000);continue;}
      fprintf(f,"hvcatch: %ld bound\n",bt_ms());
    }
    struct timeval tv={0,200000}; setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    struct canfd_frame fr; memset(&fr,0,sizeof fr); ssize_t r=read(s,&fr,sizeof fr);
    if(r!=CAN_MTU && r!=CANFD_MTU) continue; int isfd=(r==CANFD_MTU); int dl=fr.len;
    long t=bt_ms(); unsigned id=fr.can_id;
    if(id&CAN_ERR_FLAG){ fprintf(f,"hvcatch: %ld ERR %08X %02X%02X%02X%02X%02X%02X%02X%02X\n",t,id&CAN_ERR_MASK,fr.data[0],fr.data[1],fr.data[2],fr.data[3],fr.data[4],fr.data[5],fr.data[6],fr.data[7]); continue; }
    unsigned sid=id&CAN_SFF_MASK;
    if(sid==0x120||sid==0x131) continue;                      /* steam generator chatter */
    {char b[300];int n=snprintf(b,sizeof b,"hvcatch: %ld %03X%s%s [%d]",t,sid,(id&CAN_RTR_FLAG)?"R":"",isfd?(fr.flags&CANFD_BRS?" FD+BRS":" FD"):"",dl); for(int k=0;k<dl&&k<64;k++)n+=snprintf(b+n,sizeof b-n," %02X",fr.data[k]); fprintf(f,"%s\n",b);}
    if(sid==0x100 && fr.data[0]!=4 && fr.data[2]==1 && answered!=1){
      struct canfd_frame h; memset(&h,0,sizeof h); h.can_id=0x101; h.len=1; h.data[0]=1; if(isfd) h.flags=fr.flags&CANFD_BRS;
      int w=write(s,&h,isfd?CANFD_MTU:CAN_MTU); answered=1; fprintf(f,"hvcatch: %ld TX 101#01%s (%s)\n",bt_ms(),isfd?" FD":"",w>0?"ok":"fail");
    }
  }
  fprintf(f,"hvcatch: %ld end\n",bt_ms()); return 0;
}

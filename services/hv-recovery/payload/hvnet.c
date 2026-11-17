/* initshim — first-stage /init wrapper for the TT10V2 boot ramdisk.
 * Parent: exec the real first-stage init (/system/bin/init.real) immediately, argv/env untouched.
 * Child : as early as can0 exists (mcp251xfd loads in first stage ~4 s), set 100 kbit/s over
 *         rtnetlink, bring it up, and for 150 s listen for the HydroVive CAN bootloader's status-1
 *         announcement (ID 0x100). Only if it announces: run the vendor update sequence
 *         (hvlsr_bootloader_load_firmware / program_page / complete_update_and_restart) with
 *         ThermaSol's published image embedded below. Otherwise send nothing. Log to /dev/kmsg. */
#include <errno.h>
#include <stdarg.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/wait.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <linux/can.h>
#include <linux/can/raw.h>
#include <linux/can/error.h>
#include <linux/can/netlink.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include "hv5.h"
#ifndef HVNET_LISTEN_MS
#define HVNET_LISTEN_MS 20000
#endif
#ifndef HVNPLAN
#define HVNPLAN 1
#endif
#ifndef HVPLAN0
#define HVPLAN0 25000
#endif
#ifndef HVPLAN1
#define HVPLAN1 16666
#endif
#ifndef HVPLAN0_END
#define HVPLAN0_END 6000
#endif
#ifndef HVRATE
#define HVRATE 50000
#endif
#define PAGE 2048
static int kfd = -1;
static long ms(void){struct timespec t;clock_gettime(CLOCK_BOOTTIME,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
static void klog(const char*f,...){ char b[200]; int n=snprintf(b,sizeof b,"hvshim: %ld ",ms()); va_list ap; va_start(ap,f); n+=vsnprintf(b+n,sizeof b-n,f,ap); va_end(ap);
  if(n>(int)sizeof b-2)n=sizeof b-2; b[n++]='\n'; if(kfd<0) kfd=open("/dev/kmsg",O_WRONLY|O_CLOEXEC); if(kfd>=0) write(kfd,b,n); }
static void msleep(int m){struct timespec t={m/1000,(m%1000)*1000000L};nanosleep(&t,NULL);}

/* rtnetlink: set can0 bittiming (100k, 0.875) and admin-up */
static int nl_can_set(int ifindex,unsigned bitrate,int lo){
  { int d=socket(AF_INET,SOCK_DGRAM|SOCK_CLOEXEC,0); struct ifreq f; memset(&f,0,sizeof f); strcpy(f.ifr_name,"can0"); if(ioctl(d,SIOCGIFFLAGS,&f)==0&&(f.ifr_flags&IFF_UP)){ f.ifr_flags&=~IFF_UP; ioctl(d,SIOCSIFFLAGS,&f);} close(d); msleep(30); }
  int s=socket(AF_NETLINK,SOCK_RAW|SOCK_CLOEXEC,NETLINK_ROUTE); if(s<0) return -1;
  struct { struct nlmsghdr n; struct ifinfomsg i; char buf[256]; } r; memset(&r,0,sizeof r);
  r.n.nlmsg_len=NLMSG_LENGTH(sizeof(struct ifinfomsg)); r.n.nlmsg_type=RTM_NEWLINK; r.n.nlmsg_flags=NLM_F_REQUEST|NLM_F_ACK;
  r.i.ifi_family=AF_UNSPEC; r.i.ifi_index=ifindex;
  #define ADD(type,data,len) do{ struct rtattr*a=(struct rtattr*)((char*)&r+NLMSG_ALIGN(r.n.nlmsg_len)); a->rta_type=(type); a->rta_len=RTA_LENGTH(len); if(len) memcpy(RTA_DATA(a),data,len); r.n.nlmsg_len=NLMSG_ALIGN(r.n.nlmsg_len)+RTA_ALIGN(a->rta_len);}while(0)
  struct rtattr*li=(struct rtattr*)((char*)&r+NLMSG_ALIGN(r.n.nlmsg_len)); ADD(IFLA_LINKINFO,NULL,0);
  ADD(IFLA_INFO_KIND,"can",3);
  struct rtattr*id=(struct rtattr*)((char*)&r+NLMSG_ALIGN(r.n.nlmsg_len)); ADD(IFLA_INFO_DATA,NULL,0);
  struct can_bittiming bt; memset(&bt,0,sizeof bt);
  /* MCP2518FD 40 MHz: the kernel's auto timing for slow rates picks 175+ TQ/bit and the controller
   * times out entering normal mode. For rates <= 50k give explicit 40 TQ/bit (1+15+19+5), which
   * was verified to come up at 25k and 16.67k on the live bus. */
  if(bitrate<=50000){ bt.tq=1000000000u/(bitrate*40u); bt.prop_seg=15; bt.phase_seg1=19; bt.phase_seg2=5; bt.sjw=4; }
  else { bt.bitrate=bitrate; bt.sample_point=875; }
  ADD(IFLA_CAN_BITTIMING,&bt,sizeof bt);
  struct can_ctrlmode cm; cm.mask=CAN_CTRLMODE_LISTENONLY|CAN_CTRLMODE_BERR_REPORTING; cm.flags=((lo!=2)?CAN_CTRLMODE_BERR_REPORTING:0)|(lo==1?CAN_CTRLMODE_LISTENONLY:0); ADD(IFLA_CAN_CTRLMODE,&cm,sizeof cm);
  unsigned rms=(lo==1)?0:100; ADD(IFLA_CAN_RESTART_MS,&rms,4);
  id->rta_len=(char*)&r+r.n.nlmsg_len-(char*)id; li->rta_len=(char*)&r+r.n.nlmsg_len-(char*)li;
  int ok=send(s,&r,r.n.nlmsg_len,0)>0; char ack[512]; int err=0;
  if(ok){ int n=recv(s,ack,sizeof ack,0); struct nlmsghdr*h=(struct nlmsghdr*)ack; if(n>0&&h->nlmsg_type==NLMSG_ERROR) err=((struct nlmsgerr*)NLMSG_DATA(h))->error; }
  close(s); if(!ok||err){ klog("bittiming set failed err=%d",err); return -1; }
  int d=socket(AF_INET,SOCK_DGRAM|SOCK_CLOEXEC,0); struct ifreq f; memset(&f,0,sizeof f); strcpy(f.ifr_name,"can0");
  int up=0, lasterr=0; for(int tr=0;tr<8&&!up;tr++){ if(ioctl(d,SIOCGIFFLAGS,&f)==0){ f.ifr_flags|=IFF_UP; if(ioctl(d,SIOCSIFFLAGS,&f)==0) up=1; else { lasterr=errno; msleep(60);} } } close(d);
  if(!up) klog("ifup %u failed errno %d",bitrate,lasterr);
  return up?0:-1;
}

static int nl_is_listenonly(int ifindex){
  int s=socket(AF_NETLINK,SOCK_RAW|SOCK_CLOEXEC,NETLINK_ROUTE); if(s<0) return -1;
  struct { struct nlmsghdr n; struct ifinfomsg i; } q; memset(&q,0,sizeof q);
  q.n.nlmsg_len=NLMSG_LENGTH(sizeof(struct ifinfomsg)); q.n.nlmsg_type=RTM_GETLINK; q.n.nlmsg_flags=NLM_F_REQUEST; q.i.ifi_family=AF_UNSPEC; q.i.ifi_index=ifindex;
  if(send(s,&q,q.n.nlmsg_len,0)<0){ close(s); return -1; }
  static char buf[8192]; int n=recv(s,buf,sizeof buf,0); close(s); if(n<=0) return -1;
  struct nlmsghdr*h=(struct nlmsghdr*)buf; if(h->nlmsg_type!=RTM_NEWLINK) return -1;
  struct ifinfomsg*ii=NLMSG_DATA(h); int len=h->nlmsg_len-NLMSG_LENGTH(sizeof *ii);
  for(struct rtattr*a=IFLA_RTA(ii); RTA_OK(a,len); a=RTA_NEXT(a,len)) if(a->rta_type==IFLA_LINKINFO){
    int l2=RTA_PAYLOAD(a); for(struct rtattr*b=RTA_DATA(a); RTA_OK(b,l2); b=RTA_NEXT(b,l2)) if(b->rta_type==IFLA_INFO_DATA){
      int l3=RTA_PAYLOAD(b); for(struct rtattr*c=RTA_DATA(b); RTA_OK(c,l3); c=RTA_NEXT(c,l3)) if(c->rta_type==IFLA_CAN_CTRLMODE){
        struct can_ctrlmode*cm=RTA_DATA(c); return (cm->flags&CAN_CTRLMODE_LISTENONLY)?1:0; } } }
  return -1;
}
#include <linux/watchdog.h>
static int wdfd=-1;
static void wdping(void){ if(wdfd>=0) ioctl(wdfd,WDIOC_KEEPALIVE,0); }
static int s=-1, st_status=-1, st_ack=0, st_resend=0, n_err=0, n_rx=0, n_logged=0, n_stuff=0, n_form=0, n_other=0, n_dev=0; static unsigned dev_id=0;
static int tx(unsigned id,const unsigned char*d,int n){ struct can_frame f; memset(&f,0,sizeof f); f.can_id=id; f.can_dlc=n; memcpy(f.data,d,n);
  for(int t=0;t<50;t++){ if(write(s,&f,sizeof f)==sizeof f) return 0; if(errno!=ENOBUFS&&errno!=EAGAIN) break; msleep(1);} klog("tx %03X failed %d",id,errno); return -1; }
static void pump(int m){ wdping(); long end=ms()+m; for(;;){ long left=end-ms(); if(left<0)left=0; struct timeval tv={left/1000,(left%1000)*1000};
  setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv); struct can_frame f; if(read(s,&f,sizeof f)==sizeof f){ if(f.can_id&CAN_ERR_FLAG){ n_err++; if(f.data[2]&0x04) n_stuff++; else if(f.data[2]&0x02) n_form++; else n_other++; if(n_logged<6&&n_err<=1){ n_logged++; klog("ERR %08X %02X%02X%02X%02X%02X%02X%02X%02X",f.can_id&CAN_ERR_MASK,f.data[0],f.data[1],f.data[2],f.data[3],f.data[4],f.data[5],f.data[6],f.data[7]);} if(ms()>=end) return; continue; } n_rx++; unsigned id=f.can_id&CAN_SFF_MASK; if(id!=0x120&&id!=0x131&&id!=0x101&&id!=0x102&&!(id==0x100&&(f.can_id&CAN_RTR_FLAG))){ n_dev++; dev_id=id; }
  if(id!=0x120&&id!=0x131&&n_logged<200){ n_logged++; char b[64]; int n=snprintf(b,sizeof b,"%03X [%d]",id,f.can_dlc); for(int k=0;k<f.can_dlc;k++) n+=snprintf(b+n,sizeof b-n," %02X",f.data[k]); klog("RX %s",b);} 
  if(id==0x100 && !(f.can_id&CAN_RTR_FLAG) && f.can_dlc>=3){ if(f.data[0]==4) st_resend=1; else { st_status=f.data[2]; if(f.can_dlc>=8&&f.data[7]) st_ack=1; } } }
  if(ms()>=end) return; } }
static int wait_status(int want,int m){ long end=ms()+m; while(ms()<end){ if(st_status==want) return 0; pump(50);} return -1; }
static int send_page(int page){ unsigned crc=0; unsigned char d[8]; int len=sizeof HV5;
  for(int off=0;off<PAGE;off+=4){ d[0]=page; d[1]=off>>8; d[2]=off&0xff; d[3]=0x69; for(int i=0;i<4;i++){int p=page*PAGE+off+i; d[4+i]=p<len?HV5[p]:0;}
    if(tx(0x102,d,8)) return -1; crc^=(unsigned)d[4]<<24|(unsigned)d[5]<<16|(unsigned)d[6]<<8|d[7]; msleep(2);} 
  d[0]=5; d[1]=page; d[2]=crc>>24; d[3]=crc>>16; d[4]=crc>>8; d[5]=crc; st_ack=0; st_resend=0; return tx(0x101,d,6); }

static void child(void){
  long t0=ms(); int idx=0;
  while(ms()-t0<15000){ int d=socket(AF_INET,SOCK_DGRAM|SOCK_CLOEXEC,0); struct ifreq f; memset(&f,0,sizeof f); strcpy(f.ifr_name,"can0");
    if(d>=0&&ioctl(d,SIOCGIFINDEX,&f)==0){ idx=f.ifr_ifindex; close(d); break;} if(d>=0) close(d); msleep(5); }
  if(!idx){ klog("can0 never appeared"); return; }
  klog("can0 exists (ifindex %d)",idx);
  s=socket(PF_CAN,SOCK_RAW|SOCK_CLOEXEC,CAN_RAW); struct sockaddr_can a; memset(&a,0,sizeof a); a.can_family=AF_CAN; a.can_ifindex=idx;
  if(s<0||bind(s,(struct sockaddr*)&a,sizeof a)<0){ klog("can socket failed %d",errno); return; }
  can_err_mask_t em=CAN_ERR_MASK; setsockopt(s,SOL_CAN_RAW,CAN_RAW_ERR_FILTER,&em,sizeof em);
  { int z=0; setsockopt(s,SOL_CAN_RAW,CAN_RAW_LOOPBACK,&z,sizeof z); setsockopt(s,SOL_CAN_RAW,CAN_RAW_RECV_OWN_MSGS,&z,sizeof z); }
  /* 100k NORMAL mode, transmit nothing: the panel ACKs every valid frame, so a one-shot announcement
   * is received on its first transmission instead of being retransmitted unseen. */
  int ok=-1; for(int t=0;t<10&&ok;t++){ ok=nl_can_set(idx,100000,0); if(ok) msleep(50); }
  klog("100k normal %s at %ld ms",ok?"FAILED":"up",ms()); if(ok) return;
  long end=ms()+HVNET_LISTEN_MS; int tr=0,te=0;
  while(ms()<end && st_status<0){ n_err=n_rx=n_dev=0; pump(100); tr+=n_rx; te+=n_err; if(n_dev) klog("device frame 0x%03X at %ld ms",dev_id,ms()); }
  klog("listen %ld ms: rx %d err %d status %d",ms(),tr,te,st_status);
  if(st_status!=1){ klog("SUMMARY no bootloader status 1 (status %d)",st_status); return; }
  klog("bootloader status 1 seen: starting vendor update with v5 (%d bytes)",(int)sizeof HV5);
  unsigned char b=1; tx(0x101,&b,1); if(wait_status(2,10000)){ klog("no status 2"); return;}
  b=2; tx(0x101,&b,1); if(wait_status(3,30000)){ klog("no status 3"); return;}
  int pages=(int)sizeof HV5/PAGE+2;
  for(int p=0;p<pages;p++){ if(send_page(p)){ klog("page %d tx fail",p); return;} int ok2=0;
    for(int t=0;t<10&&!ok2;t++){ pump(40); if(st_ack){ok2=1;break;} if(st_resend){ st_resend=0; klog("page %d resend",p); send_page(p);} }
    st_ack=0; if(!ok2){ klog("page %d not acked; stopping before restart",p); return;} klog("page %d/%d ok",p+1,pages); }
  b=3; tx(0x101,&b,1); b=4; tx(0x101,&b,1); klog("update complete; unit restarting"); pump(5000);
}
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/syscall.h>
static void loadmod(const char*p){ int fd=open(p,O_RDONLY|O_CLOEXEC); if(fd<0){klog("open %s failed %d",p,errno);return;} long r=syscall(SYS_finit_module,fd,"",0); klog("insmod %s -> %ld/%d",p,r,r?errno:0); close(fd); }
int main(int argc,char**argv,char**envp){
  mount("devtmpfs","/dev","devtmpfs",0,NULL); mount("proc","/proc","proc",0,NULL); mount("sysfs","/sys","sysfs",0,NULL);
  kfd=open("/dev/kmsg",O_WRONLY|O_CLOEXEC);
  klog("hvnet PID1 start (local payload)");
  wdfd=open("/dev/watchdog",O_WRONLY|O_CLOEXEC);
  if(wdfd>=0){ int to=60; ioctl(wdfd,WDIOC_SETTIMEOUT,&to); wdping(); klog("watchdog armed %d s",to); } else klog("watchdog open failed %d",errno);
  { FILE*f=fopen("/m/modules.load","r"); char ln[128];
    if(f){ while(fgets(ln,sizeof ln,f)){ ln[strcspn(ln,"\r\n")]=0; if(!*ln) continue; char path[160]; snprintf(path,sizeof path,"/m/%s",ln); loadmod(path); wdping(); } fclose(f); }
    else klog("no /m/modules.load"); }
  pid_t p=fork(); if(p==0){ child(); _exit(0); }
  int st; waitpid(p,&st,0);
  klog("hvnet done at %ld ms; rebooting to normal boot",ms()); sync(); msleep(300);
  reboot(RB_AUTOBOOT); for(;;) pause();
}

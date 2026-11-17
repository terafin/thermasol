/* canprobe: send the given frames (ID#HEX, ID#R for remote, ID# for empty) on can0, then print
 * every received frame whose ID is not in the ignore list for <ms> milliseconds.
 * usage: canprobe <ms> [frame...]   — never sends anything not on the command line. */
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
static long now_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000+t.tv_nsec/1000000;}
int main(int argc,char**argv){
  if(argc<2){fprintf(stderr,"usage: canprobe <ms> [ID#HEX...]\n");return 2;}
  int ms=atoi(argv[1]);
  int s=socket(PF_CAN,SOCK_RAW,CAN_RAW); struct ifreq ifr; memset(&ifr,0,sizeof ifr); strcpy(ifr.ifr_name,"can0");
  if(ioctl(s,SIOCGIFINDEX,&ifr)<0){perror("can0");return 4;}
  struct sockaddr_can a; memset(&a,0,sizeof a); a.can_family=AF_CAN; a.can_ifindex=ifr.ifr_ifindex;
  if(bind(s,(struct sockaddr*)&a,sizeof a)<0){perror("bind");return 4;}
  for(int i=2;i<argc;i++){
    struct can_frame f; memset(&f,0,sizeof f); char*h=strchr(argv[i],'#'); if(!h){fprintf(stderr,"bad %s\n",argv[i]);return 2;}
    f.can_id=strtoul(argv[i],NULL,16); h++;
    if(*h=='R'){f.can_id|=CAN_RTR_FLAG;} else { int n=strlen(h)/2; if(n>8)return 2; for(int k=0;k<n;k++){unsigned v; sscanf(h+2*k,"%2x",&v); f.data[k]=v;} f.can_dlc=n; }
    ssize_t w=write(s,&f,sizeof f); printf("TX %s -> %s\n",argv[i], w==sizeof f?"ok":"FAILED");
  }
  long end=now_ms()+ms;
  while(now_ms()<end){
    long left=end-now_ms(); struct timeval tv={left/1000,(left%1000)*1000}; setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    struct can_frame f; if(read(s,&f,sizeof f)!=sizeof f) continue;
    unsigned id=f.can_id&CAN_SFF_MASK; if(id==0x120||id==0x131) continue;
    printf("RX %03X%s [%d]",id,(f.can_id&CAN_RTR_FLAG)?"R":"",f.can_dlc); for(int k=0;k<f.can_dlc;k++)printf(" %02X",f.data[k]); printf("\n");
  }
  return 0;
}

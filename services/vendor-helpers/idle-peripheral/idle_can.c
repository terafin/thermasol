#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/can.h>
#include <linux/can/raw.h>
#include "idle_frames.h"
#define BASE "/data/local/tmp/tt-idle-peripheral"
static long long now_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return (long long)t.tv_sec*1000+t.tv_nsec/1000000;}
static int read_file(const char*p,char*b,size_t n){int f=open(p,O_RDONLY|O_CLOEXEC|O_NOFOLLOW);if(f<0)return -1;ssize_t r=read(f,b,n-1);close(f);if(r<=0||r==(ssize_t)n-1)return -1;b[r]=0;return 0;}
static int field(const char*b,const char*key,char*out,size_t n){size_t k=strlen(key);for(const char*p=b;*p;){const char*e=strchr(p,'\n');if(!e)e=p+strlen(p);if((size_t)(e-p)>k&&p[k]=='='&&!strncmp(p,key,k)){size_t z=e-p-k-1;if(z>=n)return -1;memcpy(out,p+k+1,z);out[z]=0;return 0;}p=*e?e+1:e;}return -1;}
static int atomic_file(const char*p,const char*s){char tmp[256];if(snprintf(tmp,sizeof tmp,"%s.tmp",p)>=(int)sizeof tmp)return -1;int fd=open(tmp,O_WRONLY|O_CREAT|O_TRUNC|O_CLOEXEC|O_NOFOLLOW,0600);if(fd<0)return -1;size_t n=strlen(s);int ok=write(fd,s,n)==(ssize_t)n&&fsync(fd)==0;close(fd);if(!ok||rename(tmp,p))return -1;int parent=open("/data/local/tmp",O_RDONLY|O_DIRECTORY|O_CLOEXEC);if(parent<0)return -1;int synced=fsync(parent);close(parent);return synced;}
static int current_boot(char*out,size_t n){char b[64];if(read_file("/proc/sys/kernel/random/boot_id",b,sizeof b))return -1;unsigned long long h=1469598103934665603ULL;for(size_t i=0;b[i];i++){h^=(unsigned char)b[i];h*=1099511628211ULL;}snprintf(out,n,"%016llx",h&0x7fffffffffffffffULL);return 0;}
int main(int argc,char**argv){
 if(argc!=2||(strcmp(argv[1],"OFF")&&strcmp(argv[1],"RESUME")))return 2;
 int resume=!strcmp(argv[1],"RESUME");
 int lock=open(BASE".lock",O_CREAT|O_RDWR|O_CLOEXEC|O_NOFOLLOW,0600);if(lock<0||flock(lock,LOCK_EX|LOCK_NB))return 3;
 char status[2048],state[32],media[32],stamp[32],boot[32],input[16],liveboot[32],activity[32],ownership[128]={0},cycle[128],result[256];
 if(read_file("/data/local/tmp/tt-idle-dim.status",status,sizeof status)||field(status,"state",state,sizeof state)||field(status,"playback",media,sizeof media)||field(status,"heartbeat_ms",stamp,sizeof stamp)||field(status,"boot_id",boot,sizeof boot)||field(status,"input_open",input,sizeof input)||field(status,"last_activity_ms",activity,sizeof activity)||current_boot(liveboot,sizeof liveboot))return 4;
 char*end;errno=0;long long last=strtoll(stamp,&end,10),now=now_ms();if(errno||*end||last<=0||last>now||now-last>5000||strcmp(boot,liveboot)||strcmp(input,"1"))return 5;
 if(resume?strcmp(media,"playing"):(strcmp(media,"idle")||strcmp(state,"dim")))return 6;
 snprintf(cycle,sizeof cycle,"%s:%s\n",boot,activity);
 read_file(BASE".owned",ownership,sizeof ownership);
 if(resume&&!ownership[0]){snprintf(result,sizeof result,"operation=RESUME\nstatus=no_action_required\nuptime_ms=%lld\n",now);return atomic_file(BASE".status",result)?7:0;}
 if(!resume&&!strcmp(ownership,cycle)){snprintf(result,sizeof result,"operation=OFF\nstatus=idle_light_off_speaker_standby\nuptime_ms=%lld\n",now);return atomic_file(BASE".status",result)?7:0;}
 int fd=socket(PF_CAN,SOCK_RAW|SOCK_CLOEXEC,CAN_RAW);if(fd<0)return 8;
 struct timeval timeout={.tv_sec=1};setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
 struct ifreq ifr={0};strcpy(ifr.ifr_name,"can0");if(ioctl(fd,SIOCGIFINDEX,&ifr)){close(fd);return 9;}
 struct sockaddr_can address={.can_family=AF_CAN,.can_ifindex=ifr.ifr_ifindex};
 if(bind(fd,(struct sockaddr*)&address,sizeof address)){close(fd);return 10;}
 struct can_frame frames[3];int count=idle_frames(resume,frames);
 if(atomic_file(BASE".owned",resume?"unmute_pending\n":"mute_pending\n")){close(fd);return 12;}
 for(int i=0;i<count;i++){
  if(write(fd,&frames[i],sizeof frames[i])!=sizeof frames[i]){close(fd);return 11;}
  if(i+1<count)usleep(50000);
 }
 close(fd);
 if(atomic_file(BASE".owned",resume?"":cycle))return 13;
 snprintf(result,sizeof result,"operation=%s\nstatus=%s\nuptime_ms=%lld\n",argv[1],resume?"media_resumed_owned_mute_cleared":"idle_light_off_speaker_standby",now_ms());
 if(atomic_file(BASE".status",result))return 14;
 puts(result);return 0;
}

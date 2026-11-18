"""Minimal AN3155 USART bootloader emulator of a bricked STM32G474 (device 0x469), served over TCP
like the ESP32 stream-server. Models: flash 512 KB @0x08000000, option bytes @0x1FFF7800 (OPTR+complement),
FLASH_OPTR register mirror @0x40022020. Write Memory to 0x1FFF7800 updates OPTR (as the ROM does)."""
import os,socket,struct,sys,threading
ROMVER=int(os.environ.get('ROMVER','0xD4'),16)
ACK,NACK=0x79,0x1F
FLASH=bytearray(b'\xff'*0x80000)
v5=open(sys.argv[1],'rb').read(); FLASH[:len(v5)]=v5
OPTR=[int(sys.argv[2],16)]
OLD_ROM=len(sys.argv)>3 and sys.argv[3]=='old'
log=open(sys.argv[4] if len(sys.argv)>4 else '/dev/null','a')
# RM0440 cat-3 option words after OPTR (value, then bitwise complement), ST production values:
def _w(v): return struct.pack('<II',v,(~v)&0xffffffff)
OB_FACTORY_REST=_w(0xFFFFFFFF)+_w(0x00FF0000)+_w(0xFF00FFFF)+_w(0xFF00FFFF)+_w(0xFF00FF00)  # PCROP1 start/end, WRP1A, WRP2A, SEC1
OBREST=[bytearray(OB_FACTORY_REST)]
def ob(): v=OPTR[0]; return bytearray(struct.pack('<II',v,(~v)&0xffffffff))+OBREST[0]
def rd(a,n):
    if 0x08000000<=a and a+n<=0x08080000: return bytes(FLASH[a-0x08000000:a-0x08000000+n])
    if 0x1FFF7800<=a and a+n<=0x1FFF7840:
        if OLD_ROM: return None
        return bytes(ob()[a-0x1FFF7800:a-0x1FFF7800+n])
    if a==0x40022020 and n<=4: return struct.pack('<I',OPTR[0])[:n]
    if 0x1FFF6FF0<=a and a+n<=0x1FFF7000: return bytes([ROMVER,0x00]*n)[:n] if a==0x1FFF6FFE else bytes([ROMVER]*n)
    return None
def handle(c):
    f=c.makefile('rwb',buffering=0)
    def r(n):
        b=b''
        while len(b)<n:
            x=f.read(n-len(b))
            if not x: raise EOFError
            b+=x
        return b
    def w(*bs): f.write(bytes(bs))
    def addr():
        d=r(5); 
        if d[4]!=(d[0]^d[1]^d[2]^d[3]): w(NACK); return None
        w(ACK); return struct.unpack('>I',d[:4])[0]
    try:
        while True:
            b=r(1)[0]
            if b==0x7F: w(ACK); log.write('sync\n'); continue
            x=r(1)[0]
            if x!=(b^0xFF): w(NACK); continue
            log.write(f'cmd {b:#04x}\n'); log.flush()
            if b==0x00: w(ACK); w(11,0x31,0x00,0x01,0x02,0x11,0x21,0x31,0x43,0x63,0x73,0x82,0x92,ACK)
            elif b==0x01: w(ACK,0x31,0,0,ACK)
            elif b==0x02: w(ACK,1,0x04,0x69,ACK)
            elif b==0x11:
                w(ACK); a=addr()
                if a is None: continue
                n=r(2); N=n[0]+1
                if n[1]!=(n[0]^0xFF): w(NACK); continue
                d=rd(a,N)
                if d is None: w(NACK); log.write(f'  read NACK {a:#x}\n'); continue
                w(ACK); f.write(d)
            elif b==0x31:
                w(ACK); a=addr()
                if a is None: continue
                N=r(1)[0]+1; d=r(N); ck=r(1)[0]
                cs=N-1
                for y in d: cs^=y
                if cs!=ck: w(NACK); continue
                if 0x1FFF7800<=a<0x1FFF7840:
                    buf=bytearray(b'\xff'*48); buf[a-0x1FFF7800:a-0x1FFF7800+N]=d   # AN3155: OB area erased, then written
                    v,cmp_=struct.unpack_from('<II',buf,0)
                    if cmp_!=(~v)&0xffffffff and N>=8: w(NACK); continue
                    OPTR[0]=v; OBREST[0]=bytearray(buf[8:48]); log.write(f'  OPTR <- {v:#010x} rest_intact={bytes(buf[8:48])==OB_FACTORY_REST}\n'); w(ACK)
                    log.write('  OB reload -> reset\n'); log.flush(); c.close(); return
                elif 0x08000000<=a<0x08080000:
                    FLASH[a-0x08000000:a-0x08000000+N]=d; w(ACK)
                else: w(NACK)
            elif b==0x44:
                w(ACK); hdr=r(2)
                if hdr==b'\xff\xff': r(1); w(ACK)
                else:
                    n=struct.unpack('>H',hdr)[0]+1; r(2*n+1); w(ACK)
            elif b==0x21: w(ACK); a=addr(); w(ACK); return
            else: w(NACK)
    except (EOFError, BrokenPipeError, ConnectionResetError): pass
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('127.0.0.1',int(sys.argv[5]) if len(sys.argv)>5 else 16639)); s.listen(5)
open(sys.argv[4]+'.optr','w').write(hex(OPTR[0])) if len(sys.argv)>4 else None
while True:
    c,_=s.accept(); handle(c)
    if len(sys.argv)>4: open(sys.argv[4]+'.optr','w').write(hex(OPTR[0])); open(sys.argv[4]+'.rest','w').write(OBREST[0].hex())

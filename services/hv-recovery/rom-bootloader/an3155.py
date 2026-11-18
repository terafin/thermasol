#!/usr/bin/env python3
"""Tiny AN3155 (STM32 USART bootloader) client over TCP, for an ESP32 stream-server bridge running 8E1.
Commands: id | read ADDR LEN OUTFILE | write ADDR INFILE. Never erases. Exits non-zero on any NACK/timeout."""
import socket,struct,sys,time
ACK,NACK=0x79,0x1F
class BL:
    def __init__(s,host,port):
        s.s=socket.create_connection((host,port),5); s.s.settimeout(3)
        for _ in range(5):
            s.s.sendall(b'\x7f')
            try:
                b=s.s.recv(1)
                if b and b[0] in (ACK,NACK): return  # NACK = already synced
            except socket.timeout: pass
            time.sleep(0.2)
        raise SystemExit('no answer from ROM bootloader')
    def rx(s,n):
        b=b''
        while len(b)<n:
            x=s.s.recv(n-len(b))
            if not x: raise SystemExit('connection closed')
            b+=x
        return b
    def ack(s,what):
        b=s.rx(1)[0]
        if b!=ACK: raise SystemExit(f'NACK on {what} ({b:#x})')
    def cmd(s,c): s.s.sendall(bytes([c,c^0xFF])); s.ack(f'cmd {c:#x}')
    def addr(s,a):
        d=struct.pack('>I',a); s.s.sendall(d+bytes([d[0]^d[1]^d[2]^d[3]])); s.ack(f'addr {a:#x}')
    def getid(s):
        s.cmd(0x02); n=s.rx(1)[0]+1; pid=s.rx(n); s.ack('getid'); return int.from_bytes(pid,'big')
    def getver(s):
        s.cmd(0x01); v=s.rx(3); s.ack('getver'); return v[0]
    def read(s,a,n):
        out=b''
        while n>0:
            k=min(256,n); s.cmd(0x11); s.addr(a); s.s.sendall(bytes([k-1,(k-1)^0xFF])); s.ack('len')
            out+=s.rx(k); a+=k; n-=k
        return out
    def write(s,a,d):
        s.cmd(0x31); s.addr(a); n=len(d)-1; cs=n
        for x in d: cs^=x
        s.s.sendall(bytes([n])+d+bytes([cs])); s.ack('write data')
if __name__=='__main__':
    h,p,op=sys.argv[1],int(sys.argv[2]),sys.argv[3]
    b=BL(h,p)
    if op=='id': print(f'device_id={b.getid():#06x} bl_version={b.getver():#04x}')
    elif op=='read':
        a=int(sys.argv[4],0); n=int(sys.argv[5],0); open(sys.argv[6],'wb').write(b.read(a,n)); print(f'read {n} bytes @ {a:#x}')
    elif op=='write':
        a=int(sys.argv[4],0); d=open(sys.argv[5],'rb').read(); b.write(a,d); print(f'wrote {len(d)} bytes @ {a:#x}')

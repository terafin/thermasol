#!/usr/bin/env python3
"""Tiny AN3155 (STM32 USART bootloader) client over TCP, for an ESP32 stream-server bridge running 8E1.
Commands: id | read ADDR LEN OUTFILE | write ADDR INFILE | erase-bank1 LEN | write-flash ADDR INFILE.
erase-bank1 only ever erases bank-1 pages (0x08000000-0x0803FFFF); nothing else erases. Exits non-zero on any NACK/timeout."""
import socket,struct,sys,time
ACK,NACK=0x79,0x1F
class BL:
    def __init__(s,host,port):
        s.s=socket.create_connection((host,port),5)
        # AN3155: the ROM autobauds on the first 0x7F after reset and ACKs. Once synced, a lone 0x7F is taken
        # as the first byte of a command: no reply, and the next 0x7F completes a bad pair and gets NACK
        # (stm32flash's stm32_send_init_seq does the same). So a short wait, then resend, and treat NACK as synced.
        s.s.settimeout(1)
        for _ in range(6):
            s.s.sendall(b'\x7f')
            try:
                b=s.s.recv(1)
                if b and b[0] in (ACK,NACK): s.s.settimeout(3); return
            except socket.timeout: pass
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
    def drain(s):
        s.s.settimeout(0.3)
        try:
            while s.s.recv(4096): pass
        except socket.timeout: pass
        finally: s.s.settimeout(3)
    def read_chunk(s,a,k):
        s.cmd(0x11); s.addr(a); s.s.sendall(bytes([k-1,(k-1)^0xFF])); s.ack('len')
        return s.rx(k)
    def read(s,a,n):
        # AN3155 Read Memory has no checksum, so a flipped bit would land in the backup silently.
        # Each 256-byte chunk is accepted only when two consecutive reads agree; a timeout or NACK
        # drains the line and tries again. Six attempts per chunk, then give up.
        out=b''; total=n; start=a
        while n>0:
            k=min(256,n); d=None
            for tries in range(6):
                try:
                    d1=s.read_chunk(a,k); d2=s.read_chunk(a,k)
                except (socket.timeout, SystemExit) as e:
                    print(f'  read @ {a:#x}: {e or "timeout"}; retrying', file=sys.stderr, flush=True)
                    s.drain(); continue
                if d1==d2: d=d1; break
                print(f'  read @ {a:#x}: two reads differ; reading again', file=sys.stderr, flush=True)
            if d is None: raise SystemExit(f'read @ {a:#x}: no two matching reads in 6 attempts')
            out+=d; a+=k; n-=k
            if total>65536 and (a-start)%65536==0: print(f'  {a-start:7d}/{total} bytes', file=sys.stderr, flush=True)
        return out
    def write(s,a,d):
        s.cmd(0x31); s.addr(a); n=len(d)-1; cs=n
        for x in d: cs^=x
        s.s.sendall(bytes([n])+d+bytes([cs])); s.ack('write data')
    def erase_pages(s,pages):
        # AN3155 Extended Erase (0x44): N-1 (2 bytes BE), N page numbers (2 bytes BE each), XOR checksum.
        assert pages and all(0<=p<128 for p in pages), 'only bank-1 pages 0-127 are ever erased here'
        s.cmd(0x44); d=struct.pack('>H',len(pages)-1)+b''.join(struct.pack('>H',p) for p in pages)
        cs=0
        for x in d: cs^=x
        s.s.settimeout(30); s.s.sendall(d+bytes([cs])); s.ack('erase'); s.s.settimeout(3)
    def close(s):
        # Close explicitly so the far end sees EOF now, not when the OS reaps this process: the next
        # an3155.py call opens a new connection, and the bridge must be done with this one first.
        try: s.s.shutdown(socket.SHUT_RDWR)
        except OSError: pass
        s.s.close()
if __name__=='__main__':
    h,p,op=sys.argv[1],int(sys.argv[2]),sys.argv[3]
    b=BL(h,p)
    import atexit; atexit.register(b.close)
    if op=='id': print(f'device_id={b.getid():#06x} bl_version={b.getver():#04x}')
    elif op=='read':
        a=int(sys.argv[4],0); n=int(sys.argv[5],0); open(sys.argv[6],'wb').write(b.read(a,n)); print(f'read {n} bytes @ {a:#x}')
    elif op=='erase-bank1':
        n=int(sys.argv[4],0); pages=list(range((n+0x7FF)//0x800)); b.erase_pages(pages); print(f'erased bank-1 pages 0-{pages[-1]}')
    elif op=='write-flash':
        a=int(sys.argv[4],0); d=open(sys.argv[5],'rb').read(); d+=b'\xff'*(-len(d)%8)
        for o in range(0,len(d),256): b.write(a+o,d[o:o+256])
        print(f'wrote {len(d)} bytes @ {a:#x}')
    elif op=='write':
        a=int(sys.argv[4],0); d=open(sys.argv[5],'rb').read(); b.write(a,d); print(f'wrote {len(d)} bytes @ {a:#x}')

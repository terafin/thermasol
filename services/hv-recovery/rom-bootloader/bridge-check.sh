#!/bin/bash
# Check the ESP32 bridge before wiring it to the amp, so a bridge problem is not mistaken for a ROM one.
# usage: bridge-check.sh <esp32-ip> [port]
HOST=${1:?usage: bridge-check.sh <esp32-ip> [port]}; PORT=${2:-6639}
python3 -I - "$HOST" "$PORT" <<'PY'
import socket,sys,time
h,p=sys.argv[1],int(sys.argv[2])
try: s=socket.create_connection((h,p),5)
except OSError as e: print(f"FAIL: cannot open {h}:{p} ({e}). Is the ESP32 on Wi-Fi with amp-uart.yaml flashed?"); sys.exit(1)
print(f"ok: {h}:{p} accepts a connection")
s.settimeout(1.5); s.sendall(b'\x7f')
try: b=s.recv(64)
except socket.timeout: b=b''
s.close()
if not b: print("ok: nothing answered 0x7F - expected with the amp not wired yet; with it wired, recover.sh should get 0x79"); sys.exit(0)
if b[:1] in (b'\x79',b'\x1f'): print(f"ok: the ROM bootloader answered ({b[0]:#04x}) - the amp is already wired and in the ROM"); sys.exit(0)
print(f"WARN: unexpected bytes {b[:16].hex()} - something else is on the UART or another client is connected"); sys.exit(2)
PY

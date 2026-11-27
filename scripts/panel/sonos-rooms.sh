#!/bin/bash
# Ask the Sonos system itself for every player (no panel, no inference).
# Prints "ip<TAB>name" for every Sonos player SSDP finds that can play (advertises AVTransport):
# one output per amp, no Sonos grouping applied. Boosts and hidden bonded halves cannot play.
# Usage: sonos-rooms.sh > ~/panel-work/expected-rooms.tsv
set -euo pipefail
python3 - <<'PY'
import socket, re, time, urllib.request, html, sys
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2); s.settimeout(1)
msg = (b"M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\n"
       b"MX: 2\r\nST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n\r\n")
for _ in range(2): s.sendto(msg, ("239.255.255.250", 1900))
ips, t = set(), time.time()
while time.time() - t < 4:
    try: _, a = s.recvfrom(4096); ips.add(a[0])
    except socket.timeout: pass
if not ips: sys.exit("no Sonos players answered SSDP")
body = ('<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>'
        '<u:GetZoneGroupState xmlns:u="urn:schemas-upnp-org:service:ZoneGroupTopology:1"/></s:Body></s:Envelope>')
x = None
for ip in sorted(ips):
    try:
        r = urllib.request.Request(f"http://{ip}:1400/ZoneGroupTopology/Control", body.encode(),
            {"Content-Type": 'text/xml; charset="utf-8"',
             "SOAPACTION": '"urn:schemas-upnp-org:service:ZoneGroupTopology:1#GetZoneGroupState"'})
        x = html.unescape(urllib.request.urlopen(r, timeout=6).read().decode()); break
    except Exception: continue
if x is None: sys.exit("no player answered GetZoneGroupState")
rooms = []
for m in re.finditer(r'<ZoneGroupMember ([^>]*?)/?>', x):
    a = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
    ip = re.search(r'//([\d.]+):', a.get("Location", ""))
    name = a.get("ZoneName")
    if not ip or not name: continue
    if ip.group(1) in ips: rooms.append((name, ip.group(1)))
def is_player(ip):
    # a Boost (bridge) or the hidden half of a bonded pair has no AVTransport: it cannot play
    try: d = urllib.request.urlopen(f"http://{ip}:1400/xml/device_description.xml", timeout=4).read().decode()
    except Exception: return True
    return "urn:schemas-upnp-org:service:AVTransport:1" in d
for name, ip in sorted(set(rooms)):
    if is_player(ip): print(f"{ip}\t{name}")
PY

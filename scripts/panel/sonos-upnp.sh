#!/bin/bash
# Minimal Sonos UPnP calls from tellah (no panel). Usage:
#   sonos-upnp.sh <ip> getmute | mute 0|1 | uri      (uri = the transport's current track URI)
set -euo pipefail
IP=${1:?ip}; CMD=${2:?cmd}
call() {  # $1 service path  $2 urn  $3 action  $4 args-xml
  curl -s --max-time 6 -H 'Content-Type: text/xml; charset="utf-8"' -H "SOAPACTION: \"$2#$3\"" \
    -d "<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:$3 xmlns:u=\"$2\">$4</u:$3></s:Body></s:Envelope>" \
    "http://$IP:1400$1"
}
RC=/MediaRenderer/RenderingControl/Control; RCU=urn:schemas-upnp-org:service:RenderingControl:1
AV=/MediaRenderer/AVTransport/Control; AVU=urn:schemas-upnp-org:service:AVTransport:1
case $CMD in
  getmute) call $RC $RCU GetMute "<InstanceID>0</InstanceID><Channel>Master</Channel>" | sed -nE 's/.*<CurrentMute>([01])<.*/\1/p';;
  mute)    call $RC $RCU SetMute "<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredMute>${3:?0|1}</DesiredMute>" >/dev/null
           [ "$("$0" "$IP" getmute)" = "$3" ] || { echo "mute did not take" >&2; exit 1; };;
  uri)     call $AV $AVU GetPositionInfo "<InstanceID>0</InstanceID>" | sed -nE 's/.*<TrackURI>([^<]*)<.*/\1/p' | sed 's/&amp;/\&/g';;
  state)   call $AV $AVU GetTransportInfo "<InstanceID>0</InstanceID>" | sed -nE 's/.*<CurrentTransportState>([^<]*)<.*/\1/p';;
  *) echo "unknown $CMD" >&2; exit 2;;
esac

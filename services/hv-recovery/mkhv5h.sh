#!/bin/sh
# Generate hv5.h (the embedded HydroVive v5 image) from ThermaSol's published firmware.
# The image is ThermaSol's, so it is not in this repo:
#   curl -O http://thermatouch.tsolup.com/firmware/hydrovive/latest.bin   # sha256 37c81d0b...
set -e
in=${1:-latest.bin}; out=${2:-hv5.h}
python3 -I - "$in" "$out" <<'PY'
import sys
b=open(sys.argv[1],'rb').read()
open(sys.argv[2],'w').write('static const unsigned char HV5[%d]={%s};\n'%(len(b),','.join(map(str,b))))
PY

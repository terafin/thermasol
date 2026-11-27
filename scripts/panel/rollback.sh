#!/bin/bash
# Boot back into the known-good slot (_b by default) and confirm.
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
"$(dirname "$0")/swap.sh" "${1:-_b}"

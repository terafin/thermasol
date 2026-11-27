#!/bin/bash
# Boot back into the known-good slot (_b by default) and confirm.
source "$(dirname "$0")/lib.sh"
"$(dirname "$0")/swap.sh" "${1:-_b}"

#!/bin/bash
# Fetch the base images from the published release BASE_RELEASE (lib.sh) and pin them.
# Refuses anything whose sha does not match lib.sh BASE_SHA. Needs gh (GitHub CLI); no panel access.
source "$(dirname "$0")/lib.sh" || { echo "FAIL: cannot load lib.sh next to $0" >&2; exit 1; }
REPO_SLUG=${REPO_SLUG:-terafin/thermasol}
command -v gh >/dev/null || die "gh (GitHub CLI) is needed to download $BASE_RELEASE"
mkdir -p "$BASE"
for p in vendor boot dtbo product system; do
  f=$BASE/$p.img
  if [ -f "$f" ] && [ "$(sha "$f")" = "${BASE_SHA[$p]}" ]; then ok "$p already pinned"; continue; fi
  step "download $p.img from $BASE_RELEASE"
  rm -f "$f.part"
  gh release download "$BASE_RELEASE" -R "$REPO_SLUG" -p "$p.img" -O "$f.part" || die "download $p.img"
  [ "$(sha "$f.part")" = "${BASE_SHA[$p]}" ] || die "$p.img sha $(sha "$f.part") != pinned ${BASE_SHA[$p]}"
  mv "$f.part" "$f"; ok "$p pinned"
done

#!/bin/bash
# Compare the VINTF HAL declarations of a build's vendor image (manifest fragments + the audio APEX's
# fragments) against the base. A HAL declared twice, or at a different version than base, fails at
# early boot (before logd) and hangs the panel. Usage: check-vintf.sh <build-dir|latest>
source "$(dirname "$0")/lib.sh"
D=${1:-latest}; [ "$D" = latest ] && D=$OUT/latest; D=$(readlink -f "$D")
M=$WORK/vintfcheck; sudo umount -q $M/b $M/n 2>/dev/null || true; rm -rf $M; mkdir -p $M/b $M/n
trap 'sudo umount -q $M/b $M/n 2>/dev/null || true' EXIT
sudo mount -o ro,loop "$BASE/vendor.img" $M/b; sudo mount -o ro,loop "$D/vendor.img" $M/n
decls() {  # $1 = mounted vendor root -> "name@version/fqname" lines from manifests + audio APEX
  local v=$1 x; x=$(mktemp -d)
  sudo cat $v/etc/vintf/manifest.xml $v/etc/vintf/manifest/*.xml 2>/dev/null > $x/m.xml
  sudo cp $v/apex/com.android.hardware.audio.apex $x/a.apex; sudo chown $(id -u) $x/a.apex
  "$H/deapexer" --debugfs_path "$H/debugfs_static" --fsckerofs_path "$H/fsck.erofs" extract $x/a.apex $x/ax >/dev/null 2>&1
  cat $x/ax/etc/vintf/*.xml 2>/dev/null >> $x/m.xml
  python3 - $x/m.xml <<'PY'
import re,sys
t=open(sys.argv[1]).read()
for h in re.findall(r'<hal[^>]*format="aidl"[^>]*>(.*?)</hal>', t, re.S):
    n=re.search(r'<name>([^<]+)',h); v=re.search(r'<version>([^<]+)',h)
    for f in re.findall(r'<fqname>([^<]+)',h) or ["-"]:
        print(f"{n.group(1).strip() if n else '?'}@{v.group(1).strip() if v else '1'}/{f.strip()}")
PY
  rm -rf $x
}
decls $M/b | sort > $M/base.txt; decls $M/n | sort > $M/new.txt
fail=0
dup=$(sed 's/@[^/]*\//\//' $M/new.txt | sort | uniq -d)
[ -z "$dup" ] || { echo "  FAIL: HAL declared more than once: $dup"; fail=1; }
while IFS= read -r l; do
  key=$(echo "$l" | sed 's/@[^/]*\//\//'); b=$(sed 's/@[^/]*\//\//' $M/base.txt | grep -xF "$key" | head -1)
  bv=$(grep -F "${key%%/*}@" $M/base.txt | grep -F "/${key#*/}" | head -1)
  if [ -n "$bv" ] && [ "$bv" != "$l" ]; then echo "  FAIL: $l differs from base $bv"; fail=1; fi
done < $M/new.txt
[ $fail = 0 ] || die "VINTF declarations would fail at boot"
ok "VINTF declarations: no duplicates, no version changes vs base ($(wc -l < $M/new.txt) HALs)"

#!/bin/bash
# install.sh against a fake panel (fake-adb.sh): partitions are 1 MiB files, so this runs in CI.
set -u
H=$(cd "$(dirname "$0")" && pwd); T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
res(){ if [ "$2" = 0 ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; sed 's/^/    | /' "$T/out" | tail -12; fail=$((fail+1)); fi; }
PARTS="boot dtbo system vendor product vbmeta"
mkpanel(){  # fresh fake panel on _a, both slots holding "old" content
  rm -rf "$T/p" "$T/w"; mkdir -p "$T/p/dev" "$T/p/data" "$T/w/backup/x"
  for p in $PARTS; do for s in _a _b; do head -c 1048576 /dev/zero | tr '\0' 'o' > "$T/p/dev/${p}${s}"; done; done
  python3 -I -c "
import zlib,struct,sys
b=b'\0AB0'+bytes([1,0,0,0])+bytes([15,0,1,0,14,0,1,0])+bytes(12)
m=bytearray(4096); m[2048:2080]=b+struct.pack('>I',zlib.crc32(b)&0xffffffff); open(sys.argv[1],'wb').write(m)" "$T/p/dev/misc"
  echo _a > "$T/p/slot"; echo boot1 > "$T/p/boot_id"; echo olddigest > "$T/p/digest_a"
  echo x > "$T/w/backup/x/SHA256SUMS"; echo boot1 > "$T/w/backup/x/boot_id"; ln -s "$T/w/backup/x" "$T/w/backup/latest"
}
mkimages(){ rm -rf "$T/img"; mkdir -p "$T/img"; for p in $PARTS; do head -c 1048576 /dev/urandom > "$T/img/$p.img"; done
  (cd "$T/img" && sha256sum *.img > SHA256SUMS); }
# stand-in for imgcheck.py (real images need the signing key): prints the digest the "new" slot will report
printf '#!/usr/bin/env python3\nprint("vbmeta_digest=newdigest")\n' > "$T/imgcheck-stub.py"
run(){ ( cd "$H" && env -i HOME="$T" PATH="$PATH" PANEL=fake ADB="$H/fake-adb.sh" FAKE="$T/p" WORK="$T/w" \
         IMGCHECK="$T/imgcheck-stub.py" FAKE_DEVICE="${FAKE_DEVICE:-dart_mx8mm}" bash ./install.sh "$@" ) > "$T/out" 2>&1; }
same(){ for p in $PARTS; do cmp -s "$1/$p.img" "$T/p/dev/${p}$2" || return 1; done; }
a_hash(){ cat "$T/p/dev/"*_a | sha256sum; }

# 1. happy path: _b gets the images, _a untouched, panel ends on _b marked successful
mkpanel; mkimages; echo newdigest > "$T/p/digest_b"; before=$(a_hash)
run "$T/img" --yes; rc=$?
ok=1; [ $rc = 0 ] && same "$T/img" _b && [ "$(a_hash)" = "$before" ] && [ "$(cat "$T/p/slot")" = _b ] \
  && python3 -I -c "import sys;b=open(sys.argv[1],'rb').read()[2048:2080];sys.exit(0 if (b[12],b[13],b[14])==(15,0,1) and b[8]==14 else 1)" "$T/p/dev/misc" && ok=0
res "installs to the inactive slot, keeps the running slot, ends marked successful" $ok

# 2. wrong device: refuses before writing anything
mkpanel; mkimages; before=$(cat "$T/p/dev/"* | sha256sum)
FAKE_DEVICE=other run "$T/img" --yes; rc=$?
ok=1; [ $rc != 0 ] && [ "$(cat "$T/p/dev/"* | sha256sum)" = "$before" ] && grep -q "not a TT10V2" "$T/out" && ok=0
res "refuses a panel that is not a TT10V2, writes nothing" $ok

# 3. tampered image: SHA256SUMS mismatch refuses before touching the panel
mkpanel; mkimages; printf 'x' | dd of="$T/img/vendor.img" bs=1 seek=10 conv=notrunc status=none; before=$(cat "$T/p/dev/"* | sha256sum)
run "$T/img" --yes; rc=$?
ok=1; [ $rc != 0 ] && [ "$(cat "$T/p/dev/"* | sha256sum)" = "$before" ] && grep -q "SHA256SUMS does not match" "$T/out" && ok=0
res "refuses an image set whose SHA256SUMS do not match, writes nothing" $ok

# 4. wrong-size image: refuses before writing
mkpanel; mkimages; head -c 2048 /dev/urandom >> "$T/img/boot.img"; (cd "$T/img" && sha256sum *.img > SHA256SUMS); before=$(cat "$T/p/dev/"* | sha256sum)
run "$T/img" --yes; rc=$?
ok=1; [ $rc != 0 ] && [ "$(cat "$T/p/dev/"* | sha256sum)" = "$before" ] && grep -q "not the size of" "$T/out" && ok=0
res "refuses an image that is not exactly its partition's size, writes nothing" $ok

# 5. digest mismatch after the trial boot: does not mark the new slot successful
mkpanel; mkimages; echo wrongdigest > "$T/p/digest_b"
run "$T/img" --yes; rc=$?
ok=1; [ $rc != 0 ] && grep -q "vbmeta digest is not the image set" "$T/out" \
  && python3 -I -c "import sys;b=open(sys.argv[1],'rb').read()[2048:2080];sys.exit(0 if b[14]==0 else 1)" "$T/p/dev/misc" && ok=0
res "does not keep a slot whose booted vbmeta digest differs from the image set" $ok

echo "$pass passed, $fail failed"; [ $fail = 0 ]

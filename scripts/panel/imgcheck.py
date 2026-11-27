#!/usr/bin/env python3
"""Offline checks for a ThermaTouch TT10V2 image set and the panel's A/B record. No dependencies.

  imgcheck.py release DIR [--key-sha1 HEX] [--size NAME=BYTES ...] [--quick]
      Verify an image set (boot dtbo system product vendor vbmeta) the way the panel's U-Boot will:
      vbmeta signed with the expected key (default: the BSP public test key the panel's U-Boot
      trusts), flags 0, rollback index 0, no chain descriptors, exactly one hash/hashtree
      descriptor for each of the five partitions, every hash and hashtree root digest matching
      the image, the stored hash tree matching, boot.img's kernel decompressing to under 32 MiB.
      --size pins each image to its partition size (a short boot/vbmeta leaves a stale footer).
      Prints "vbmeta_digest=<hex>" (what the panel reports as ro.boot.vbmeta.digest) on success.
  imgcheck.py vbmeta-digest FILE
  imgcheck.py ab-select HEX
      Which slot this panel's U-Boot (2019.04-41468-ge20d4ecd9f, fsl_avb_ab_flow.c) boots for an
      A/B record, and which it falls back to: "first=_b fallback=_a" (or "-" for none).
  imgcheck.py uboot-env FILE
      Decode a 4 KiB U-Boot environment (CRC32 LE header); print the CRC state and whether bootcmd
      starts with the network recovery hook. Device identifiers are never printed.

Exit status is 0 only when every check passes.
"""
import hashlib
import mmap
import os
import struct
import sys
import zlib

BSP_TEST_KEY_SHA1 = "2597c218aae470a130f61162feaae70afd97f011"
PARTS = ("boot", "dtbo", "system", "product", "vendor")
KERNEL_MAX = 32 * 1024 * 1024          # fb_fsl_boot.c DST_DECOMPRESS_LEN
SHA256_RSA4096 = 2
PKCS1_SHA256 = bytes([0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03,
                      0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20])
HDR = "!4s2L2QL2Q2Q2Q2Q2QQLL47sx80x"


class Bad(Exception):
    pass


def need(cond, msg):
    if not cond:
        raise Bad(msg)


def parse_vbmeta(blob):
    need(len(blob) >= 256 and blob[:4] == b"AVB0", "vbmeta: no AVB0 header")
    (_, _, _, auth_sz, aux_sz, alg, h_off, h_sz, s_off, s_sz, k_off, k_sz, _, _, d_off, d_sz,
     rollback, flags, _, release) = struct.unpack(HDR, blob[:256])
    need(256 + auth_sz + aux_sz <= len(blob), "vbmeta: blocks run past the file")
    auth = blob[256:256 + auth_sz]
    aux = blob[256 + auth_sz:256 + auth_sz + aux_sz]
    return dict(alg=alg, auth=auth, aux=aux, size=256 + auth_sz + aux_sz, rollback=rollback,
                flags=flags, h=(h_off, h_sz), s=(s_off, s_sz), k=(k_off, k_sz), d=(d_off, d_sz),
                release=release.split(b"\0")[0].decode("ascii", "replace"), header=blob[:256])


def verify_signature(v):
    need(v["alg"] == SHA256_RSA4096, f"vbmeta: algorithm {v['alg']}, expected SHA256_RSA4096")
    k_off, k_sz = v["k"]
    key = v["aux"][k_off:k_off + k_sz]
    need(len(key) == 8 + 2 * 512, "vbmeta: public key is not RSA-4096")
    bits, _ = struct.unpack("!II", key[:8])
    need(bits == 4096, "vbmeta: public key is not RSA-4096")
    n = int.from_bytes(key[8:8 + 512], "big")
    digest = hashlib.sha256(v["header"] + v["aux"]).digest()
    h_off, h_sz = v["h"]
    need(v["auth"][h_off:h_off + h_sz] == digest, "vbmeta: stored hash does not match header+aux")
    s_off, s_sz = v["s"]
    sig = int.from_bytes(v["auth"][s_off:s_off + s_sz], "big")
    em = pow(sig, 65537, n).to_bytes(512, "big")
    want = b"\x00\x01" + b"\xff" * (512 - 3 - len(PKCS1_SHA256) - 32) + b"\x00" + PKCS1_SHA256 + digest
    need(em == want, "vbmeta: RSA signature does not verify")
    return hashlib.sha1(key).hexdigest()


def descriptors(v):
    d_off, d_sz = v["d"]
    data = v["aux"][d_off:d_off + d_sz]
    out, o = [], 0
    while o < len(data):
        need(o + 16 <= len(data), "vbmeta: truncated descriptor")
        tag, nbf = struct.unpack("!QQ", data[o:o + 16])
        body = data[o:o + 16 + nbf]
        need(len(body) == 16 + nbf, "vbmeta: truncated descriptor")
        if tag == 0:
            ks, vs = struct.unpack("!QQ", body[16:32])
            out.append(("prop", body[32:32 + ks].decode(), body[33 + ks:33 + ks + vs].decode()))
        elif tag == 1:
            f = struct.unpack("!QQLQQQLLLQQ32sLLLL60s", body[:180])
            (_, _, _, img_sz, tree_off, tree_sz, dbs, hbs, _, _, _, alg, nl, sl, rl, dflags, _) = f
            p = 180
            name = body[p:p + nl].decode(); salt = body[p + nl:p + nl + sl]
            root = body[p + nl + sl:p + nl + sl + rl]
            out.append(("hashtree", name, dict(image_size=img_sz, tree_offset=tree_off,
                        tree_size=tree_sz, dbs=dbs, hbs=hbs, alg=alg.rstrip(b"\0").decode(),
                        salt=salt, digest=root, flags=dflags)))
        elif tag == 2:
            f = struct.unpack("!QQQ32sLLLL60s", body[:132])
            (_, _, img_sz, alg, nl, sl, dl, dflags, _) = f
            p = 132
            name = body[p:p + nl].decode(); salt = body[p + nl:p + nl + sl]
            dig = body[p + nl + sl:p + nl + sl + dl]
            out.append(("hash", name, dict(image_size=img_sz, alg=alg.rstrip(b"\0").decode(),
                        salt=salt, digest=dig, flags=dflags)))
        elif tag == 4:
            raise Bad("vbmeta: has a chain partition descriptor (a chained slot parks in fastboot "
                      "forever on this U-Boot; never flash it)")
        else:
            raise Bad(f"vbmeta: unexpected descriptor tag {tag}")
        o += 16 + nbf
    return out


def round_up(n, m):
    return (n + m - 1) // m * m


def hash_tree(mm, image_size, block, salt):
    """avbtool generate_hash_tree for sha256 (no digest padding): (root digest, tree bytes)."""
    base = hashlib.sha256(salt)
    sizes, size = [], image_size
    while size > block:
        size = round_up(((size + block - 1) // block) * 32, block)
        sizes.append(size)
    offsets = [sum(sizes[m] for m in range(n + 1, len(sizes))) for n in range(len(sizes))]
    tree = bytearray(sum(sizes))
    if image_size == block:
        h = base.copy(); h.update(mm[:block]); return h.digest(), bytes(tree)
    src, src_size, level = mm, image_size, 0
    view = memoryview(src)
    while src_size > block:
        out = []
        for o in range(0, src_size, block):
            chunk = view[o:o + block]
            h = base.copy(); h.update(chunk)
            if len(chunk) < block:
                h.update(b"\0" * (block - len(chunk)))
            out.append(h.digest())
        lvl = b"".join(out)
        lvl += b"\0" * (round_up(len(lvl), block) - len(lvl))
        tree[offsets[level]:offsets[level] + len(lvl)] = lvl
        view = memoryview(lvl); src_size = len(lvl); level += 1
    h = base.copy(); h.update(lvl)
    return h.digest(), bytes(tree)


def lz4_sequences(data, o, end):
    """Decompressed size of one LZ4 block, walking its sequences without copying."""
    total = 0
    while o < end:
        tok = data[o]; o += 1
        lit = tok >> 4
        if lit == 15:
            while True:
                b = data[o]; o += 1; lit += b
                if b != 255: break
        o += lit; total += lit
        if o >= end:
            break
        o += 2
        m = tok & 15
        if m == 15:
            while True:
                b = data[o]; o += 1; m += b
                if b != 255: break
        total += m + 4
    need(o == end, "boot: LZ4 block does not end on a sequence boundary")
    return total


def lz4_size(data):
    """Decompressed size of an LZ4 kernel: frame format (04 22 4d 18) or legacy (02 21 4c 18)."""
    n = len(data)
    if data[:4] == b"\x04\x22\x4d\x18":
        flg = data[4]
        need(flg >> 6 == 1, "boot: unsupported LZ4 frame version")
        o = 6 + (8 if flg & 0x08 else 0) + (4 if flg & 0x01 else 0) + 1
        total = 0
        while True:
            need(o + 4 <= n, "boot: LZ4 frame truncated")
            bsz = struct.unpack("<I", data[o:o + 4])[0]; o += 4
            if bsz == 0:
                break
            raw, bsz = bsz & 0x80000000, bsz & 0x7fffffff
            need(o + bsz <= n, "boot: LZ4 block runs past the kernel")
            total += bsz if raw else lz4_sequences(data, o, o + bsz)
            o += bsz + (4 if flg & 0x10 else 0)
        return total
    if data[:4] == b"\x02\x21\x4c\x18":
        o, total = 4, 0
        while o + 4 <= n:
            bsz = struct.unpack("<I", data[o:o + 4])[0]
            if bsz == 0x184C2102:
                o += 4; continue
            if bsz == 0:
                break
            o += 4
            need(o + bsz <= n, "boot: LZ4 block runs past the kernel")
            total += lz4_sequences(data, o, o + bsz); o += bsz
        return total
    return None


def check_boot(path):
    with open(path, "rb") as f:
        hdr = f.read(48)
        need(hdr[:8] == b"ANDROID!", "boot: no ANDROID! header")
        ksz = struct.unpack("<I", hdr[8:12])[0]
        page = struct.unpack("<I", hdr[36:40])[0]
        need(page in (2048, 4096) and 0 < ksz < 64 << 20, "boot: implausible header")
        f.seek(page); kern = f.read(ksz)
    size = lz4_size(kern)
    if size is None:
        need(kern[:4] != b"\x1f\x8b\x08\x00", "boot: gzip kernel; this U-Boot only decompresses LZ4")
        size = len(kern)
    need(size < KERNEL_MAX, f"boot: kernel decompresses to {size} bytes; U-Boot's limit is "
                            f"{KERNEL_MAX} (it would park in fastboot)")
    return size


def release(argv):
    d = argv[0]
    key_sha1, sizes, quick = BSP_TEST_KEY_SHA1, {}, False
    i = 1
    while i < len(argv):
        if argv[i] == "--key-sha1":
            key_sha1 = argv[i + 1].lower(); i += 2
        elif argv[i] == "--size":
            k, val = argv[i + 1].split("="); sizes[k] = int(val); i += 2
        elif argv[i] == "--quick":
            quick = True; i += 1
        else:
            raise Bad(f"unknown option {argv[i]}")
    files = {p: os.path.join(d, p + ".img") for p in PARTS + ("vbmeta",)}
    for p, f in files.items():
        need(os.path.isfile(f), f"{p}.img missing from {d}")
        with open(f, "rb") as fh:
            need(fh.read(4) != b"\x3a\xff\x26\xed", f"{p}.img is an Android sparse image; this "
                 f"panel needs raw images (dd of a sparse file writes the block map)")
        if p in sizes:
            need(os.path.getsize(f) == sizes[p], f"{p}.img is {os.path.getsize(f)} bytes; the "
                 f"{p} partition is {sizes[p]}")
    with open(files["vbmeta"], "rb") as f:
        v = parse_vbmeta(f.read())
    got_key = verify_signature(v)
    need(got_key == key_sha1, f"vbmeta: signed by key {got_key}, expected {key_sha1}")
    need(v["flags"] == 0, f"vbmeta: flags {v['flags']} (verification disabled); expected 0")
    need(v["rollback"] == 0, f"vbmeta: rollback index {v['rollback']}; a non-zero index would "
         "stop older images from ever booting again")
    print(f"ok: vbmeta signature verifies (key {got_key}, {v['release']})")
    descs = [x for x in descriptors(v) if x[0] != "prop"]
    names = sorted(x[1] for x in descs)
    need(names == sorted(PARTS), f"vbmeta: descriptors for {names}, expected exactly {sorted(PARTS)}")
    for kind, name, info in descs:
        need(info["alg"] == "sha256", f"{name}: hash algorithm {info['alg']}")
        need(info["flags"] == 0, f"{name}: descriptor flags {info['flags']}")
        path = files[name]
        fsz = os.path.getsize(path)
        with open(path, "rb") as fh:
            mm = mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ)
            try:
                if kind == "hash":
                    need(info["image_size"] <= fsz, f"{name}: image shorter than its descriptor")
                    h = hashlib.sha256(info["salt"]); h.update(mm[:info["image_size"]])
                    need(h.digest() == info["digest"], f"{name}: hash does not match vbmeta")
                    print(f"ok: {name} hash matches vbmeta")
                else:
                    need(info["dbs"] == 4096 and info["hbs"] == 4096, f"{name}: unexpected block size")
                    need(info["tree_offset"] + info["tree_size"] <= fsz, f"{name}: tree past the image end")
                    if quick:
                        print(f"skip: {name} hashtree (--quick)"); continue
                    root, tree = hash_tree(mm, info["image_size"], 4096, info["salt"])
                    need(root == info["digest"], f"{name}: hashtree root does not match vbmeta")
                    stored = mm[info["tree_offset"]:info["tree_offset"] + info["tree_size"]]
                    need(stored == tree, f"{name}: hash tree stored in the image is wrong")
                    print(f"ok: {name} hashtree root and stored tree match vbmeta")
            finally:
                mm.close()
    ksize = check_boot(files["boot"])
    print(f"ok: boot kernel decompresses to {ksize} bytes (< {KERNEL_MAX})")
    with open(files["dtbo"], "rb") as fh:
        need(fh.read(4) == b"\xd7\xb7\xab\x1e", "dtbo: no DT table header")
    print("ok: dtbo has a DT table header")
    print(f"vbmeta_digest={hashlib.sha256(open(files['vbmeta'], 'rb').read()[:v['size']]).hexdigest()}")


def vbmeta_digest(argv):
    blob = open(argv[0], "rb").read()
    v = parse_vbmeta(blob)
    print(hashlib.sha256(blob[:v["size"]]).hexdigest())


def ab_select(argv):
    """fsl_load_metadata_dual_uboot + avb_ab_flow_fast slot choice, before verification."""
    b = bytes.fromhex(argv[0].replace(" ", ""))
    need(len(b) == 32 and b[:4] == b"\0AB0" and b[4] == 1, "A/B record: bad magic or version")
    need(struct.unpack(">I", b[28:])[0] == zlib.crc32(b[:28]) & 0xffffffff, "A/B record: bad CRC")
    slots = []
    for off in (8, 12):
        pri, tries, succ = b[off], b[off + 1], b[off + 2]
        if pri > 0 and tries == 0 and not succ:      # tries exhausted -> unbootable
            pri = 0
        slots.append((pri, tries, succ, pri > 0 and (succ or tries > 0)))
    target = 1 if slots[1][0] > slots[0][0] else 0
    order = [s for s in (target, 1 - target) if slots[s][3]]
    name = lambda s: "_ab"[1:][s].join(("_", "")) if s is not None else "-"
    first = order[0] if order else None
    fb = order[1] if len(order) > 1 else None
    print(f"first={name(first)} fallback={name(fb)}")


def uboot_env(argv):
    e = open(argv[0], "rb").read()
    need(len(e) == 4096, "environment must be 4096 bytes")
    crc_ok = struct.unpack("<I", e[:4])[0] == zlib.crc32(e[4:]) & 0xffffffff
    kv = {}
    for item in e[4:].split(b"\0"):
        if b"=" in item:
            k, val = item.split(b"=", 1); kv[k.decode("latin1")] = val.decode("latin1")
    boot = kv.get("bootcmd", "")
    print(f"crc={'ok' if crc_ok else 'BAD'}")
    print(f"nethook={'first' if boot.startswith('run tt_nethook;') else ('present' if 'tt_nethook' in boot else 'absent')}")
    print(f"android_bootargs={'ok' if 'androidboot.hardware=freescale' in kv.get('bootargs', '') else 'MISSING'}")
    need(crc_ok, "environment CRC does not match")
    # A sealed panel has no way in without the hook, so its absence is a failure, not a note.
    need(boot.startswith("run tt_nethook;") and "tftpboot" in kv.get("tt_nethook", ""),
         "bootcmd does not start with the network recovery hook (run tt_nethook)")
    need("androidboot.hardware=freescale" in kv.get("bootargs", ""), "bootargs lack the Android command line")


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr); return 2
    cmd, argv = sys.argv[1], sys.argv[2:]
    fn = {"release": release, "vbmeta-digest": vbmeta_digest, "ab-select": ab_select,
          "uboot-env": uboot_env}.get(cmd)
    if not fn:
        print(__doc__, file=sys.stderr); return 2
    try:
        fn(argv)
    except Bad as e:
        print(f"FAIL: {e}", file=sys.stderr); return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

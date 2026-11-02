# Release v1.0-android15 — verified

A first-timer's first command is a checksum. This is the record that it passes.

## Assets

Six `.img` files plus `SHA256SUMS`, from the release page.

```
boot.img     50,331,648 B
dtbo.img      4,194,304 B
product.img 1,879,048,192 B
system.img  1,879,048,192 B
vbmeta.img    1,048,576 B
vendor.img    536,870,912 B
```

## `sha256sum -c SHA256SUMS`

```
boot.img: OK
dtbo.img: OK
product.img: OK
system.img: OK
vbmeta.img: OK
vendor.img: OK
```

## AVB, against the public AOSP test key

`avbtool verify_image --image vbmeta.img --key <external/avb/test/data/testkey_rsa4096.pem>`

```
vbmeta:  Successfully verified SHA256_RSA4096 vbmeta struct in vbmeta.img
boot:    Successfully verified sha256 hash of boot.img for image of 34469888 bytes
dtbo:    Successfully verified sha256 hash of dtbo.img for image of 69099 bytes
product: Successfully verified sha256 hashtree of product.img for image of 948834304 bytes
system:  Successfully verified sha256 hashtree of system.img for image of 861192192 bytes
vendor:  Successfully verified sha256 hashtree of vendor.img for image of 84840448 bytes
```

Two things that look like errors and are not:

- The `for image of` sizes are **payload sizes**, not partition sizes. They will never match
  the file sizes above.
- All six images must be in the **current directory**. `avbtool` follows every hash inside
  `vbmeta` and fails on the first partition it cannot see.

## What this does not prove

That the images boot. That is a device result, and it is recorded in
[`../build/README.md`](../build/README.md) — not here.

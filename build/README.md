# Building our Android 15 image

This is **our** image: Variscite's `imx-android-15.0.0_1.2.0` BSP plus the ThermaSol panel
port and the fixes described in [`../docs/05-fixes.md`](../docs/05-fixes.md).

The images are not committed to git; they are published as release assets — see [Availability of the images](#availability-of-the-images).

## What is ours vs. what is somebody else's

| Layer | Owner | Do we publish it? |
|---|---|---|
| AOSP 15 platform | Google / AOSP (Apache-2.0) | source, yes; our `.img` no |
| **`product.img` — GMS, Play Store, Pixel prebuilts** | **Google, proprietary** | **no** |
| Variscite BSP: kernel, `vendor.img`, U-Boot | Variscite / NXP, proprietary-ish | no |
| ThermaSol device tree additions, our HAL patch, our app patches | **ours** | yes |
| Build/flash/verify scripts | **ours** | yes |

Measured, not assumed: `product.img` contains 1.4 GB of Google's proprietary apps —
`PrebuiltGmsCore` 164 MB, `Phonesky` (Play Store) 81 MB, `PrebuiltBugle` 135 MB, and more.
Publishing that image would redistribute Google's binaries to the world. `vendor.img` is
likewise NXP/Variscite content. **Neither is ours to republish**, exactly as with the 47 KB
speaker firmware — the size changes, the principle does not.

## The build, in order

```sh
# 1. BSP
#    imx-android-15.0.0_1.2.0.tar.gz  (357 MB)
#    manifest: github.com/varigit/variscite-bsp-platform, branch imx-android-15-var01
cd <android_build>
repo sync            # must be run from android_build/
source build/envsetup.sh
lunch dart_mx8mm-ap4a-userdebug   # not trunk_staging: its APEX minSdk codename hangs boot
m -j"$(nproc)"
```

Traps we hit (details in `../docs/04-android15-port.md`):

- Java 21 is required; the host default was 27 and fails.
- linuxbrew's git needed a system gitconfig that did not exist.
- **A build can report success and not rebuild `boot.img`.** Verify by timestamp *and* hash,
  every time.

## Then the panel-specific layer

1. **Device tree** — merge [`devicetree/tt10v2-port.dtsi`](../devicetree/tt10v2-port.dtsi) and
   [`devicetree/bluetooth-uart2.dtsi`](../devicetree/bluetooth-uart2.dtsi) into
   `arch/arm64/boot/dts/freescale/imx8mm-var-dart-dt8mcustomboard.dts` of Variscite's `linux-imx`,
   branch `android-15.0.0_1.2.0-var01` (the target named in the dtsi header). Display timings are
   measured, not guessed.
2. **Bluetooth HAL** — apply [`patches/bluetooth-hci-command-drain.patch`](../patches/bluetooth-hci-command-drain.patch)
   to `hardware/interfaces/bluetooth/aidl/default/`. This is the bounded command drain that
   stops the second OFF/ON cycle from timing out the HCI RESET.
3. **Vendor APK** — the navigation/layout fix is app-side; see
   [`../docs/06-procedures.md`](../docs/06-procedures.md) §G for the patch technique.
4. **Audio and framework** — [`scripts/panel/`](../scripts/panel/README.md) applies
   `overlay/audio-tree.patch` (the Sonos module in the reference AIDL audio service) and
   `overlay/framework.patch` (amp volume default, remembered output), then builds, gates and
   flashes the image.

## Reproducing the full image set

Build, then assemble per-partition with AVB. Our tooling did this metadata-preservingly:
extract the vendor/product EROFS, change only the intended payload, compare **all 999 inodes**
for uid/gid/mode/capabilities/SELinux label, rebuild with the original salt, re-sign vbmeta
with the five-descriptor / `flags=0` / no-chain layout, then verify with
`avbtool verify_image`.

**Do not chain `boot` in vbmeta** — see `../docs/04-android15-port.md`.

## The deployed set

**Current: v1.7-android15** — the exact set on both slots of the reference panel, built from published
inputs only. Verify a download with the release's `SHA256SUMS`.

| Partition | SHA-256 | Bytes |
|---|---|---|
| boot | `5d81612048846396a2a93fc5b7a2da7157c6c7146414f773fab641d09db820dd` | 50,331,648 |
| dtbo | `c9d519893db938fa9c8133943911ba63d528cc408ab30107bc784e9f818f538c` | 4,194,304 |
| product | `839432b1eb6ac636703ac00939bb694515202284b5c39f01a65174996e8bad5f` | 1,879,048,192 |
| system | `1fe36ed949668cba4b2f7644f37f8063089f12254e19f3bbbfe8346aec4bbc52` | 1,879,048,192 |
| vendor | `21df3ac1503662eed2ceb05925795f5ccf90b5a56e76b05eb43bcf0982973f31` | 536,870,912 |
| vbmeta | `5666d1bbfabfe553ef23b6eceebd3f9b87a11a2cc7b9cb14df1635a5f6e32742` | 1,048,576 |

### History: v1.0 and v1.2

Recorded so earlier downloads can still be checked.

**These are the hashes of the release assets, not of any single flash.** `product` and `system`
match the deployed set; `dtbo` (`c9d51989…`) matches no witnessed deployment — several dtbo builds
were used during bring-up, and the release carries the last good one built on the host. If you
need the hash the panel actually booted from, read it off the device:

```sh
adb shell 'su 0 sha256sum /dev/block/by-name/dtbo_$(getprop ro.boot.slot_suffix)'
```

| Partition | SHA-256 | Bytes |
|---|---|---|
| boot | `5d81612048846396a2a93fc5b7a2da7157c6c7146414f773fab641d09db820dd` | 50,331,648 |
| dtbo | `c9d519893db938fa9c8133943911ba63d528cc408ab30107bc784e9f818f538c` | 4,194,304 |
| product | `839432b1eb6ac636703ac00939bb694515202284b5c39f01a65174996e8bad5f` | 1,879,048,192 |
| system | `2c838f0bef27d9a6b472a03609e335f1376a3ef09836e1bc803241d048e1e81d` | 1,879,048,192 |
| vendor | `37f858a16a7d6a1fab25653827111629e2ab898160c5e6e5ec45dc6540ea6fbc` | 536,870,912 |
| vbmeta | `f9f496c448855b2cbf127ae6cb7b0ec1bbfee23df78529eac18a4015067efbb5` | 1,048,576 |

**v1.2-android15** changes only `vendor` and `vbmeta` (idle goes to the home screen; see
[`../services/tt-idle-dim/deployed/`](../services/tt-idle-dim/deployed/)):

| Partition | SHA-256 | Bytes |
|---|---|---|
| vendor | `8b4ab623ab1f0e31e8ee19d8afd2d9536fd6755b869ac0a08a1980c6a7191946` | 536,870,912 |
| vbmeta | `c814a60c9a40355f6f79dcff460a3b0ff31c23b8da140b1b2d97ec133fbb2cd8` | 1,048,576 |

These two are the bytes read back from both `vendor_a`/`vendor_b` and `vbmeta_a`/`vbmeta_b` on the
panel. The vendor image is v1.1's with `bin/tt_idle_dim` replaced; the other 999 inodes, their
uid/gid/mode/mtime, and all SELinux labels were compared and are identical, and the hashtree
reuses v1.1's salt. vbmeta was re-signed from the panel's own vbmeta (re-signing it unchanged
reproduced it byte for byte), so only the vendor descriptor differs.

## Availability of the images

The images are **not committed to git** — 4.4 GB in a repo whose value is the reasoning, and
`git clone` should stay cheap. They are published as **release assets** instead, so anyone
can download exactly what ran and flash it.

Two things to know before you do:

1. **They are signed with the BSP's stock test key.**
   `device/nxp/common/security/testkey_rsa4096.pem` (byte-identical to
   `external/avb/test/data/testkey_rsa4096.pem`), which `dart_mx8mm/BoardConfig.mk:228`
   selects. It is a **public, checked-in key** — not a secret, not per-device. Verify any image
   you download against it:

   ```sh
   AVB=$ANDROID_BUILD_TOP/out/host/linux-x86/bin/avbtool
   KEY=$ANDROID_BUILD_TOP/external/avb/test/data/testkey_rsa4096.pem
   "$AVB" verify_image --image vbmeta.img --key "$KEY"
   ```

   All six `.img` files must be in the current directory — `avbtool` follows every hash inside
   `vbmeta` and fails on the first missing partition.

2. **`product.img` contains Google proprietary applications** (GMS, Play Store, Pixel
   prebuilts — 1.4 GB). It is published here as a **device backup for owners of this hardware**,
   not as a redistribution licence. If you are not restoring your own panel, build from source
   using the recipe above.

## Installing onto a stock panel

That is the whole point, so it gets its own guide:
[`../docs/09-install-from-stock.md`](../docs/09-install-from-stock.md).

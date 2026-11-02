# Building our Android 15 image

This is **our** image: Variscite's `imx-android-15.0.0_1.2.0` BSP plus the ThermaSol panel
port and the fixes described in [`../docs/05-fixes.md`](../docs/05-fixes.md).

The images themselves are **not published here** — see [Why not the images](#why-not-the-images).

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
lunch dart_mx8mm-userdebug
m -j"$(nproc)"
```

Traps we hit (details in `../docs/04-android15-port.md`):

- Java 21 is required; the host default was 27 and fails.
- linuxbrew's git needed a system gitconfig that did not exist.
- **A build can report success and not rebuild `boot.img`.** Verify by timestamp *and* hash,
  every time.

## Then the panel-specific layer

1. **Device tree** — merge [`devicetree/tt10v2-port.dtsi`](devicetree/tt10v2-port.dtsi) and
   [`devicetree/bluetooth-uart2.dtsi`](devicetree/bluetooth-uart2.dtsi) into the Variscite
   DART DT. Display timings are measured, not guessed.
2. **Bluetooth HAL** — apply [`patches/bluetooth-hci-command-drain.patch`](patches/bluetooth-hci-command-drain.patch)
   to `hardware/interfaces/bluetooth/aidl/default/`. This is the bounded command drain that
   stops the second OFF/ON cycle from timing out the HCI RESET.
3. **Vendor APK** — the navigation/layout and volume fixes are app-side; see
   [`../docs/06-procedures.md`](../docs/06-procedures.md) §G for the patch technique.

## Reproducing the full image set

Build, then assemble per-partition with AVB. Our tooling did this metadata-preservingly:
extract the vendor/product EROFS, change only the intended payload, compare **all 999 inodes**
for uid/gid/mode/capabilities/SELinux label, rebuild with the original salt, re-sign vbmeta
with the five-descriptor / `flags=0` / no-chain layout, then verify with
`avbtool verify_image`.

**Do not chain `boot` in vbmeta** — see `../docs/04-android15-port.md`.

## The deployed set

Recorded so you can confirm you have the same thing we ran:

| Partition | SHA-256 | Bytes |
|---|---|---|
| boot | `5d81612048846396a2a93fc5b7a2da7157c6c7146414f773fab641d09db820dd` | 50,331,648 |
| dtbo | `c9d519893db938fa9c8133943911ba63d528cc408ab30107bc784e9f818f538c` | 4,194,304 |
| product | `839432b1eb6ac636703ac00939bb694515202284b5c39f01a65174996e8bad5f` | 1,879,048,192 |
| system | `2c838f0bef27d9a6b472a03609e335f1376a3ef09836e1bc803241d048e1e81d` | 1,879,048,192 |
| vendor | `37f858a16a7d6a1fab25653827111629e2ab898160c5e6e5ec45dc6540ea6fbc` | 536,870,912 |
| vbmeta | `f9f496c448855b2cbf127ae6cb7b0ec1bbfee23df78529eac18a4015067efbb5` | 1,048,576 |

## Why not the images

Three honest reasons:

1. **Proprietary content.** `product.img` and `vendor.img` are Google's and NXP/Variscite's.
2. **They are device-locked.** The images are signed with the device's AVB key and will only
   boot on this exact unit; for anyone else they are at best useless, at worst a brick.
3. **Size.** ~4.4 GB of binaries for a repo whose value is the reasoning.

If you own one of these panels and want the images, rebuild from the BSP with the patches
here — that is reproducible, and it does not depend on trusting a stranger's binary.

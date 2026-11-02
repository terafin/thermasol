# 11 — Serving the vendor app store ourselves

The panel's list of installable apps does **not** come from Google Play. The ThermaSol app has
its own store, fetched over plain HTTP. That is what made it possible to get Termux onto a
completely stock panel.

This page is read out of the decompiled app (`com.thermasol.touchsteam2`), not guessed. Every
claim below has a file:line behind it in the **vendor-store-protocol** section at the end.

> The protocol below is confirmed from the decompiled app, the live vendor server, and a real
> Termux install that went through a mirror. The DNS override **has** been done for real; see
> §"What was actually done" for the exact configuration.

---

## The mechanism

| Piece | Value |
|---|---|
| Base | `http://thermatouch.tsolup.com/` |
| Listings | `index.json` (MCU/older) and `index-10.json` (current) |
| Cache | `getExternalFilesDir(DIRECTORY_DOCUMENTS)/cached` |
| Cleartext | explicitly whitelisted for `thermatouch.tsolup.com` and `www.thermatouchupdate.com` |

Both listings are fetched and **merged, `index-10.json` winning** on package-name collisions.
The result is written to `cached` as `combined.json`.

Override DNS for `thermatouch.tsolup.com` to a host you control and the panel fetches your
listings instead. No proxy, no certificate, no TLS interception.

The DNS trick works specifically because the cleartext whitelist in `network_security_config.xml`
matches on **hostname**, not address — `thermatouch.tsolup.com` is permitted cleartext wherever
it resolves to. Renaming the host in a hosts file instead would lose that permission.

## The listing schema

`{"app_details": [ ... ]}` — camel-to-snake via Gson `@SerializedName`.

```json
{
  "app_details": [
    {
      "app_name": "Termux",
      "package_name": "com.termux",
      "current_version": "0.118.3",
      "updated": "20260901",
      "apk_icon_url": "http://thermatouch.tsolup.com/apps-10/icons/com.termux.png"
    }
  ]
}
```

| Field | Required | Consumed? |
|---|---|---|
| `package_name` | yes | yes — identity, matching, install state |
| `apk_icon_url` | yes | yes — and the download path is derived from it (below) |
| `app_name`, `current_version`, `updated` | no | display only |
| `min_core_req`, `min_service_version` | no | **parsed and never read** |

`hidden` appears in the **live vendor data** (2 of 47 entries, both vendor-internal) but has no
corresponding field in `AppDetail` and is read nowhere — Gson drops it. It is inert; do not rely
on it. The only `hidden` identifiers in the app are an unrelated preference screen.

Real filtering is local: four built-in packages are excluded (`Utility.internalApp`),
already-installed packages are hidden, and the grid caps at 24.

## The APK URL is derived from the icon URL

This is the part that matters, and it is not what you would guess — but it **is** confirmed,
twice: against the live vendor server and against a real Termux install that used it.

There is **no `apps-10/` literal in the download path** — `SystemConstants.APPS_FOLDER` is a dead
constant, referenced only at its declaration. Instead:

```java
File icon   = new File(apkIconUrl);
File parent = new File(icon.getParent()).getParentFile();   // two levels up
url = icon.getScheme() + "://" + icon.getHost() + "/" + parent.getName()
      + "/" + packageName + ".apk";
```

Worked example, using a real entry out of the live `index-10.json`:

```
apk_icon_url = https://thermatouch.tsolup.com/apps-10/icons/com.amazon.mp3.png
package_name = com.amazon.mp3
     getParent()          = .../apps-10/icons        (drop the filename)
     getParentFile()      = .../apps-10             (drop "icons")
     .getName()           = "apps-10"
APK          = https://thermatouch.tsolup.com/apps-10/com.amazon.mp3.apk
```

**Confirmed live**: that URL answers HTTP 206 to a range request. Every one of the 45
non-builtin entries in the live listing has exactly this three-segment shape
(`apps-10/icons/<package>.png`), so the rule is uniform.

**Confirmed again by a real install**: on 2026-09-13 a mirror served
`apk_icon_url = http://thermatouch.tsolup.com/apps/icons/com.termux.png`, the panel derived
`http://thermatouch.tsolup.com/apps/com.termux.apk`, requested it, and Termux installed. That is
the whole trick working end to end.

**Rules the server must obey:**

1. `apk_icon_url` must be absolute with a host and **exactly the depth you want to name the
   folder**. Fewer than two path segments and the client returns early — the install silently
   does nothing. The icon file itself is cosmetic; its *string* is load-bearing.
2. No query strings — `java.io.File` parses them into the folder name.
3. The APK filename is `<package_name>.apk` verbatim. No version suffix.
4. The folder is whatever the **second-to-last** path segment is. So pick your layout and keep
   it: `<prefix>/icons/<pkg>.png` → APKs at `<prefix>/<pkg>.apk`.
5. **The scheme is copied from the icon URL.**

   ```java
   url = (isVantron ? "https" : iconUri.getScheme()) + "://" + iconUri.getHost() + "/" + ...
   ```

   The panel is not Vantron, so the icon URL's scheme wins. Serve `http://` icons from a
   plain-HTTP mirror, or the panel will demand TLS for the APK and fail.

Note the two built-in entries that carry `apk_icon_url: "emptyUrl"` — the ThermaTouch service and
TouchSteam apps. They are excluded locally by `Utility.internalApp`, so they never reach the
install path.

## No signature check

`Verifiable` sounds like verification and mostly isn't. It is a `CRC32` subclass; the fetch path
is a bare `URL.openStream()` with no status check, no length check, no headers, no retry.

- **App listings and APKs: no checksum, no signature, no auth.** The only integrity check is
  Android's own package-signature check at install time.
- The one real CRC32 verify is HydroVive firmware: `firmware/hydrovive/latest.bin` against the
  hex string in `latest.bin.crc32`. That is a CRC, not a cryptographic signature, and it is
  firmware-only.

## Two failure modes that look like "the server is broken"

- **100 KB hard cap.** `ByteBuffer.allocate(102400)`; the 102401st byte throws, the exception is
  swallowed, and you get truncated JSON → an empty list. Keep each listing under 100 000 bytes.
- **HTTP status is ignored.** A 404 produces a silent empty app grid. There is no error dialog.
  If the store appears blank, it is almost always a 404 or a parse failure, not the network.

A parse failure anywhere also yields a silent empty list — there is no logging on that path.

## Step 1 — get the APKs (and verify them)

`scripts/store-mirror/fetch_bootstrap.py` pulls the apps that take a stock panel to a
persistent shell, and **verifies each one**:

```sh
./scripts/store-mirror/fetch_bootstrap.py --out ./store \
    --apksigner /path/to/apksigner.jar --aapt /path/to/aapt
```

| Package | App | Why it is in the set |
|---|---|---|
| `com.termux` | Termux | The shell. Everything depends on it. |
| `com.termux.boot` | Termux:Boot | Runs `~/.termux/boot/*` at boot — what makes access survive a reboot. |
| `com.termux.api` | Termux:API | Android APIs (clipboard, notifications, sensors) for shell commands. |
| `com.termux.widget` | Termux:Widget | Home-screen shortcuts to scripts. |

What "verified" means, per APK:

| Check | Tool | Failure mode it catches |
|---|---|---|
| Signature verifies and the cert SHA-256 is F-Droid's | `apksigner` | a substituted or intercepted APK |
| Package name **inside** the APK matches the filename | `aapt` | a mislabelled file served under the wrong name |
| SHA-256 recorded, and compared against a pin when one exists | — | silent version drift |

A pin mismatch deletes the file and fails the run. Add pins to `PINS` once you have checked a
digest yourself. Output is `apks/`, `icons/`, `bootstrap.json` (provenance and digests), and a
`meta.json` that `serve_store.py` reads automatically, so the listing gets real app names and
versions with no extra step.

**Deliberately not fetched:**

- **NewPipe** — it was on the first mirror, but it is not part of the access stack and its APK
  does not carry the F-Droid repository certificate (signer `964dfa41…`, not `228fb2cf…`).
  Serving an APK whose provenance we cannot confirm would break the one invariant this script
  exists to enforce.
- **Any Play Store client** — the route into this panel was never a store client. The panel's
  own vendor store installs whatever this mirror lists.
- **A standalone sshd or adb binary** — Termux supplies both. A second copy is a second thing
  to trust for no gain.

Verified 2026-11-02: all four fetch, pass the F-Droid cert check, and pass the package-name
check.

## Step 2 — serve them

`scripts/store-mirror/serve_store.py`:

```sh
mkdir -p store/apks store/icons
cp Termux.apk         store/apks/com.termux.apk
cp Termux-Boot.apk    store/apks/com.termux.boot.apk
cp termux-icon.png    store/icons/com.termux.png      # optional; a 1x1 PNG is synthesised if absent

# --base-url is REQUIRED: it is what makes the icon URLs absolute
./scripts/store-mirror/serve_store.py \
    --root ./store --port 80 --base-url http://<your-server-ip> --log
```

| URL | Serves |
|---|---|
| `/index-10.json`, `/index.json` | the same generated listing |
| `/apps-10/<package>.apk` | the APK, `application/vnd.android.package-archive` |
| `/apps-10/<package>/icon.png` | the icon — the depth the client needs to derive the APK path |

`--base-url` is not optional. The client needs absolute icon URLs; without one it returns early
and installs nothing, silently. Use the address the **panel** will reach, not `localhost`.

`--print-index` dumps the listing without serving. `--log` shows every request, which is how you
confirm what the panel actually asks for.

**Verified** (2026-11-02): `scripts/store-mirror/test_serve_store.py` derives the APK URL from
each advertised icon URL the same way the client does, then fetches it — 33 checks, all passing,
covering both listings, absolute icon URLs, derived-APK 200 with the right MIME type, icon
serving, missing-package 404, `..` traversal blocked, and the startup banner appearing before
the first request. Run it with `python3 -I test_serve_store.py`.

## What was actually done (2026-09-13)

The first successful run of this technique, recorded so it can be repeated exactly:

| Piece | Value |
|---|---|
| DNS | **UniFi gateway local-DNS A record** `thermatouch.tsolup.com → 104.168.102.110`, TTL 300 |
| Host | `zeal` (`zeal.example.net`), a public VPS outside the home-fleet route chain |
| Server | plain `python3` `http.server` bound `0.0.0.0:80` as root, in `/tmp` |
| Content | `/tmp/paneldata/termux.apk` (from F-Droid, 114,920,926 B) + a hand-written catalogue |
| Result | panel fetched `index.json` and `index-10.json`, then the APK, and Termux installed |

No resolver software was involved — not dnsmasq, not unbound, not pihole. The UniFi record was
the whole change. Verified with:

```sh
dig +short @10.0.90.1 thermatouch.tsolup.com    # the IoT-VLAN gateway the panel resolves through
```

The panel's request lines were exactly as this page predicts:

```
GET /index.json
GET /index-10.json
User-Agent: Dalvik/2.1.0 (Linux; U; Android 10; variscite Build/QD1A.190821.014.C2)
Host: thermatouch.tsolup.com
```

**The record is gone.** No revert call appears in the session log, but the override has been
removed — verified 2026-11-02: `thermatouch.tsolup.com` resolves to the real vendor IP
`50.116.16.103` from both a general resolver and the panel's IoT-VLAN gateway (`10.0.90.1`).
The panel can reach the real store and firmware updates.

Before setting the override again, **check the UniFi local-DNS table for a leftover record** —
a stale one would silently redirect the panel to a mirror that is no longer serving.

**Also worth knowing:** the first attempt returned the generic `{"status":"ok"}` fallback for
`index-10.json`. Gson produced a null list and the app threw an NPE. The fix was making every
`index*.json` return a real catalogue — which is why this server generates one listing and
answers both names with it.

## The end-to-end recipe

0. `fetch_bootstrap.py --out ./store` — get and verify the APKs (Step 1).
1. Override DNS for `thermatouch.tsolup.com` → your server. A UniFi local-DNS A record works and
   is what was used; a router/dnsmasq/pihole entry works the same way.
2. Serve a listing containing Termux and Termux:Boot, with the APKs at the derived path.
3. On the panel, open the app's App Store. Install both. (Termux:Boot could **not** be
   installed this way the first time — it went on over `adb` once Termux had given a shell. The
   store can carry it if you list it, but the historical run did not.)
4. In Termux: `pkg install openssh`, start `sshd`, add your key, add the boot hook.
5. Continue with [09-install-from-stock.md](09-install-from-stock.md).
6. **Revert the DNS override.** Leaving it in place silently breaks the real store and firmware
   lookups — and remember a broken store looks like an empty grid, not an error.

## Safety

- `fetch_bootstrap.py` refuses anything not signed by F-Droid's repository certificate, and
  refuses an APK whose internal package name does not match its filename. Do not bypass that by
  copying files into `apks/` by hand — if you do, you are serving unverified binaries to a
  root-capable device.
- Serve only APKs you built or trust. This is a root-capable device with no signature checking
  on the download path.
- Android still enforces package signatures at install time, so you cannot substitute a
  differently-signed build of an already-installed package.

## Vendor-store protocol — sources

Decompiled trees: `/home/terafin/tt-recovery/thermasol-apk-20261011/` (Java, 2026-10-11 APK) and
`installed-smali/` (smali, installed 1.2.0 image). Both agree.

| Claim | Evidence |
|---|---|
| Listing URLs | `sources/com/thermasol/utils/SystemConstants.java:5-6,16-21` |
| Merge order, `combined.json`, cache path | `touchsteam2/util/Utils.java:845-885`, `LocalConstants.java:7` |
| Gson schema | `utils/ServerResponse.java:10-12`, `utils/AppDetail.java:9-35` |
| `min_core_req`/`min_service_version` unread | grep, both trees |
| Local filtering | `touchsteam2/util/Utils.java:724-742`, `utils/Utility.java:48-50`, `AppGridAdapter.java:24` |
| APK URL derivation | `touchsteam2/activities/AppListingActivity.java:102-121` |
| `APPS_FOLDER` dead | grep, hits only the declaration |
| `Verifiable` / bare fetch | `utils/Verifiable.java:8-52`, `utils/Utility.java:135-161` |
| Firmware CRC32 | `activities/FirmwareUpdateActivity.java:90-93` |
| DownloadManager | `touchsteam2/util/FileManager.java:106-125` |
| Cleartext whitelist | `resources/res/xml/network_security_config.xml:1-9` |
| No headers / no okhttp | grep, both trees |
| Scheme copied from icon URL | `AppListingActivity.java:111-113` |
| Live APK location `apps-10/<pkg>.apk` (206) | `curl -r 0-0`, 2026-11-02 |
| Derivation confirmed end to end by a real Termux install | session `clever-purring-hopper`, 2026-09-13 02:42 |

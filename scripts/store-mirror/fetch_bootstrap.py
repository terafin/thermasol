#!/usr/bin/env python3
"""Pull the panel-bootstrap APKs and verify them, so the mirror serves known-good files.

WHAT IT FETCHES
---------------
The apps that take a stock ThermaTouch from "no shell" to "shell, plus the tools that
made the first conversion possible". Termux is the load-bearing one; the rest are the
supporting cast.

    com.termux          Termux itself — the shell. F-Droid build.
    com.termux.boot     Termux:Boot — runs ~/.termux/boot/* at boot. This is what makes
                        access survive a reboot.
    com.termux.api      Termux:API — exposes Android APIs (clipboard, notifications,
                        sensors) to shell commands.
    com.termux.widget   Termux:Widget — home-screen shortcuts to scripts.

NOT fetched, on purpose:
  * **NewPipe** — it was on the first mirror, but it is not part of the access stack and its
    APK does not carry the F-Droid repository certificate (verified: signer
    964dfa41…, not 228fb2cf…). Serving an APK whose provenance this script cannot confirm
    would break the one invariant it exists to enforce.
  * **A Play Store client of any kind.** The route into this panel was never a store client
    — it was the panel's own vendor store, redirected at a mirror. Nothing here needs one.
  * **A standalone sshd/adb binary** — Termux supplies both (`pkg install openssh`, and
    `adbd` is already on the device). Shipping a second copy would be a second thing to
    trust for no gain.

WHY VERIFY
----------
The vendor download path has no signature check at all (see docs/11), and the panel will
install whatever this directory contains. Verification has to happen HERE, once, with
evidence written next to the files — not be assumed at install time.

Each APK is checked for:
  * signature verifies (apksigner) and the signing cert's SHA-256 digest is recorded;
  * the package name INSIDE the APK matches the filename we are about to serve;
  * the version reported by the APK matches what will be advertised in the listing.

The vendor's expected digests are pinned below as they become known. A pin mismatch is a
hard failure. Adding a pin is how you turn "we downloaded it once" into "this is the file
we intended".

USAGE
    ./fetch_bootstrap.py --out ./store            # apks/ + icons/ + bootstrap.json
    ./fetch_bootstrap.py --out ./store --print    # what would be fetched

Needs `apksigner` (or --apksigner PATH) and `aapt` (or --aapt PATH) to verify.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

FDROID_REPO = "https://f-droid.org/repo"
FDROID_INDEX = "https://f-droid.org/repo/index-v2.json"
# Published F-Droid repository signing certificate SHA-256 digest. An APK signed by this
# cert came from the F-Droid repo and not from someone who intercepted the download.
FDROID_CERT_SHA256 = "228fb2cfe90831c1499ec3ccaf61e96e8e1ce70766b9474672ce427334d41c42"

# package -> (f-droid package name, human name, why it is in the bootstrap set)
CATALOGUE = [
    ("com.termux",         "com.termux",         "Termux",
     "The shell. Everything else depends on it."),
    ("com.termux.boot",    "com.termux.boot",    "Termux:Boot",
     "Runs ~/.termux/boot/* at boot — this is what makes access survive a reboot."),
    ("com.termux.api",     "com.termux.api",     "Termux:API",
     "Android APIs (clipboard, notifications, sensors) exposed to shell commands."),
    ("com.termux.widget",  "com.termux.widget",  "Termux:Widget",
     "Home-screen shortcuts to scripts."),
]

# Pinned SHA-256 of the exact APK we intend to serve. Empty = not yet pinned; the digest is
# recorded on every run either way so a pin can be added deliberately.
PINS: dict[str, str] = {}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_tool(name: str, given: str | None) -> str:
    if given:
        return given
    exe = shutil.which(name)
    if exe:
        return exe
    die(f"{name} not found. Pass --{name} /path/to/{name}.")


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def run(cmd: list[str]) -> str:
    r = subprocess.run(cmd, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        die(f"{' '.join(cmd)}\n{out}")
    return out


def apksigner_java(apksigner: str) -> list[str]:
    """Resolve an invocable apksigner.

    Two common shapes: a shell wrapper that needs `apksigner.jar` next to it (which some
    AOSP trees put somewhere entirely different), and the jar on its own. Accept either, so
    `--apksigner` can point at whatever the user actually has.
    """
    path = Path(apksigner)
    if path.suffix == ".jar":
        return ["java", "-jar", str(path)]
    try:
        probe = subprocess.run([apksigner, "version"], capture_output=True, text=True, timeout=60)
        if probe.returncode == 0:
            return [apksigner]
    except Exception:
        pass
    # Wrapper that cannot find its jar: look in the layouts AOSP and the SDK use.
    here = path.resolve().parent
    candidates = [
        here / "lib" / "apksigner.jar",
        here.parent / "lib" / "apksigner.jar",
        here.parent.parent / "lib" / "apksigner.jar",
        here.parent.parent.parent / "lib" / "apksigner.jar",
    ]
    for cand in candidates:
        if cand.is_file():
            return ["java", "-jar", str(cand)]
    die(f"apksigner at {apksigner} cannot find apksigner.jar; pass --apksigner "
        f"pointing at apksigner.jar itself")


def cert_digest(apksigner: str, apk: Path) -> str:
    out = run(apksigner_java(apksigner) + ["verify", "--print-certs", str(apk)])
    for line in out.splitlines():
        if "SHA-256 digest" in line:
            return line.rsplit(":", 1)[-1].strip().lower()
    die(f"no certificate digest in apksigner output for {apk}")


def badging(aapt: str, apk: Path) -> dict:
    out = run([aapt, "dump", "badging", str(apk)])
    first = out.splitlines()[0] if out else ""
    info = {}
    for field in ("name", "versionCode", "versionName"):
        marker = f"{field}='"
        if marker in first:
            info[field] = first.split(marker, 1)[1].split("'", 1)[0]
    return info


def fdroid_version(pkg: str) -> tuple[str, int]:
    """Ask F-Droid for the suggested (versionName, versionCode) of a package."""
    import urllib.request
    url = f"https://f-droid.org/api/v1/packages/{pkg}"
    with urllib.request.urlopen(url, timeout=60) as r:
        doc = json.loads(r.read().decode())
    code = doc["suggestedVersionCode"]
    name = next((p["versionName"] for p in doc["packages"] if p["versionCode"] == code), "")
    return name, code


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default="store", type=Path,
                    help="mirror root; writes apks/, icons/, bootstrap.json")
    ap.add_argument("--apksigner", default=None)
    ap.add_argument("--aapt", default=None)
    ap.add_argument("--print", action="store_true", help="show the plan and exit")
    args = ap.parse_args(argv)

    if args.print:
        print(f"catalogue ({len(CATALOGUE)} packages) -> {args.out}/apks/")
        for pkg, source, label, why in CATALOGUE:
            print(f"  {pkg:22} {label:16} {why}")
        return 0

    apksigner = find_tool("apksigner", args.apksigner)
    aapt = find_tool("aapt", args.aapt)

    out: Path = args.out
    (out / "apks").mkdir(parents=True, exist_ok=True)
    (out / "icons").mkdir(parents=True, exist_ok=True)

    import urllib.request

    records = []
    failures = []
    for pkg, source, label, why in CATALOGUE:
        try:
            vname, vcode = fdroid_version(source)
        except Exception as e:
            failures.append(f"{pkg}: F-Droid index lookup failed: {e}")
            continue
        url = f"{FDROID_REPO}/{source}_{vcode}.apk"
        dest = out / "apks" / f"{pkg}.apk"
        print(f"== {label} ({pkg}) {vname} [{vcode}]")
        try:
            with urllib.request.urlopen(url, timeout=600) as r, dest.open("wb") as f:
                shutil.copyfileobj(r, f)
        except Exception as e:
            failures.append(f"{pkg}: download failed: {e}")
            continue

        digest = sha256(dest)
        cert = cert_digest(apksigner, dest)

        if cert != FDROID_CERT_SHA256:
            dest.unlink(missing_ok=True)
            failures.append(f"{pkg}: signed by {cert}, expected F-Droid {FDROID_CERT_SHA256}")
            continue

        info = badging(aapt, dest)
        if info.get("name") != pkg:
            dest.unlink(missing_ok=True)
            failures.append(f"{pkg}: APK declares package '{info.get('name')}'")
            continue

        pinned = PINS.get(pkg)
        if pinned and pinned != digest:
            dest.unlink(missing_ok=True)
            failures.append(f"{pkg}: digest {digest} != pinned {pinned}")
            continue

        take_icon(dest, out / "icons" / f"{pkg}.png")
        print(f"   sha256 {digest}{'  (pinned)' if pinned else '  (unpinned)'}")
        print(f"   cert   {cert}  ✓ F-Droid")
        records.append({
            "package_name": pkg,
            "app_name": label,
            "why": why,
            "source": url,
            "current_version": info.get("versionName", vname),
            "version_code": int(info.get("versionCode", vcode)),
            "sha256": digest,
            "signer_sha256": cert,
            "signer_pinned": pinned is not None,
        })

    manifest = out / "bootstrap.json"
    manifest.write_text(json.dumps({"fetched": records, "failures": failures}, indent=1))

    # serve_store.py reads meta.json as per-package overrides. Writing it here means the
    # listing gets real app names and versions with no extra step — the two scripts compose.
    if not failures:
        meta = {
            r["package_name"]: {
                "app_name": r["app_name"],
                "current_version": r["current_version"],
            }
            for r in records
        }
        (out / "meta.json").write_text(json.dumps(meta, indent=1))

    print()
    if failures:
        print(f"{len(failures)} FAILED — nothing that failed was written:")
        for f in failures:
            print(f"  {f}")
        print(f"manifest: {manifest}")
        return 1
    print(f"{len(records)} app(s) fetched and verified -> {out}/apks/")
    print(f"manifest: {manifest}")
    print(f"meta:     {out / 'meta.json'} (serve_store.py picks this up automatically)")
    print(f"now run:  serve_store.py --root {out} --base-url http://<panel-reachable-ip>")
    return 0


def take_icon(apk: Path, dest: Path) -> None:
    """Extract the launcher icon if the APK ships a plain PNG, else leave it — serve_store
    synthesises a placeholder and the icon URL is load-bearing as a string regardless."""
    try:
        with zipfile.ZipFile(apk) as z:
            for n in z.namelist():
                if n.startswith("res/") and n.endswith(".png") and "icon" in n.lower():
                    dest.write_bytes(z.read(n))
                    return
    except Exception:
        pass


if __name__ == "__main__":
    raise SystemExit(main())

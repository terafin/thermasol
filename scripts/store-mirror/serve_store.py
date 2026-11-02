#!/usr/bin/env python3
"""Serve a ThermaSol 'app store' for the ThermaTouch panel.

WHY THIS EXISTS
---------------
The vendor app does not use Google Play. Its store is a plain HTTP index at

    http://thermatouch.tsolup.com/<listing>

(`index-10.json` for the Android 10 build) which `Utils.getAppDetails()` fetches and parses
into app entries. Pointing that hostname at a LAN/VPS host — via DNS — makes the panel install
whatever we serve instead.

This script is that server. It serves:
    /index-10.json            the listing (generated from what is on disk)
    /<listing>                same, for whichever listing name you choose
    /apps-10/icons/<pkg>.png  icons (optional)
    /apps-10/<pkg>.apk        APK payloads  (see NOTE on the path below)

HOW THE CLIENT FINDS AN APK
---------------------------
The listing has no download-URL field. AppListingActivity builds the APK URL from the ICON URL:

    File parentFile = new File(new File(iconUrl).getParent()).getParentFile();
    url = (isVantron ? "https" : uri.getScheme()) + "://" + uri.getHost()
          + "/" + parentFile.getName() + "/" + packageName + ".apk"

Two consequences that matter here:

  * the icon URL must be ABSOLUTE with >= 2 path segments, or the method returns early and
    the install silently does nothing. Hence --base-url is required.
  * the SCHEME is inherited from the icon URL. Advertise http:// icons and the download is
    http://; advertise https:// icons and the panel demands TLS. This server serves plain
    HTTP, so it always advertises http://.

CONFIRMED, not inferred: with icon URLs of the form <base>/<prefix>/icons/<pkg>.png the
client derives <base>/<prefix>/<pkg>.apk. Checked against the live vendor server (HTTP 206
for https://thermatouch.tsolup.com/apps-10/com.amazon.mp3.apk) and against a real Termux
install through a mirror on 2026-09-13, which used exactly
http://thermatouch.tsolup.com/apps/icons/com.termux.png -> .../apps/com.termux.apk.

This server therefore advertises <base>/<prefix>/icons/<pkg>.png and serves the APK at
<base>/<prefix>/<pkg>.apk. --log still shows every request; keep it on the first time.
"""
import argparse
import hashlib
import json
import mimetypes
import os
import re
import sys
import time
import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# 1x1 transparent PNG, used when no icon was supplied. The icon URL is load-bearing as a
# STRING (the client derives the APK folder from it) but its bytes are only cosmetic, so a
# 404 here is noise rather than a failure.
_PLACEHOLDER_ICON = base64.decodebytes(
    b"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

DEFAULT_INDEX = "index-10.json"
DEFAULT_APK_PREFIX = "apps-10/"
PKG_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$")


def apk_version(apk: Path) -> str:
    """Best-effort version without aapt: fall back to mtime date."""
    try:
        import subprocess

        for tool in ("aapt2", "aapt"):
            exe = shutil_which(tool)
            if not exe:
                continue
            out = subprocess.run([exe, "dump", "badging", str(apk)],
                                 capture_output=True, text=True, timeout=30).stdout
            m = re.search(r"versionName='([^']+)'", out)
            if m:
                return m.group(1)
    except Exception:
        pass
    return time.strftime("%Y-%m-%d", time.localtime(apk.stat().st_mtime))


def shutil_which(name: str):
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = Path(d) / name
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None


def default_icon_url(pkg: str, root: Path, base_url: str) -> str:
    """Absolute icon URL at the depth the client requires.

    Must be <scheme>://<host>/<folder>/<anything>/<file> — the client takes two parents of
    this path to find <folder>, which is where it then looks for <pkg>.apk.
    """
    return f"{base_url.rstrip('/')}/{DEFAULT_APK_PREFIX.strip('/')}/{pkg}/icon.png"


def build_index(root: Path, overrides: dict, base_url: str) -> dict:
    """Generate the vendor-shaped listing from the APKs present on disk."""
    entries = []
    apk_dir = root / "apks"
    for apk in sorted(apk_dir.glob("*.apk")):
        pkg = apk.stem
        if not PKG_RE.match(pkg):
            print(f"  skip (not a package name): {apk.name}", file=sys.stderr)
            continue
        meta = overrides.get(pkg, {})
        entry = {
            "app_name": meta.get("app_name", pkg),
            "package_name": pkg,
            "current_version": meta.get("current_version", apk_version(apk)),
            "updated": meta.get("updated", time.strftime("%m-%d-%Y",
                                                         time.localtime(apk.stat().st_mtime))),
            "apk_icon_url": meta.get("apk_icon_url", default_icon_url(pkg, root, base_url)),
        }
        for k, v in meta.items():
            if not k.startswith("_"):
                entry[k] = v
        entries.append(entry)
    return {"app_details": entries}


class Handler(BaseHTTPRequestHandler):
    server_version = "tt-store"
    root: Path = Path(".")
    index_name = DEFAULT_INDEX
    apk_prefix = DEFAULT_APK_PREFIX
    base_url = ""
    overrides: dict = {}
    log_requests = False

    def log_message(self, fmt, *args):
        if self.log_requests:
            sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def _send(self, body: bytes, ctype: str, code: int = 200):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _safe(self, rel: str) -> Path | None:
        p = (self.root / rel.lstrip("/")).resolve()
        try:
            p.relative_to(self.root.resolve())
        except ValueError:
            return None
        return p

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        path = self.path.split("?")[0]
        # The client fetches index.json AND index-10.json and merges them. Serve the same
        # listing for both so whichever it asks for second does not blank the store.
        if path in ("/", f"/{self.index_name}", "/index.json", "/index-10.json"):
            body = json.dumps(build_index(self.root, self.overrides, self.base_url),
                              indent=1).encode()
            if len(body) >= 100000:
                sys.stderr.write(
                    f"WARNING: listing is {len(body)} bytes; the client caps at 100000 and "
                    f"will show an EMPTY store. Trim entries.\n")
            return self._send(body, "application/json")

        # The listing advertises <apk_prefix><pkg>.apk and <apk_prefix>icons/<pkg>.png.
        # On disk those live as apks/<pkg>.apk and icons/<pkg>.png, so map the prefix to the
        # real directories rather than exposing the on-disk layout at the URL layer.
        prefix = "/" + self.apk_prefix.strip("/") + "/"
        if not path.startswith(prefix):
            self.log_message("404 %s", path)
            return self._send(b"not found\n", "text/plain", 404)

        rest = path[len(prefix):]
        parts = [p for p in rest.split("/") if p]

        # <prefix><pkg>/icon.png  ->  icons/<pkg>.png  (synthesise if absent)
        if len(parts) == 2 and parts[1] in ("icon.png", "icon.jpg"):
            icon = self._safe(f"icons/{parts[0]}.png")
            if icon is not None and icon.is_file():
                return self._send(icon.read_bytes(), "image/png")
            return self._send(_PLACEHOLDER_ICON, "image/png")

        # <prefix><pkg>.apk  ->  apks/<pkg>.apk
        if len(parts) == 1:
            target = self._safe(f"apks/{parts[0]}")
            if target is not None and target.is_file():
                ctype = (mimetypes.guess_type(target.name)[0]
                         or "application/octet-stream")
                return self._send(target.read_bytes(), ctype)

        self.log_message("404 %s", path)
        return self._send(b"not found\n", "text/plain", 404)


def main(argv=None):
    # Unbuffered: when stdout is a pipe or a log file — which is how anyone runs a server —
    # Python block-buffers it, so the operator sees no banner until the process exits. That
    # makes a working server look hung.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(line_buffering=True)
        except (AttributeError, ValueError):
            pass

    ap = argparse.ArgumentParser(description="Serve a ThermaSol app-store index + APKs.")
    ap.add_argument("--root", default="store", type=Path, help="content root (apks/, icons/)")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", default=8080, type=int)
    ap.add_argument("--index-name", default=DEFAULT_INDEX,
                    help="listing filename the panel requests (default index-10.json)")
    ap.add_argument("--apk-prefix", default=DEFAULT_APK_PREFIX,
                    help="URL prefix for APKs (adjust after observing the real request)")
    ap.add_argument("--base-url", default=None,
                    help="absolute base the panel will fetch from, e.g. http://10.0.1.5 "
                         "(required: icon URLs must be absolute or the client silently "
                         "refuses to install)")
    ap.add_argument("--log", action="store_true", help="log every request line")
    ap.add_argument("--print-index", action="store_true", help="print the index and exit")
    args = ap.parse_args(argv)

    root = args.root.resolve()
    overrides = {}
    meta = root / "meta.json"
    if meta.is_file():
        overrides = json.loads(meta.read_text())

    if not args.base_url:
        print("serve_store.py: --base-url is required (the panel needs absolute icon URLs)",
              file=sys.stderr)
        return 2
    base_url = args.base_url.rstrip("/")

    if args.print_index:
        print(json.dumps(build_index(root, overrides, base_url), indent=1))
        return 0

    Handler.base_url = base_url
    Handler.root = root
    Handler.index_name = args.index_name
    Handler.apk_prefix = args.apk_prefix
    Handler.overrides = overrides
    Handler.log_requests = args.log

    n = len(build_index(root, overrides, base_url)["app_details"])
    print(f"serving {n} app(s) from {root}")
    print(f"  listing : {base_url}/{args.index_name}  (+ /index.json, same body)")
    print(f"  apks    : {base_url}/{args.apk_prefix.strip('/')}/<package>.apk")
    if args.log:
        print("  logging every request — watch this to learn the real APK path")
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    raise SystemExit(main())

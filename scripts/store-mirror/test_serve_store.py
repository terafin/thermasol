#!/usr/bin/env python3
"""Contract tests for serve_store.py, written against the *client's* rules.

The panel derives the APK URL from apk_icon_url, so the test derives it the same way
(AppListingActivity.java:102-121) rather than assuming our own layout. If our server ever
disagrees with the client's derivation, these fail.

Run: python3 -I test_serve_store.py
"""
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent


def free_port() -> int:
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def client_apk_url(icon_url: str, package: str) -> str | None:
    """Faithful mirror of AppListingActivity.java:102-121.

    That code runs java.io.File over the URL *string*: it takes getParent(), then
    getParentFile(), then getName() of the result as the APK folder. Reproduce that
    literally — an intuitive "second-to-last segment" reading gets it wrong.
    """
    u = icon_url.split("?")[0]
    if "://" not in u:
        return None                                     # File.getParent() == null -> return
    parent = u.rsplit("/", 1)[0]                        # getParent()
    if "/" not in parent:
        return None                                     # getParentFile() == null -> return
    grandparent = parent.rsplit("/", 1)[0]              # getParentFile()
    folder = grandparent.rsplit("/", 1)[-1]             # .getName()
    scheme, rest = u.split("://", 1)
    host = rest.split("/", 1)[0]
    return f"{scheme}://{host}/{folder}/{package}.apk"


def main() -> int:
    fails = []

    def check(name, cond, detail=""):
        print(("PASS  " if cond else "FAIL  ") + name + (f"  [{detail}]" if detail and not cond else ""))
        if not cond:
            fails.append(name)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        (root / "apks").mkdir()
        (root / "icons").mkdir()
        (root / "apks" / "com.termux.apk").write_bytes(b"PK\x03\x04fake-apk-payload")
        (root / "apks" / "com.termux.boot.apk").write_bytes(b"PK\x03\x04fake-apk-payload-2")

        port = free_port()
        base = f"127.0.0.1:{port}"
        srv = subprocess.Popen(
            [sys.executable, "-I", str(HERE / "serve_store.py"),
             "--root", str(root), "--host", "127.0.0.1", "--port", str(port),
             "--base-url", f"http://{base}"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            # wait for readiness without a bare sleep
            deadline = time.time() + 10
            while time.time() < deadline:
                try:
                    socket.create_connection(("127.0.0.1", port), 0.2).close()
                    break
                except OSError:
                    time.sleep(0.05)
            else:
                print("FAIL  server never came up")
                return 1

            def get(path):
                try:
                    with urllib.request.urlopen(f"http://{base}{path}", timeout=5) as r:
                        return r.status, r.headers.get("Content-Type", ""), r.read()
                except urllib.error.HTTPError as e:
                    return e.code, e.headers.get("Content-Type", ""), b""

            for listing in ("/index-10.json", "/index.json"):
                st, ct, body = get(listing)
                check(f"{listing} 200", st == 200, f"status={st}")
                check(f"{listing} under 100 KB cap", len(body) < 100000, f"{len(body)} bytes")
                if st != 200:
                    continue
                doc = json.loads(body)
                check(f"{listing} has app_details", isinstance(doc.get("app_details"), list))
                for e in doc.get("app_details", []):
                    icon = e.get("apk_icon_url", "")
                    check(f"{listing} {e['package_name']} absolute icon url",
                          "://" in icon, icon)

                    apk_url = client_apk_url(icon, e["package_name"])
                    check(f"{listing} {e['package_name']} client can derive apk url",
                          apk_url is not None, icon)
                    if not apk_url:
                        continue
                    derived = apk_url.split(f"http://{base}", 1)[-1]
                    st2, ct2, data = get(derived)
                    check(f"{listing} {e['package_name']} derived apk 200", st2 == 200,
                          f"{derived} status={st2}")
                    check(f"{listing} {e['package_name']} apk mime",
                          ct2 == "application/vnd.android.package-archive", ct2)
                    check(f"{listing} {e['package_name']} apk non-empty", len(data) > 0)

                    st3, ct3, _ = get(icon.split(f"http://{base}", 1)[-1])
                    check(f"{listing} {e['package_name']} icon fetchable", st3 == 200,
                          f"status={st3}")

            st, _, _ = get("/apps-10/../../etc/passwd")
            check("path traversal blocked", st in (400, 403, 404), f"status={st}")
            st, _, _ = get("/apps-10/com.example.missing.apk")
            check("missing package 404", st == 404, f"status={st}")
        finally:
            srv.terminate()
            srv.wait(timeout=10)

    print()
    if fails:
        print(f"{len(fails)} FAILED")
        return 1
    print("all passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Install the exact official Godot templates, downloading selected ZIP entries.

Uses HTTP byte ranges; zipfile checks every extracted entry's CRC. Godot's
release archive is not repackaged or modified. Set XDG_DATA_HOME consistently
for this command and all Godot invocations.
"""
import argparse
import io
import os
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.6.3"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"


class HTTPFile(io.RawIOBase):
    def __init__(self, url):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60) as response:
            self.url = response.url
            self.length = int(response.headers["Content-Length"])
        self.pos = 0

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.length + offset
        return self.pos

    def read(self, count=-1):
        count = self.length - self.pos if count < 0 else min(count, self.length - self.pos)
        if count <= 0:
            return b""
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{self.pos + count - 1}"})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Release host did not honor HTTP Range; refusing full archive download")
            data = response.read()
        if len(data) != count:
            raise RuntimeError("Truncated archive range")
        self.pos += count
        return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("web", "android", "both"), default="both")
    args = parser.parse_args()
    target = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/export_templates" / f"{VERSION}.stable"
    names = ["version.txt"]
    if args.platform in ("web", "both"):
        names += ["web_nothreads_debug.zip", "web_nothreads_release.zip", "web_debug.zip", "web_release.zip"]
    if args.platform in ("android", "both"):
        names += ["android_debug.apk", "android_release.apk"]
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(HTTPFile(URL)) as archive:
        for name in names:
            dest = target / name
            info = archive.getinfo("templates/" + name)
            if dest.exists() and dest.stat().st_size == info.file_size:
                print("Present:", name, flush=True)
                continue
            print("Downloading:", name, f"({info.compress_size:,} bytes)", flush=True)
            temporary = dest.with_suffix(dest.suffix + ".tmp")
            temporary.write_bytes(archive.read(info))
            temporary.replace(dest)
    print("Templates installed:", target)


if __name__ == "__main__":
    main()

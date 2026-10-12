#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src/hidehook.m"
OUT="/var/jb/Library/MobileSubstrate/DynamicLibraries"
CFG="/var/jb/basebin/config.plist"
FAKELIB="/var/jb/basebin/.fakelib"

if [ ! -d /var/jb ]; then
  echo "Dopamine jbroot not found at /var/jb"
  exit 1
fi

mkdir -p "$OUT" /var/jb/basebin

SDK=""
if [ -d /usr/share/SDKs/iPhoneOS.sdk ]; then
  SDK="-isysroot /usr/share/SDKs/iPhoneOS.sdk"
elif [ -d /var/jb/usr/share/SDKs/iPhoneOS.sdk ]; then
  SDK="-isysroot /var/jb/usr/share/SDKs/iPhoneOS.sdk"
fi

CC=clang
if ! command -v clang >/dev/null 2>&1; then
  if [ -x /var/jb/usr/bin/clang ]; then
    CC=/var/jb/usr/bin/clang
  else
    echo "clang not found. install llvm + odcctools from Procursus, then rerun."
    exit 2
  fi
fi

echo "[*] compiling hidehook.dylib"
$CC $SDK -arch arm64 -miphoneos-version-min=15.0 -fobjc-arc -dynamiclib \
  -install_name @loader_path/hidehook.dylib \
  -framework Foundation -framework UIKit -framework CoreFoundation \
  -o /tmp/hidehook.dylib "$SRC"

if command -v ldid >/dev/null 2>&1; then
  ldid -S /tmp/hidehook.dylib
fi

cp /tmp/hidehook.dylib /var/jb/basebin/hidehook.dylib
cp /tmp/hidehook.dylib "$OUT/HideJailbreak.dylib"
ln -sf /var/jb/basebin/hidehook.dylib "$FAKELIB/hidehook.dylib" 2>/dev/null || true
cp "$ROOT/HideJailbreak.plist" "$OUT/HideJailbreak.plist"

python3 - <<'PY' || true
import plistlib, os, pathlib
cfg = pathlib.Path("/var/jb/basebin/config.plist")
data = {}
if cfg.exists():
    with cfg.open("rb") as f:
        data = plistlib.load(f)
ids = set(data.get("HideJailbreakBundleIDs") or [])
paths = set(data.get("HideJailbreakApps") or [])
defaults = [
    "com.alipay.iphoneclient","com.tencent.xin","com.tencent.mqq",
    "com.unionpay.chsp","com.unionpay.mobilepay","com.chinamworld.main",
    "com.icbc.iphoneclient","com.abc.iphoneclient","cmb.pb",
    "com.apple.Passbook","com.paypal.PPClient"
]
ids.update(defaults)
data["HideJailbreakBundleIDs"] = sorted(ids)
data["HideJailbreakApps"] = sorted(paths)
data["HideJailbreakDefaultsApplied"] = True
with cfg.open("wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_XML)
print("[*] updated", cfg)
PY

if command -v jbctl >/dev/null 2>&1; then
  jbctl trustcache add 2>/dev/null || true
fi
if [ -x /var/jb/basebin/jbctl ]; then
  /var/jb/basebin/jbctl rebuild_trustcache 2>/dev/null || true
fi

echo "[*] installed"
echo "    /var/jb/basebin/hidehook.dylib"
echo "    $OUT/HideJailbreak.dylib"
echo "    $OUT/HideJailbreak.plist"
echo "[*] kill and reopen bank apps, or respring: sbreload"

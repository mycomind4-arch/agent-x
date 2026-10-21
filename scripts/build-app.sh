#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
build_dir="$(pwd)/.build/local"
app_dir="$build_dir/WiFiStabilizer.app"
mkdir -p "$build_dir" "$app_dir/Contents/MacOS"

swiftc -parse-as-library -emit-module -module-name StabilizerCore \
  Sources/StabilizerCore/*.swift \
  -emit-module-path "$build_dir/StabilizerCore.swiftmodule"
swiftc -parse-as-library -whole-module-optimization -emit-object -module-name StabilizerCore \
  Sources/StabilizerCore/*.swift \
  -o "$build_dir/Diagnostics.o"

swiftc -I "$build_dir" \
  -framework CoreWLAN -framework CoreLocation -framework CoreBluetooth -framework Network -framework SwiftUI -framework Charts -framework AppKit -framework AVFoundation -framework Vision -framework SoundAnalysis \
  Sources/WiFiStabilizer/*.swift "$build_dir/Diagnostics.o" \
  -o "$app_dir/Contents/MacOS/WiFiStabilizer"

cp Info.plist "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir" >/dev/null
echo "$app_dir"

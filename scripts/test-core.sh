#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
build_dir="$(pwd)/.build/local"
mkdir -p "$build_dir"
swiftc -parse-as-library -emit-module -module-name StabilizerCore \
  Sources/StabilizerCore/*.swift \
  -emit-module-path "$build_dir/StabilizerCore.swiftmodule"
swiftc -parse-as-library -whole-module-optimization -emit-object -module-name StabilizerCore \
  Sources/StabilizerCore/*.swift \
  -o "$build_dir/Diagnostics.o"
swiftc -I "$build_dir" scripts/core-self-test.swift "$build_dir/Diagnostics.o" \
  -o "$build_dir/CoreSelfTest"
"$build_dir/CoreSelfTest"

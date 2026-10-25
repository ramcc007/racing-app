#!/usr/bin/env bash
# Runs the EchoLapCore game-logic tests on Linux, with no Mac needed (same approach as NumFall).
# Fetches Ubuntu's Swift 6.0.3 packages (archive.ubuntu.com) into a cache folder once, then runs `swift test`.
# The SwiftUI/SpriteKit app needs Apple's SDK and is built by .github/workflows/ios.yml on a GitHub Mac.
#
#   tools/swift/linux-swift.sh            # build and run all EchoLapCore tests
#   tools/swift/linux-swift.sh build      # any other swift package command
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
CACHE="${SWIFT_CACHE:-$HOME/.cache/echolap-swift}"
POOL=http://archive.ubuntu.com/ubuntu/pool
SWIFT_VER=6.0.3-2build1
XML_DEB=libxml2-16_2.14.5+dfsg-0.2ubuntu0.2_amd64.deb

if [ ! -x "$CACHE/root/usr/libexec/swift/bin/swift" ]; then
  echo "Fetching Swift $SWIFT_VER (about 500 MB, once)..."
  mkdir -p "$CACHE/root" "$CACHE/debs"
  for deb in "swiftlang_${SWIFT_VER}_amd64.deb" "libswiftlang_${SWIFT_VER}_amd64.deb"; do
    curl -fsS -o "$CACHE/debs/$deb" "$POOL/universe/s/swiftlang/$deb"
    dpkg-deb -x "$CACHE/debs/$deb" "$CACHE/root"
  done
  curl -fsS -o "$CACHE/debs/$XML_DEB" "$POOL/main/libx/libxml2/$XML_DEB"
  dpkg-deb -x "$CACHE/debs/$XML_DEB" "$CACHE/root"
  rm -rf "$CACHE/debs"
fi

export PATH="$CACHE/root/usr/libexec/swift/bin:$PATH"
export LD_LIBRARY_PATH="$CACHE/root/usr/lib/x86_64-linux-gnu:$CACHE/root/usr/libexec/swift/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$REPO/ios/EchoLapCore"
if [ $# -eq 0 ]; then set -- test; fi
exec swift "$@"

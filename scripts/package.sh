#!/usr/bin/env bash
# Makes the release zip for CurseForge: dist/Targetpad-<version>.zip.
# The zip holds one folder, Targetpad, with the addon and the license.
#   scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."
toc=addon/Targetpad/Targetpad.toc
version=$(sed -n 's/^## Version: //p' "$toc" | tr -d '\r')
if [ -z "$version" ]; then
  echo "error: no version in $toc" >&2
  exit 1
fi
# Every file that the TOC loads must be in the zip.
for file in $(grep -v '^#' "$toc" | tr -d '\r' | grep .); do
  if [ ! -f "addon/Targetpad/$file" ]; then
    echo "error: the TOC loads $file, but it is not there" >&2
    exit 1
  fi
done
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -r addon/Targetpad "$work/"
cp LICENSE "$work/Targetpad/"
mkdir -p dist
out="$(pwd)/dist/Targetpad-$version.zip"
rm -f "$out"
(cd "$work" && python3 -m zipfile -c "$out" Targetpad)
echo "packaged $version in $out"

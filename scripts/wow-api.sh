#!/usr/bin/env bash
# Gets the source of the WoW Forever client and checks the addon against it
# (scripts/api-check.sh). The pins below are the client that Targetpad is checked on.
# `--latest` uses the newest commit of the forever branch instead: the nightly
# job does this to find a client patch that breaks Targetpad.
#   scripts/wow-api.sh [--latest]
# The checkouts go to target/wow-api: ui is Gethe/wow-ui-source, and bir is
# Ketho/BlizzardInterfaceResources. Gnomish Relay pins the same commits.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

UI_REPO=https://github.com/Gethe/wow-ui-source
BIR_REPO=https://github.com/Ketho/BlizzardInterfaceResources
UI_COMMIT=172a387e3ab85b26e6640d3058d5ec1e6ccd4c63 # forever, 1.60.1.70450
BIR_COMMIT=c5a49d394564f20c508c71014d6f60d9cd240c71 # forever, 1.60.1.70338

case ${1:-} in
  --latest) UI_COMMIT=forever BIR_COMMIT=forever ;;
  "") ;;
  *) echo "error: unknown argument $1" >&2; exit 2 ;;
esac
work=target/wow-api

# A shallow fetch of one commit. It skips the fetch when the folder has it already.
fetch() {
  local dir=$1 repo=$2 commit=$3
  if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$commit" ]; then
    return
  fi
  rm -rf "$dir"
  git init -q "$dir"
  git -C "$dir" fetch -q --depth 1 "$repo" "$commit"
  git -C "$dir" checkout -q FETCH_HEAD
}

fetch "$work/ui" "$UI_REPO" "$UI_COMMIT"
fetch "$work/bir" "$BIR_REPO" "$BIR_COMMIT"
build=$(tr -d '[:space:]' < "$work/ui/version.txt")

# The TOC Interface number of 1.60.1 is 16001: major * 10000 + minor * 100 + patch.
IFS=. read -r major minor patch _ <<< "$build"
interface=$((major * 10000 + minor * 100 + patch))
toc=addon/Targetpad/Targetpad.toc
have=$(sed -n 's/^## Interface: *//p' "$toc" | tr -d ' \r')
case ",$have," in
  *",$interface,"*) ;;
  *)
    echo "error: the client is $build, so $toc needs $interface in ## Interface (it has $have)" >&2
    exit 1
    ;;
esac

scripts/api-check.sh "$work"

#!/usr/bin/env bash
# Checks every WoW global in wow.yml and every event Targetpad registers against the
# Forever client source. Give a folder with two checkouts of the forever branch:
#   <dir>/ui   Gethe/wow-ui-source
#   <dir>/bir  Ketho/BlizzardInterfaceResources
# Gnomish Relay keeps both in target/wow-api after its scripts/wow-api.sh runs.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
src=${1:?usage: scripts/api-check.sh <folder with ui and bir>}
res=$src/bir/Resources

# Names from other addons. Targetpad reads them only when they exist.
optional=""
# Lua and the bit library, not the WoW API.
# Enum is the client's table of enums; its members are checked through the docs.
builtin="date geterrorhandler seterrorhandler Enum"

known() {
  local name=$1
  grep -qF "\"$name\"" "$res/GlobalAPI.lua" "$res/FrameXML.lua" "$res/Frames.lua" && return 0
  grep -qE "^$name = " "$res/GlobalStrings/enUS.lua" && return 0
  # Namespaces (C_Timer) and globals that Blizzard's Lua or XML defines.
  grep -qF "\"$name." "$res/GlobalAPI.lua" && return 0
  grep -rqE "^(_G\.)?$name *=|name=\"$name\"" "$src/ui/Interface" --include=*.lua --include=*.xml && return 0
  return 1
}

failed=0
for name in $(sed -n 's/^  \([A-Za-z_][A-Za-z0-9_]*\):$/\1/p' wow.yml); do
  case " $optional $builtin " in *" $name "*) continue ;; esac
  case $name in Targetpad* | SLASH_TARGETPAD* | BINDING_HEADER_TARGETPAD) continue ;; esac
  if ! known "$name"; then
    echo "error: $name is not in the client" >&2
    failed=1
  fi
done
for call in $(grep -ohE "\bC_[A-Za-z]+\.[A-Za-z]+" addon/Targetpad/*.lua | sort -u); do
  if ! grep -qF "\"$call\"" "$res/GlobalAPI.lua"; then
    echo "error: $call is not in the client" >&2
    failed=1
  fi
done
# Events go through ns.on("EVENT"), or a list of them in Secure.lua that it loops over (none yet).
events=$( (grep -ohE 'ns\.on\("[A-Z_]+"' addon/Targetpad/*.lua
  awk '/for _, e in ipairs\(\{/,/ns\.on\(e/' addon/Targetpad/Secure.lua) | grep -oE '"[A-Z][A-Z_]+"' | tr -d '"' | sort -u)
for event in $events; do
  if ! grep -qF "\"$event\"" "$res/Events.lua"; then
    echo "error: event $event is not in the client" >&2
    failed=1
  fi
done
[ "$failed" = 0 ] && echo "api ok: $(tr -d '[:space:]' < "$src/ui/version.txt")"
exit "$failed"

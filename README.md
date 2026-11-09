# Targetpad

Target with a controller. Hold a button, step through nearby enemies, let go.

- **Hold**: a big gold arrow bobs over your target. With no enemy targeted,
  the nearest one is. Nothing else is drawn, so it works with any nameplates.
- **Step** with the d-pad, the right stick or the left stick (your choice), or
  the arrow keys: next and previous enemy, in the game's own order. The arrow
  follows.
- **Let go**: you keep the target, and the d-pad does what you bound again.

`/tp` to pick the hold button and what steps. The hold button is a normal game
binding, so it also shows in the game's Key Bindings menu under Targetpad.

Checks: `scripts/check.sh` (format, lint, tests) and `scripts/wow-api.sh`
(every API name against the client).

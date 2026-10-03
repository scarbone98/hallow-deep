# Hallow Deep

A Metroidvania for the Scareathon arcade. You play as **your own Scareathon
avatar**, spelunking the caves under the old cemetery to find your friend
Rowan, and the Hallowseed: the seed of the first jack-o'-lantern, whose roots
feed everything down there. Planting it is how Hallow Fields (game #2) wakes.

Godot 4.5, GDScript, web export (no threads), 320x180 at integer scale.

## The first slice

Nine rooms: Old Cemetery → The Sinkhole → Hollis's Lantern (save, story) →
Glowcap Hollow → The Roost → The Mire → Warden's Pit (boss: Mags, the Mire
Warden; reward: Bat Wings, the double jump) → back up the Roost → Sunken
Chapel → The Rim (ending). Plus a heart vessel behind the double jump and a
root wall that needs fire (a later ability).

## Layout

- `src/world/rooms.gd` — every room as a text map; legend at the top.
- `src/world/terrain.gd` — paints rock/brick/muck procedurally per theme, builds collision.
- `src/world/world.gd` — room loading, transitions, hazards, story beats, boss fight.
- `src/actors/` — player, enemies, the boss, pickups/things, fx.
- `src/avatar/avatar.gd` — builds the player sprite from a Scareathon avatar look.
- `src/ui/` — HUD, dialogue, map, touch buttons.
- `src/autoload/` — `Bridge` (arcade page), `Game` (save), `Sfx` (synthesised sound).

## Your avatar

`tools/sync_avatar.sh` copies the site's built avatar art
(`scareathon-v3/public/avatar-px`) into `assets/avatar-px`. In the arcade the
page sends `SCARATHON_USER`; the game then fetches `GET /user/looks?ids=<id>`
and draws that look. The site only has an idle loop, so run/jump/fall poses are
generated: head and body parts bob, and ground parts (legs, trousers, shoes)
are split into near and far legs that stride. Guests are one of the four kids.
Re-run the sync after new avatar items ship.

## The four kids

Alex, Joe, Jon and Matt are playable characters with full animation sets
(idle, run, jump/fall/land, double jump, a 3-hit sword combo, up and down
slashes, air swing, hurt, death, plus blended transition clips between them).
They're 3D-rendered pixel art from the spritechar pipeline (`~/tools/sprite3d`,
profile `hallow-deep`); `tools/sync_kids.sh` copies the sheets into
`assets/kids/`. Pick one on the title screen (left / right), or play as your
own avatar when the arcade has sent your look. `?outfit=joe` forces a kid.

`node tools/kid_test.mjs <kid>` plays a scripted run with `?trace=1` (every
animation frame logged to `window.__hdTrace`) and checks each state and
transition actually played.

## Checks

```
godot --headless --path . -s tools/check_rooms.gd   # maps are the right size, exits line up
python3 tools/reach.py                              # the slice can be finished; the wings gate holds
godot --headless --path . -s tools/avatar_sheet.gd  # shots/avatars.png: every outfit's poses
```

## Dev flags

`?room=<id>` start there · `?give=double_jump` · `?fresh` ignore the save ·
`?outfit=alex` wear a preview outfit · `?touch` show touch buttons.

## Build and screenshots

`tools/build_web.sh` exports to `build/web`; `tools/publish_pages.sh` publishes it to GitHub Pages (https://scarbone98.github.io/hallow-deep/). Serve it (`python3 -m http.server
8793` in build/web) and run `tools/shot.mjs` from a folder with playwright.

## Art

8 Bit Evil Returns sprites (`assets/sprites`), the Scareathon avatars, and
CC0 packs by ansimuz (`assets/cc0`, see its CREDITS.md).

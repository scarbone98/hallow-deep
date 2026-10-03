#!/usr/bin/env bash
# Copies the four kids' 3D-rendered sprite sheets (spritechar, profile "hallow-deep") into the
# game. Regenerate them with:  spritechar anim NAME all --profile hallow-deep && spritechar pack NAME --profile hallow-deep
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=${SRC:-$HOME/tools/sprite3d/chars}
mkdir -p assets/kids
for kid in alex joe jon matt; do
  cp "$SRC/$kid/hallow-deep/${kid}_sheet.png" "$SRC/$kid/hallow-deep/${kid}_sheet.json" assets/kids/
done
echo "synced $(ls assets/kids/*.json | wc -l) kid sheets"

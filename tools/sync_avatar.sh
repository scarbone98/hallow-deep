#!/usr/bin/env bash
# Copies the site's built avatar art (scareathon-v3/public/avatar-px) into the
# game, so every look can be drawn without asking the site for images. Run it
# after new avatar items ship (npm run art:avatar on the site).
set -euo pipefail
cd "$(dirname "$0")/.."
SITE=${SITE:-$HOME/scareathon-v3}
rm -rf assets/avatar-px
cp -r "$SITE/public/avatar-px" assets/avatar-px
mkdir -p assets/avatar-px/outfits
cp "$SITE"/pixel-avatar/outfits/*.json assets/avatar-px/outfits/
echo "synced $(ls assets/avatar-px/items | wc -l) items"

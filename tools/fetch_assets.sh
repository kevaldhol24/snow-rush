#!/bin/bash
# Re-download the large raw third-party packs that are NOT in git (D-016) into assets/raw_packs/.
# All CC0. Needs network access to quaternius.itch.io + itch's download CDN and dl.polyhaven.org.
# Run from the repo root:  bash tools/fetch_assets.sh
set -e
R=assets/raw_packs; T=$(mktemp -d)
mkdir -p $R
# Quaternius (itch.io free downloads)
bash tools/itch_dl.sh quaternius universal-animation-library   $T/ual1  "Standard"
bash tools/itch_dl.sh quaternius universal-animation-library-2 $T/ual2  "Standard"
bash tools/itch_dl.sh quaternius universal-base-characters     $T/ubc   "Standard"
bash tools/itch_dl.sh quaternius stylized-nature-megakit       $T/mega  "Standard"
mkdir -p $R/quaternius_ual $R/quaternius_base_characters $R/quaternius_nature_megakit
unzip -oq "$T/ual1/"*.zip -d $T/ual1/x && cp "$T/ual1/x/"*/Unreal-Godot/UAL1_Standard.glb $R/quaternius_ual/ && cp "$T/ual1/x/"*/License.txt $R/quaternius_ual/License_UAL1.txt
unzip -oq "$T/ual2/"*.zip -d $T/ual2/x && cp "$T/ual2/x/"*/Unreal-Godot/UAL2_Standard.glb $R/quaternius_ual/ && cp "$T/ual2/x/"*/License.txt $R/quaternius_ual/License_UAL2.txt
unzip -oq "$T/ubc/"*.zip -d $R/quaternius_base_characters
unzip -oq "$T/mega/"*.zip -d $R/quaternius_nature_megakit
# Poly Haven textures used in assets/textures/ (already committed; listed here for provenance)
mkdir -p $R/polyhaven
curl -sL -A "Mozilla/5.0" -o $R/polyhaven/snow_02_nor_gl_1k.jpg https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_02/snow_02_nor_gl_1k.jpg
rm -rf $T
echo "Done. Re-import in Godot; rider clips: godot --headless --path . res://scenes/dev/extract_rider_anims.tscn"

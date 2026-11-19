#!/usr/bin/env bash
# One-off build of the map boundaries in data/geo/. The output is committed,
# so you only need to run this if the boundaries themselves change.
#
#   bash data-raw/make-geo.sh
#
# Needs curl and Node.js (for npx mapshaper). Not run in CI.
#
# Sources (see data/geo/SOURCES.md for licences):
#   LGAs  ABS ASGS Edition 3, LGA 2024, via the ABS ArcGIS REST service
#   PHNs  Department of Health, PHN boundaries used by the NBRA (May 2017 V7)
#   LPHUs data-raw/lga_lphu.csv, transcribed from health.vic.gov.au
set -euo pipefail

cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mapshaper() { npx -y mapshaper@0.6 "$@"; }

echo "Downloading Victorian LGA boundaries (ABS)..."
curl -fsSL -o "$tmp/lga.json" \
  "https://geo.abs.gov.au/arcgis/rest/services/ASGS2024/LGA/MapServer/0/query?where=state_code_2021%3D%272%27&outFields=lga_code_2024,lga_name_2024&outSR=4326&maxAllowableOffset=0.002&geometryPrecision=5&f=geojson"

echo "Downloading PHN boundaries (data.gov.au)..."
curl -fsSL -o "$tmp/phn_aus.json" \
  "https://data.gov.au/data/dataset/ef2d28a4-1ed5-47d0-8e3a-46e25bc4f66b/resource/3fea565c-3b4e-4698-bd80-52396bb5bcd3/download/phn.geojson"

# Victorian PHNs only, with tidy field names.
mapshaper -i "$tmp/phn_aus.json" \
  -filter 'FIRST_STE_ == "2"' \
  -each 'phn = PHN_NAME' \
  -filter-fields phn \
  -o "$tmp/phn_vic.json"

# Drop the non-spatial ABS codes (no usual address, offshore) and
# unincorporated areas, then tidy field names and attach the LPHU.
mapshaper -i "$tmp/lga.json" \
  -filter '!/^(Migratory|No usual address|Unincorporated)/.test(lga_name_2024)' \
  -rename-fields lga_code=lga_code_2024,lga_name=lga_name_2024 \
  -join data-raw/lga_lphu.csv keys=lga_name,lga_name \
  -o "$tmp/lga_named.json"

# Assign each LGA to the PHN containing its interior point. A few LGAs on
# PHN borders (e.g. Macedon Ranges) are split; they go to whichever PHN holds
# that point, which is close enough for synthetic data.
mapshaper -i "$tmp/lga_named.json" \
  -points inner \
  -join "$tmp/phn_vic.json" fields=phn \
  -each 'metro = /Melbourne/.test(phn)' \
  -filter-fields lga_code,lga_name,phn,lphu,metro \
  -sort 'lga_name' \
  -o data-raw/lga_lookup.csv

# Simplified LGA layer, plus PHN and LPHU layers dissolved from it so the
# region maps line up exactly with the LGA data they summarise.
mkdir -p data/geo
mapshaper -i "$tmp/lga_named.json" \
  -join data-raw/lga_lookup.csv keys=lga_code,lga_code fields=phn string-fields=lga_code \
  -simplify 12% keep-shapes \
  -clean \
  -filter-fields lga_code,lga_name,phn,lphu \
  -o "$tmp/lga_simple.json"

mapshaper -i "$tmp/lga_simple.json" -o data/geo/lga.geojson precision=0.0001
mapshaper -i "$tmp/lga_simple.json" -dissolve phn -o data/geo/phn.geojson precision=0.0001
mapshaper -i "$tmp/lga_simple.json" -dissolve lphu -o data/geo/lphu.geojson precision=0.0001

ls -lh data/geo/*.geojson data-raw/lga_lookup.csv

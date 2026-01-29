#!/usr/bin/env bash
set -e

MARKER_FILE="$PGDATA/.osm_import_done"

if [ ! -f "$MARKER_FILE" ]; then
  echo "OSM not imported yet → running import"

  echo "Downloading Brazil OSM extract"
  wget -O /tmp/brazil-latest.osm.pbf \
    https://download.geofabrik.de/south-america/brazil-latest.osm.pbf

  echo "Running osm2pgsql import (this will take a while)"
  osm2pgsql \
    --create \
    --slim \
    --multi-geometry \
    --hstore \
    -d "$POSTGRES_DB" \
    -U "$POSTGRES_USER" \
    /tmp/brazil-latest.osm.pbf

  echo "OSM import complete → creating marker"
  touch "$MARKER_FILE"
else
  echo "OSM already imported → skipping"
fi

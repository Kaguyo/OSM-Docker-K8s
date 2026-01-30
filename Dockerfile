FROM postgis/postgis:15-3.4

# Install OSM tooling
RUN apt-get update && apt-get install -y \
    osm2pgsql \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Add our DB init scripts
COPY initdb /docker-entrypoint-initdb.d

# Containers need a default workdir
WORKDIR /docker-entrypoint-initdb.d

# Entrypoint and Cmd inherited from base image (Postgres entrypoint)
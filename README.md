# OSM + PostGIS (Brazil) — Deployment Lifecycle

This project provides a PostgreSQL + PostGIS database preloaded with OpenStreetMap
data for Brazil. The same container image is used across environments, with
different operational behaviors depending on the stage.

The architecture relies on **persistent volumes (PVC)** to guarantee data
survival across restarts and redeployments.

---

## 1. Test Environment (Local)

### Purpose
Validate:
- Postgres initialization
- PostGIS extensions
- Schema creation
- OSM import logic
- Volume persistence behavior

### Characteristics
- Runs **locally** using Docker / Docker Compose
- OSM data is **downloaded inside the container**
- Uses a **Docker volume** to simulate a Kubernetes PVC
- Designed for experimentation and debugging

### Workflow
1. Start the container locally
2. Docker creates a persistent volume
3. PostgreSQL initializes (`initdb`)
4. SQL and shell scripts in `/docker-entrypoint-initdb.d` run:
   - PostGIS extensions are enabled
   - GeocodeBR / custom schemas are created
   - Brazil OSM data is downloaded from Geofabrik
   - Data is imported and formatted using PostGIS
5. All data is written to the local volume
6. On container restart:
   - Existing volume is detected
   - Initialization and import are skipped
   - Database starts with persisted data

### Notes
!! Downloading OSM data inside the container is **acceptable only for local testing**.

---

## 2. Homologation Environment (Kubernetes – Controlled)

### Purpose
Validate:
- Kubernetes manifests
- PVC behavior
- Import execution in a real cluster
- Startup and restart semantics

### Characteristics
- Runs in a **real Kubernetes cluster**
- Uses a **Pod or Job** to execute the OSM import
- OSM data is **imported**, not downloaded at runtime
- Uses Kubernetes PVCs

### Workflow
1. Kubernetes provisions a PVC
2. A Kubernetes **Job or Init Pod**:
   - Has access to the OSM file (mounted or preloaded)
   - Runs the import process (`osm2pgsql`)
   - Writes all data to the PVC
3. PostgreSQL Pod starts:
   - Mounts the existing PVC
   - Detects pre-existing data
   - Skips initialization scripts
4. Database becomes available with imported OSM data

### Notes
  This stage validates real cluster behavior  
  No external downloads are required during DB startup  
  Failures can be retried safely

---

## 3. Production Environment (Kubernetes – Secure)

### Purpose
Run a stable, secure, and reproducible geospatial database in production.

### Characteristics
- Kubernetes `StatefulSet`
- Persistent Volume Claim (PVC)
- No public exposure of database internals
- No runtime downloads
- Environment variables injected securely

### Workflow
1. PVC is provisioned by the cluster
2. (Optional) One-time import Job prepares the PVC
3. PostgreSQL StatefulSet starts:
   - Mounts the PVC
   - Uses existing data only
   - Does not run initialization scripts again
4. Database serves requests normally

### Security Practices
- Credentials stored in **Kubernetes Secrets**
- No hardcoded passwords
- No exposed ports unless explicitly required
- Network access restricted via policies
- No outbound internet dependency

---

## Procedural Mapping Summary

| Stage        | Storage        | OSM Source        | Import Timing     |
|--------------|----------------|-------------------|-------------------|
| Test         | Docker Volume  | Download (live)   | On first startup  |
| Homologation | Kubernetes PVC | Mounted / Job     | One-time execution|
| Production   | Kubernetes PVC | Pre-imported data | Never at runtime  |

---

## Key Principles

- **PVC presence defines database state**
- **Initialization scripts run only once**
- **Data survives restarts and rescheduling**
- **Production never depends on external downloads**

---

## Final Note

This lifecycle ensures:
- Local simplicity
- Kubernetes correctness
- Production safety

The same database image can be reused across all stages with environment-specific orchestration.

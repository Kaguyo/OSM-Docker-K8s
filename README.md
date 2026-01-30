# OSM + PostGIS (Brazil) — Deployment Lifecycle

This project provisions a **PostgreSQL + PostGIS** database for Brazil using
**OpenStreetMap (OSM)** data, designed to run consistently across **test,
homologation, and production** using Kubernetes-native patterns.

Persistence is guaranteed through **Persistent Volume Claims (PVCs)**.
OSM ingestion is handled via a **one-time Kubernetes Job**, never coupled to
database startup.

---

## Repository Structure

```text
.
├── k8s/
│   ├── 00-namespace.yaml            # Kubernetes namespace (geodb)
│   ├── pg-pvc.yaml                  # PostgreSQL data PVC (15Gi)
│   ├── osm-data-pvc.yaml            # OSM data PVC (50Gi)
│   ├── postgres-statefulset.yaml    # PostgreSQL + PostGIS StatefulSet
│   ├── postgres-service.yaml        # Internal ClusterIP Service
│   ├── osm-import-job.yaml          # OSM import Job (test/homologation)
│   └── osm-import-job-prod.yaml     # OSM import Job (production – offline)
└── README.md
```

### Job Variants

- **`osm-import-job.yaml`** (test & homologation):
  - Downloads OSM data from Geofabrik if not present
  - Waits for Postgres readiness before importing
  - Skips download if file already exists (safe for retries)
  - Uses persistent `osm-data-pvc` for downloads

- **`osm-import-job-prod.yaml`** (production only):
  - **No downloads** — requires pre-loaded file in `osm-data-pvc`
  - Fails explicitly if file missing (ensures offline operation)
  - Waits for Postgres readiness before importing
  - Fully compliant with zero-internet-dependency principle

## 1. Test Environment (Minikube)

### Purpose
Validate:
- Kubernetes manifests
- Postgres + PostGIS setup
- PVC behavior
- OSM import workflow
- Data persistence across pod restarts

### Characteristics
- Runs locally using **Minikube**
- Real Kubernetes (not Docker Compose)
- Uses PVCs provisioned by Minikube
- OSM data downloaded during import (acceptable for testing)

### Deployment Procedure

```bash
# Start Minikube
minikube start

# Deploy in order
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/pg-pvc.yaml
kubectl apply -f k8s/osm-data-pvc.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/postgres-statefulset.yaml

# Wait for Postgres readiness
kubectl wait --for=condition=Ready pod -l app=postgres -n geodb --timeout=300s

# Deploy import job (uses osm-import-job.yaml – downloads if needed)
kubectl apply -f k8s/osm-import-job.yaml

# Monitor import progress
kubectl logs -f job/osm-import -n geodb

# Verify completion
kubectl get job osm-import -n geodb
```

### Workflow
1. Minikube cluster is started
2. Namespace and PVCs created
3. PostgreSQL + PostGIS runs as a **StatefulSet**
4. Job waits for Postgres, then:
   - Downloads Brazil OSM data (Geofabrik) into persistent `osm-data-pvc`
   - Imports data using `osm2pgsql`
   - Writes into Postgres via internal Service
5. Job completes and never runs again
6. PostgreSQL restarts reuse the same data PVCs

### Notes
- OSM download during this stage is acceptable and expected
- Database startup is never blocked by imports (Job waits for Postgres)
- PVC persistence allows testing restart behavior
- This stage mirrors production topology

---

## 2. Homologation Environment (Kubernetes – Controlled)

### Purpose
Validate:
- Production-grade Kubernetes manifests
- Import execution reliability
- PVC lifecycle and recovery
- Restart and rescheduling behavior

### Characteristics
- Runs in a real Kubernetes cluster
- Uses the same images as production
- OSM import executed via a **controlled Job**
- Downloads OSM data on first run, persists for retries

### Deployment Procedure

```bash
# Deploy in order
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/pg-pvc.yaml
kubectl apply -f k8s/osm-data-pvc.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/postgres-statefulset.yaml

# Wait for Postgres readiness
kubectl wait --for=condition=Ready pod -l app=postgres -n geodb --timeout=300s

# Deploy import job (uses osm-import-job.yaml – downloads if needed)
kubectl apply -f k8s/osm-import-job.yaml

# Monitor import progress
kubectl logs -f job/osm-import -n geodb

# Verify completion
kubectl get job osm-import -n geodb
```

### Workflow
1. Namespace and PVCs created
2. PostgreSQL StatefulSet starts and waits
3. Job waits for Postgres, then:
   - Downloads Brazil OSM data (Geofabrik) if not already in `osm-data-pvc`
   - Imports data using `osm2pgsql`
   - Writes into Postgres via internal Service
4. Job completes and can be safely retried
5. PostgreSQL restarts reuse persistent data

### Notes
- Import can be retried safely (file download skipped on subsequent runs)
- No coupling between Postgres lifecycle and ingestion
- PVC persistence enables controlled, repeatable deployments
- Job dependency on Postgres ensures no race conditions

---

## 3. Production Environment (Kubernetes – Secure)

### Purpose
Run a stable, secure, and reproducible geospatial database in production.

### Characteristics
- Kubernetes `StatefulSet`
- PVC-backed storage
- **Zero internet dependency** — OSM file pre-loaded
- One-time import (fully offline)
- No public database exposure

### Deployment Procedure

```bash
# Pre-deployment: Stage OSM file into osm-data-pvc
# This can be done via:
# - kubectl cp (small clusters)
# - Object storage (S3/GCS) with init container
# - Custom mount process specific to your infrastructure
#
# The file MUST be at: /data/brazil.osm.pbf in the PVC
# before the import job runs

# Deploy in order
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/pg-pvc.yaml
kubectl apply -f k8s/osm-data-pvc.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/postgres-statefulset.yaml

# Wait for Postgres readiness
kubectl wait --for=condition=Ready pod -l app=postgres -n geodb --timeout=300s

# Deploy import job (uses osm-import-job-prod.yaml – NO DOWNLOADS)
kubectl apply -f k8s/osm-import-job-prod.yaml

# Monitor import progress
kubectl logs -f job/osm-import -n geodb

# Verify completion
kubectl get job osm-import -n geodb
```

### Workflow
1. OSM file pre-loaded into `osm-data-pvc` (external process)
2. Namespace and PVCs created
3. PostgreSQL StatefulSet starts and waits
4. Job verifies OSM file exists, then:
   - Imports data using `osm2pgsql` (no download)
   - Writes into Postgres via internal Service
5. Job completes; fails explicitly if file is missing
6. PostgreSQL restarts reuse persistent data

### Pre-Loading the OSM File

```bash
# Example: Using kubectl cp (for small files only)
kubectl cp ./brazil.osm.pbf geodb/postgres-0:/data/brazil.osm.pbf

# Better: Use object storage or mounted volumes specific to your infrastructure
```

### Security Practices
- **Zero internet dependency** — no runtime downloads
- Credentials stored in **Kubernetes Secrets** (recommended future enhancement)
- No hardcoded values
- No public ports
- Restricted network access
- Explicit file verification (job fails if file missing)
- Production-optimized job variant (`osm-import-job-prod.yaml`)

---

## Procedural Mapping Summary

| Stage         | Platform   | OSM Source              | Job Variant              | Internet Required | Download Timing |
|---------------|------------|------------------------|--------------------------|-------------------|-----------------|
| Test          | Minikube   | Geofabrik (download)   | `osm-import-job.yaml`    | Yes               | First run only  |
| Homologation  | Kubernetes | Geofabrik (download)   | `osm-import-job.yaml`    | Yes               | First run only  |
| Production    | Kubernetes | Pre-loaded into PVC    | `osm-import-job-prod.yaml` | **No**           | Never           |

**Key Distinctions:**
- Test & Homologation use the **same job** — download OSM, import, persist
- Production uses **different job** — strict offline requirement, fails if file missing
- Homologation allows **retries** — file already persisted, download skipped
- Production **never downloads** — zero internet dependency

---

## Core Principles

- Database containers must be **boring** — no embedded import logic
- Imports must be **explicit and one-time** — separated from database lifecycle
- PVC presence defines database state — not container startup
- Restarts must never trigger re-imports — idempotent by design
- Production must **never depend on the internet** — enforced by job variant

---

## Troubleshooting

### Postgres pod not ready
```bash
kubectl describe pod postgres-0 -n geodb
kubectl logs postgres-0 -n geodb
```

### Import job fails
```bash
# Check job logs
kubectl logs job/osm-import -n geodb
kubectl describe job osm-import -n geodb

# Common issues:
# - Postgres not ready: Ensure StatefulSet is Running before job
# - Missing OSM file (production): Pre-load file into osm-data-pvc
# - Network download issues (test/homolog): Check internet connectivity
```

### Data validation
```bash
# Connect to database
kubectl exec -it postgres-0 -n geodb -- psql -U geo -d geodb

# Check if OSM tables exist
SELECT table_name FROM information_schema.tables WHERE table_schema='public';

# Query sample data
SELECT COUNT(*) FROM planet_osm_polygon LIMIT 5;
```

---

## Final Note

Minikube is not a "mock" — it is the **first-class test environment**.
If it works in Minikube with the same manifests, it works in production.

The architecture separates concerns intentionally:
- **Test**: Validate everything including downloads
- **Homologation**: Validate controlled retries and persistence
- **Production**: Validate offline operation with pre-loaded data

Only the **job variant** changes between stages; the database and storage architecture remain identical.

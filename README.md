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
│   ├── pg-pvc.yaml                  # Persistent Volume Claim
│   ├── postgres-statefulset.yaml    # PostgreSQL + PostGIS StatefulSet
│   ├── postgres-service.yaml        # Internal ClusterIP Service
│   └── osm-import-job.yaml          # One-time OSM import Job
└── README.md
```

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
- OSM data may be downloaded during import **for testing only**

### Workflow
1. Minikube cluster is started
2. PVC is created by the cluster
3. PostgreSQL + PostGIS runs as a **StatefulSet**
4. A Kubernetes **Job**:
   - Downloads Brazil OSM data (Geofabrik)
   - Imports data using `osm2pgsql`
   - Writes into Postgres via internal Service
5. Job completes and never runs again
6. PostgreSQL restarts reuse the same PVC

### Notes
- OSM download during this stage is acceptable
- Database startup is never blocked by imports
- This stage mirrors production topology as closely as possible

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
- No database startup scripts perform downloads

### Workflow
1. PVC is provisioned
2. One-time **OSM Import Job** runs:
   - Uses a mounted or pre-provisioned OSM file
   - Imports data into Postgres
3. PostgreSQL StatefulSet starts:
   - Mounts existing PVC
   - Uses only persisted data
4. Database becomes available

### Notes
- Import can be retried safely
- No coupling between Postgres lifecycle and ingestion
- No external network dependency after import

---

## 3. Production Environment (Kubernetes – Secure)

### Purpose
Run a stable, secure, and reproducible geospatial database in production.

### Characteristics
- Kubernetes `StatefulSet`
- PVC-backed storage
- One-time import (offline or controlled)
- No runtime downloads
- No public database exposure

### Workflow
1. PVC is provisioned
2. (Optional) One-time import Job prepares the data
3. PostgreSQL StatefulSet starts:
   - Mounts the PVC
   - Uses existing data only
4. Database serves internal consumers

### Security Practices
- Credentials stored in **Kubernetes Secrets**
- No hardcoded values
- No public ports
- Restricted network access
- Zero dependency on external downloads

---

## Procedural Mapping Summary

| Stage         | Platform   | Storage | OSM Source           | Import Timing |
|---------------|------------|---------|----------------------|---------------|
| Test          | Minikube   | PVC     | Download (Geofabrik) | One-time Job  |
| Homologation  | Kubernetes | PVC     | Mounted / Preloaded  | One-time Job  |
| Production    | Kubernetes | PVC     | Pre-imported         | Never runtime |

---

## Core Principles

- Database containers must be **boring**
- Imports must be **explicit and one-time**
- PVC presence defines database state
- Restarts must never trigger re-imports
- Production must not depend on the internet

---

## Final Note

Minikube is not a “mock” — it is the **first-class test environment**.
If it works in Minikube, it works in production.

The same images are reused across all stages; only orchestration changes.

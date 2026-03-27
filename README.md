# Tournabyte Infrastructure

This repository contains the infrastructure-as-code (IaC) for deploying a Tournabyte demo instance using Docker Compose. The stack consists of a three-node MongoDB replica set for the document store, a MinIO instance for S3-compatible object storage, a Go-based web API server, a Flutter-based web UI, and an Nginx ingress proxy.

## Repository Structure

```
.
├── etc/                        # Configuration files mounted into containers
│   ├── mongod/
│   │   ├── 001.conf            # mongod config for replica set node 1
│   │   ├── 002.conf            # mongod config for replica set node 2
│   │   └── 003.conf            # mongod config for replica set node 3
│   ├── nginx/
│   │   └── nginx.conf          # Nginx ingress proxy configuration
│   └── tournabyte/
│       └── webapi.json         # Web API application configuration
├── init/                       # Initialization scripts run before or during deployment
│   ├── deployment_secrets.sh   # Generates all required secrets into .env/
│   ├── ensure_mongo_replicaset.js  # Initializes the MongoDB replica set (JS, used by compose)
│   ├── ensure_mongo_rs.sh          # Initializes the MongoDB replica set (shell alternative)
│   ├── ensure_mongo_unprivileged_user.js  # Creates the app-level MongoDB user (JS, used by compose)
│   └── ensure_mongo_user.sh        # Creates the app-level MongoDB user (shell alternative)
└── deploy/                     # Docker Compose deployment manifests and Dockerfiles
    ├── compose.yaml            # Root compose file — includes all service definitions
    ├── record-store.yaml       # MongoDB replica set service definitions
    ├── object-store.yaml       # MinIO object store service definition
    ├── tournabyte-webapi.yaml  # Web API service definition
    ├── tournabyte-webui.yaml   # Web UI service definition
    ├── Dockerfile.webapi       # Builds the Go web API from source
    └── Dockerfile.webui        # Builds the Flutter web UI from source
```

Secrets are generated into a `.env/` directory at the repository root. This directory is excluded from version control.

---

## Prerequisites

- **Docker** with the Compose plugin (v2) — both the container engine and `docker compose` CLI
- **OpenSSL** — used by `init/deployment_secrets.sh` to generate random secrets and self-signed TLS certificates
- **Git** — required by the Dockerfiles to fetch source repositories at build time

---

## Step 1 — Configuration (`etc/`)

Before generating secrets or deploying services, review the configuration files in `etc/` and adjust them for your environment.

### MongoDB (`etc/mongod/`)

Each file configures one node of a three-member replica set named `infra-dev`. All three nodes listen on port `27017` and use the WiredTiger storage engine with per-database directories under `/data/db`.

| File | Hostname bound |
|------|----------------|
| `001.conf` | `infra-dev-001.mongodb.tournabyte.com` |
| `002.conf` | `infra-dev-002.mongodb.tournabyte.com` |
| `003.conf` | `infra-dev-003.mongodb.tournabyte.com` |

Key settings shared by all three nodes:

```yaml
security:
  authorization: "enabled"
  keyFile: "/run/secrets/mongo_cluster_keyfile"  # injected by compose
replication:
  replSetName: "infra-dev"
storage:
  dbPath: "/data/db"
  directoryPerDB: true
  engine: "wiredTiger"
```

- `authorization: "enabled"` means every client connection requires credentials.
- `keyFile` is the shared secret that authenticates replica set members to one another. It is mounted by Docker Compose from `.env/DBSHARD_KEYFILE.txt`.
- The `replSetName` must match across all three nodes and must also match the value used in `init/ensure_mongo_replicaset.js`.

To add a fourth replica set node, copy an existing `conf` file, update the `bindIp` hostname, add a corresponding service in `deploy/record-store.yaml`, and update the member list in `init/ensure_mongo_replicaset.js`.

### Nginx (`etc/nginx/nginx.conf`)

The Nginx configuration acts as an ingress proxy for the web application and the API. It defines two upstream blocks:

| Upstream | Backend host | Purpose |
|----------|-------------|---------|
| `app` | `app.tournabyte.com:80` | Flutter web UI |
| `api` | `api.tournabyte.com:80` | Go web API |

Both upstreams are exposed on port `80` inside the container. The ingress container maps host port `8080` to container port `80`. Modify `server_name` values and upstream host addresses if you change the service hostnames in the compose files.

### Web API (`etc/tournabyte/webapi.json`)

This JSON file is mounted into the web API container at `/etc/tournabyte/webapi.json` and controls runtime behaviour of the API server.

```jsonc
{
  "serve": {
    "port": "80",
    "security": {
      "useTLS": false,                               // set to true and provide cert/key for HTTPS
      "certificateFile": "/run/secrets/tls_certificate",
      "keychainFile": "/run/secrets/tls_keychain"
    },
    "sessions": {
      "signingAlgorithm": "HS256",
      "signingKeyFile": "/run/secrets/token_signing_key",
      "accessTokenTTL": "15m",
      "refreshTokenTTL": "72h",
      "tokenIssuer": "api.tournabyte.com",
      "tokenSubject": "Tournabyte API authorization"
    }
  },
  "mongodb": {
    "hosts": [                                       // must match replica set member hostnames
      "infra-dev-001.mongodb.tournabyte.com",
      "infra-dev-002.mongodb.tournabyte.com",
      "infra-dev-003.mongodb.tournabyte.com"
    ],
    "username": "/run/secrets/mongo_username",       // path to Docker secret file
    "password": "/run/secrets/mongo_password"
  },
  "minio": {
    "endpoint": "localhost:9000",
    "accessKey": "/run/secrets/minio_access_id",
    "secretKey": "/run/secrets/minio_access_key"
  }
}
```

- All `"/run/secrets/..."` paths are populated automatically by Docker Compose from the `.env/` files.
- The `hosts` array must list the same hostnames used in `etc/mongod/*.conf` and in `init/ensure_mongo_replicaset.js`.
- Set `"useTLS": true` for production deployments. The self-signed certificate generated by `deployment_secrets.sh` is sufficient for a demo.

---

## Step 2 — Initialization (`init/`)

Once configuration files have been reviewed, run the initialization script to generate all secrets required by the deployment. This only needs to be done once per environment (or whenever you want to rotate secrets).

### Generating secrets

From the **repository root**, run:

```bash
$ bash init/deployment_secrets.sh
```

The script uses `openssl` to create random values and writes each secret to its own file under `.env/` at the repository root. The directory is created with `700` permissions; individual secret files are created with `600` or `400` permissions.

The following files are generated:

| File | Purpose | Default value |
|------|---------|---------------|
| `.env/DBROOT_USERNAME.txt` | MongoDB root username | `mongoadmin` |
| `.env/DBROOT_PASSWORD.txt` | MongoDB root password | random (128 bytes) |
| `.env/DBSHARD_KEYFILE.txt` | MongoDB replica set shared key | random (512 bytes) |
| `.env/API_DB_USERNAME.txt` | MongoDB application username | `tbyte-user` |
| `.env/API_DB_PASSWORD.txt` | MongoDB application password | random (128 bytes) |
| `.env/S3ROOT_USERNAME.txt` | MinIO root username | `minioadmin` |
| `.env/S3ROOT_PASSWORD.txt` | MinIO root password | random (128 bytes) |
| `.env/API_S3_ACCESS_ID.txt` | MinIO application access ID | `minioadmin` |
| `.env/API_S3_ACCESS_KEY.txt` | MinIO application access key | random (128 bytes) |
| `.env/JWT_SECRET_KEY.txt` | JWT token signing key | random (32 bytes) |
| `.env/API_TLS_KEYCHAIN.txt` | TLS private key (RSA 4096) | self-signed |
| `.env/API_TLS_CERTIFICATE.txt` | TLS certificate (30-day, self-signed) | self-signed |

> **Warning:** Re-running the script overwrites all existing secrets. If the MongoDB data volumes already exist and contain data initialised with the old credentials, dropping and re-creating the volumes will be required after a secret rotation.

### What happens during `docker compose up`

Two additional short-lived containers run automatically as part of the compose stack to finish initializing MongoDB:

1. **`ensurereplicaset`** — waits for all three `mongodb0X` containers to pass their health checks, then runs `init/ensure_mongo_replicaset.js` via `mongosh` against the primary node. This script calls `rs.initiate()` with the three-member configuration. If the replica set is already initialized, it is a no-op.

2. **`ensureunprivilegeduser`** — runs after `ensurereplicaset` completes successfully. It executes `init/ensure_mongo_unprivileged_user.js` against the replica set, creating the application-level user (`API_DB_USERNAME`) with `readWrite` access to the `tournabyte` database. If the user already exists, it is a no-op.

These scripts are mounted directly from `init/` into the containers at runtime — there is no need to copy them manually.

---

## Step 3 — Deployment (`deploy/`)

With configuration reviewed and secrets generated, start the full stack from the `deploy/` directory.

### Starting the stack

```bash
$ cd deploy
$ docker compose up -d
```

Docker Compose will:

1. Pull the `mongo:8.2-rc`, `quay.io/minio/minio`, and `nginx:stable-alpine` images.
2. Build the `apidemo` and `appdemo` images from `Dockerfile.webapi` and `Dockerfile.webui` respectively. Each Dockerfile fetches the application source from GitHub and compiles it inside a multi-stage build.
3. Start all services in dependency order:
   - MongoDB nodes (`mongodb01`, `mongodb02`, `mongodb03`)
   - MinIO (`minio_dev`)
   - Replica set init job (`ensurereplicaset`)
   - App user creation job (`ensureunprivilegeduser`)
   - Web API server (`apiserver`)
   - Web UI server (`appserver`)
   - Nginx ingress (`ingress`)

The following ports are exposed on the host:

| Host port | Service | Description |
|-----------|---------|-------------|
| `8080` | Nginx | HTTP ingress for the web app and API |
| `27017` | MongoDB | Direct access to the replica set |
| `9000` | MinIO | S3-compatible API endpoint |
| `9001` | MinIO | MinIO web console |

Once the stack is running, the web UI is accessible at [http://localhost:8080](http://localhost:8080) and the API is accessible at [http://localhost:8080/api](http://localhost:8080) (routed via Nginx).

### Compose file layout

The root compose file (`compose.yaml`) uses `include:` to pull in the individual service files:

| File | Services defined |
|------|----------------|
| `record-store.yaml` | `mongodb01`, `mongodb02`, `mongodb03`, `ensurereplicaset`, `ensureunprivilegeduser` |
| `object-store.yaml` | `minio_dev` |
| `tournabyte-webapi.yaml` | `apiserver` |
| `tournabyte-webui.yaml` | `appserver` |
| `compose.yaml` | `ingress` (and the `include:` directives above) |

Each service file also declares its own `secrets:` block, mapping Docker secret names to files under `.env/`.

### Stopping the stack

```bash
$ docker compose stop
```

- Services are stopped but containers and volumes are preserved.
- Restart with `docker compose start`.

### Tearing down the stack

```bash
$ docker compose down -v
```

- Removes containers **and** named volumes (MongoDB data and MinIO object data).
- Use this when you want a completely clean deployment, or after rotating secrets.

### Rebuilding application images

If you need to pick up changes from the upstream source repositories:

```bash
$ docker compose build --no-cache apiserver appserver
$ docker compose up -d
```

The `GIT_BRANCH` build argument for `apiserver` is set to `patch-config` in `tournabyte-webapi.yaml`. Override it at build time to target a different branch:

```bash
$ docker compose build --build-arg GIT_BRANCH=main apiserver
```


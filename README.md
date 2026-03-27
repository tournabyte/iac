# Tournabyte Infrastructure

The tournabyte platform utilizes MongoDB and MinIO for storing data. The MongoDB instance provides the document database the API service uses to record and modify data records. The MinIO instance provides an S3 compatible API for retrieving and storing binary objects. These services are containerized for local development and as a stepping stone to maintain cloud-native status per the project goals.

## Services

The services offered within the data infrastructure are specified in the `compose.yaml` file. This file contains the docker image and run specification to get the local instances running inside local containers.

### Prerequisites

To run the data infrastructure for the Tournabyte platform the following requirements must be met.

- Install docker (both container engine and compose tool set)
- Configure the setup secrets (see the configuration section below)

### Starting the services

To run the data infrastructure for the Tournabyte platform, simply run the following

```bash
$ docker compose up -d
```

- The command should be run inside the directory containing the `compose.yaml` file
- The services will set up the required volumes and read the required environment variables

### Stopping the services

To stop the data infrastructure for the Tournabyte platform, simply run the following

```bash
$ docker compose stop
```

- The data services will no longer be available on their respective ports
- The data volumes will be preserved for future runs
- The services can be restarted by running `docker compose start`

## Configuration

### Secrets

The `init/` subdirectory contains a simple tool that helps initialize data infrastructure secrets. Use the tool from the directory containing this file. Invoke it as follows:

```bash
$ ./init/secret.py --help
usage: secret.py [-h] [--value] [--generate] [--length LENGTH] [key]

Initialize secrets for the infrastructure's environment

positional arguments:
  key              Secret key name

options:
  -h, --help       show this help message and exit
  --value          Read secret value interactively
  --generate       Generate random value
  --length LENGTH  Length for generated secrets (default: 32)
```

- The secrets will be automatically written to `.env/` as a subdirectory on this file's current directory
- Re-running this tool with the same arguments will *overwrite* the existing secret
- Supported secrets are currently:
  - `DBROOT01_USERNAME`: the root user for the primary `mongod` instance
  - `DBROOT01_PASSWORD`: the root password for the primary `mongod` instance
  - `DBROOT0X_PASSWORD`: the root password for secondary `mongod` instances
  - `DBROOT0X_USERNAME`: the root username for secondary `mongod` instances
  - `S3ROOT_USERNAME`: the root user for the minIO instance
  - `S3ROOT_PASSWORD`: the root password for the minIO instance 
  - `JWT_SECRET_KEY`: the secret key for signing tokens produced by the API server
  - `DBSHARD_KEYFILE`: the key file for the `mongod` replica set
- The secrets are not checked into version control for security reasons

### Files

The `etc/` subdirectory contains the configuration files for the data services. Currently there is one file for each `mongod` server process in a replica set. It is recommended to create additional configuration files based on existing copies.


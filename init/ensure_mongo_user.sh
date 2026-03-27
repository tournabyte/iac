#!/user/bin/env bash

set -euo pipefail

# ---Configuration---

MEMBERS=(
  "infra-dev-001.mongodb.tournabyte.com:27017"
  "infra-dev-002.mongodb.tournabyte.com:27017"
  "infra-dev-003.mongodb.tournabyte.com:27017"
)
RSNAME="infra-dev"

AUTHDB="admin"
ADMINUSER=$(</run/secrets/mongodb_root_user)
ADMINPASS=$(</run/secrets/mongodb_root_pass)
DBUSER=$(</run/secrets/mongo_api_user)
DBPASS=$(</run/secrets/mongo_api_pass)

MONGO_URI="mongodb://${MEMBERS[0]},${MEMBERS[1]},${MEMBERS[2]}/replicaSet=${RSNAME}"

# ---Create user if it does not exist ---

USER_EXISTS=$()

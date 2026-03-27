#!/usr/bin/env bash

set -euo pipefail

# ---RS CONFIG---

MEMBERS=(
  "infra-dev-001.mongodb.tournabyte.com:27017"
  "infra-dev-002.mongodb.tournabyte.com:27017"
  "infra-dev-003.mongodb.tournabyte.com:27017"
)
RSNAME="infra-dev"
PRIMARY=${MEMBERS[0]}

AUTHDB="admin"
DBUSER=$(</run/secrets/mongodb_root_user)
DBPASS=$(</run/secrets/mongodb_root_pass)

# ---Functions---

mongoEval() {
  local host="$1"
  mongosh --host "$host" --username "$DBUSER" --password "$DBPASS" --authenticationDatabase "$AUTHDB" --eval "$2"
}

# ---Configure RS if needed---

echo "Waiting for ${PRIMARY} to be ready..."
sleep 30

if mongoEval "$PRIMARY" "rs.status()" | grep -q "1"; then
  echo "Replica set already initialized. Exiting."
  exit 0
fi

echo "Replica set not yet initialized. Proceeding..."
CONFIG="{
  _id: \"$RSNAME\",
  members: [
"

for i in "${!MEMBERS[@]}"; do
  CONFIG+="    { _id: $i, host: \"${MEMBERS[$i]}\" }"
  if [ "$i" -lt $((${#MEMBERS[@]} - 1)) ]; then
    CONFIG+=","
  fi
  CONFIG+="
"
done

CONFIG+="  ]
}"

echo Configuring replica set as follows: ${CONFIG}
mongoEval "$PRIMARY" "rs.initiate($CONFIG).ok"

echo "Replica set successfully initiated. Exiting"
mongoEval "$PRIMARY" "rs.status()"
exit 0

#! /usr/bin/env bash

MINIO_ENDPOINT="http://minio.tournabyte.com:9000"
MINIO_ADMIN_ACCESS_KEY=$(</run/secrets/minio_root_user)
MINIO_ADMIN_SECRET_KEY=$(</run/secrets/minio_root_pass)
MINIO_APP_ACCESS_KEY=$(</run/secrets/minio_app_user)
MINIO_APP_SECRET_KEY=$(</run/secrets/minio_app_pass)
MINIO_APP_POLICY_NAME="tbyte-webapi"
MINIO_APP_POLICY_FILE="/var/minio/policies/webapi.json"

mc alias set infra-dev ${MINIO_ENDPOINT} ${MINIO_ADMIN_ACCESS_KEY} ${MINIO_ADMIN_SECRET_KEY}

echo "Creating user: $MINIO_APP_ACCESS_KEY"
mc admin user add infra-dev $MINIO_APP_ACCESS_KEY $MINIO_APP_SECRET_KEY || {
  echo "User may already exist, continuing..."
}

echo "Creating policy $MINIO_APP_POLICY_NAME"
mc admin policy create infra-dev $MINIO_APP_POLICY_NAME $MINIO_APP_POLICY_FILE || {
  echo "Policy may already exist, continuing..."
}

echo "Attaching policy $MINIO_APP_POLICY_NAME to the $MINIO_APP_ACCESS_KEY user"
mc admin policy attach infra-dev $MINIO_APP_POLICY_NAME --user $MINIO_APP_ACCESS_KEY

echo "Done."

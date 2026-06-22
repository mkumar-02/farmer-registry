#!/bin/sh
set -e

# ──────────────────────────────────────────────────────────────
# OpenG2P Registry DB Seed Entrypoint
#
# Registry database:
#   PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD
#   LOAD_SAMPLE_DATA — "true" to load sample data (default: "false")
#   LOAD_TEMPLATES   — "true" to upload templates to MinIO (default: "false")
#   LOAD_ESIGNET_IDENTITIES — "true" to seed mock eSignet identities from openg2p-data
#   REGISTRANT_AUTH_SEED_ENABLED — "true" to seed g2p_registrant_authentication_providers
#   CREATE_ESIGNET_OAUTH_CLIENT — "true" to register OAuth client via eSignet client-mgmt API
#   ESIGNET_KEYCLOAK_TOKEN_URL, ESIGNET_KEYCLOAK_CLIENT_ID, ESIGNET_KEYCLOAK_CLIENT_SECRET
#   ESIGNET_OAUTH_CLIENT_NAME, ESIGNET_RELYING_PARTY_ID
#   REGISTRANT_AUTH_PROVIDER_ID — provider row to receive client_private_key
#   REGISTRANT_AUTH_CLIENT_PRIVATE_KEY_FILE / REGISTRANT_AUTH_CLIENT_PRIVATE_KEY
#   ESIGNET_BASE_URL, REGISTRANT_AUTH_CLIENT_ID, REGISTRANT_AUTH_OAUTH_CALLBACK_URL
#   REGISTRANT_AUTH_TOKEN_ENDPOINT_AUTH_METHOD (default: private_key_jwt)
#   ESIGNET_SEED_PROFILE — individuals|farmers (default: individuals)
#   MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY — MinIO connection
#   MINIO_SECURE     — "true" for HTTPS (default: "false")
#   TEMPLATE_BUCKET_NAME — MinIO bucket (default: "template")
#   TEMPLATES_DIR    — path to flat .j2 files (default: /seed/templates)
#
# AWE database (implementation extension data; optional):
#   AWE_DB_SEED_ENABLED — "true" to seed the AWE Postgres database
#   AWE_PGHOST, AWE_PGPORT, AWE_PGDATABASE, AWE_PGUSER, AWE_PGPASSWORD
#   AWE_CALLBACK_HMAC_SECRET — callback_secret row + registry staff API
# ──────────────────────────────────────────────────────────────

PGPORT="${PGPORT:-5432}"
LOAD_SAMPLE_DATA="${LOAD_SAMPLE_DATA:-false}"
LOAD_TEMPLATES="${LOAD_TEMPLATES:-false}"
LOAD_ESIGNET_IDENTITIES="${LOAD_ESIGNET_IDENTITIES:-false}"
AWE_DB_SEED_ENABLED="${AWE_DB_SEED_ENABLED:-false}"
REGISTRANT_AUTH_SEED_ENABLED="${REGISTRANT_AUTH_SEED_ENABLED:-false}"

SEED_DIR="/seed"
META_DATA_DIR="${SEED_DIR}/meta_data"
SAMPLE_DATA_DIR="${SEED_DIR}/sample_data"
AWE_META_DATA_DIR="${SEED_DIR}/awe_meta_data"

run_sql_files() {
  dir="$1"
  label="$2"
  db_host="${3:-$PGHOST}"
  db_port="${4:-$PGPORT}"
  db_name="${5:-$PGDATABASE}"
  db_user="${6:-$PGUSER}"
  db_password="${7:-$PGPASSWORD}"

  if [ ! -d "$dir" ]; then
    echo "[db-seed] No ${label} directory found at ${dir}, skipping."
    return
  fi

  sql_files=$(find "$dir" -name '*.sql' -type f | sort)
  if [ -z "$sql_files" ]; then
    echo "[db-seed] No SQL files found in ${dir}, skipping."
    return
  fi

  echo "[db-seed] Running ${label} on ${db_name}@${db_host}:${db_port} ..."
  PGHOST="$db_host" PGPORT="$db_port" PGDATABASE="$db_name" PGUSER="$db_user" PGPASSWORD="$db_password"
  export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD
  for f in $sql_files; do
    echo "[db-seed]   -> $(basename "$f")"
    psql -v ON_ERROR_STOP=0 -f "$f"
  done
  echo "[db-seed] ${label} completed."
}

run_callback_secret() {
  tpl="${AWE_META_DATA_DIR}/40_callback_secret.sql.tpl"
  if [ ! -f "$tpl" ]; then
    return
  fi
  if [ -z "$AWE_CALLBACK_HMAC_SECRET" ]; then
    echo "[db-seed] AWE_CALLBACK_HMAC_SECRET unset — skipping callback_secret."
    return
  fi
  echo "[db-seed]   -> callback_secret (AWE DB, from template)"
  export AWE_CALLBACK_HMAC_SECRET
  PGHOST="${AWE_PGHOST}" PGPORT="${AWE_PGPORT:-5432}" PGDATABASE="${AWE_PGDATABASE}" \
    PGUSER="${AWE_PGUSER}" PGPASSWORD="${AWE_PGPASSWORD}" \
    envsubst '${AWE_CALLBACK_HMAC_SECRET}' < "$tpl" | psql -v ON_ERROR_STOP=0 -f -
}

run_registrant_auth_providers() {
  tpl="${META_DATA_DIR}/registrant-authentication/g2p_registrant_authentication_providers.sql.tpl"
  if [ ! -f "$tpl" ]; then
    return
  fi
  if [ "${REGISTRANT_AUTH_SEED_ENABLED}" != "true" ]; then
    echo "[db-seed] Skipping registrant auth providers (REGISTRANT_AUTH_SEED_ENABLED=${REGISTRANT_AUTH_SEED_ENABLED})."
    return
  fi
  if [ -z "$REGISTRANT_AUTH_CLIENT_ID" ] || [ -z "$REGISTRANT_AUTH_OAUTH_CALLBACK_URL" ]; then
    echo "[db-seed] REGISTRANT_AUTH_CLIENT_ID or REGISTRANT_AUTH_OAUTH_CALLBACK_URL unset — skipping registrant auth providers."
    return
  fi
  export ESIGNET_BASE_URL="${ESIGNET_BASE_URL:-https://esignet.qa.openg2p.net}"
  export REGISTRANT_AUTH_CLIENT_ID
  export REGISTRANT_AUTH_CLIENT_SECRET="${REGISTRANT_AUTH_CLIENT_SECRET:-}"
  export REGISTRANT_AUTH_OAUTH_CALLBACK_URL
  export REGISTRANT_AUTH_TOKEN_ENDPOINT_AUTH_METHOD="${REGISTRANT_AUTH_TOKEN_ENDPOINT_AUTH_METHOD:-private_key_jwt}"
  export REGISTRANT_AUTH_KEYMANAGER_SIGN_APP_ID="${REGISTRANT_AUTH_KEYMANAGER_SIGN_APP_ID:-}"
  echo "[db-seed]   -> g2p_registrant_authentication_providers (from template)"
  envsubst '$ESIGNET_BASE_URL $REGISTRANT_AUTH_CLIENT_ID $REGISTRANT_AUTH_CLIENT_SECRET $REGISTRANT_AUTH_OAUTH_CALLBACK_URL $REGISTRANT_AUTH_TOKEN_ENDPOINT_AUTH_METHOD $REGISTRANT_AUTH_KEYMANAGER_SIGN_APP_ID' \
    < "$tpl" | psql -v ON_ERROR_STOP=0 -f -
}

run_create_esignet_oauth_client() {
  if [ "${CREATE_ESIGNET_OAUTH_CLIENT}" != "true" ]; then
    return
  fi
  if [ -z "$ESIGNET_KEYCLOAK_TOKEN_URL" ] || [ -z "$ESIGNET_KEYCLOAK_CLIENT_ID" ] || [ -z "$ESIGNET_KEYCLOAK_CLIENT_SECRET" ]; then
    echo "[db-seed] CREATE_ESIGNET_OAUTH_CLIENT but Keycloak env incomplete — skipping."
    return
  fi
  if [ -z "$REGISTRANT_AUTH_CLIENT_ID" ] || [ -z "$REGISTRANT_AUTH_OAUTH_CALLBACK_URL" ]; then
    echo "[db-seed] CREATE_ESIGNET_OAUTH_CLIENT but client/callback unset — skipping."
    return
  fi
  export ESIGNET_BASE_URL="${ESIGNET_BASE_URL:-https://esignet.qa.openg2p.net}"
  export ESIGNET_OAUTH_CLIENT_ID="${REGISTRANT_AUTH_CLIENT_ID}"
  export ESIGNET_OAUTH_CLIENT_NAME="${ESIGNET_OAUTH_CLIENT_NAME:-Registrant eSignet}"
  export ESIGNET_RELYING_PARTY_ID="${ESIGNET_RELYING_PARTY_ID:-openg2p-auth-partner}"
  export ESIGNET_CLIENT_PRIVATE_KEY_PATH="${ESIGNET_CLIENT_PRIVATE_KEY_PATH:-/tmp/esignet-client-private-key.pem}"
  echo "[db-seed] Creating eSignet OAuth client ${REGISTRANT_AUTH_CLIENT_ID} ..."
  python3 /openg2p-data/scripts/create_esignet_oauth_client.py
  export REGISTRANT_AUTH_CLIENT_PRIVATE_KEY_FILE="${ESIGNET_CLIENT_PRIVATE_KEY_PATH}"
}

run_registrant_auth_private_key() {
  if [ "${REGISTRANT_AUTH_SEED_ENABLED}" != "true" ]; then
    return
  fi
  if [ -z "$REGISTRANT_AUTH_PROVIDER_ID" ]; then
    return
  fi
  if [ -z "$REGISTRANT_AUTH_CLIENT_PRIVATE_KEY_FILE" ] && [ -z "$REGISTRANT_AUTH_CLIENT_PRIVATE_KEY" ]; then
    echo "[db-seed] No registrant auth private key provided — skipping client_private_key update."
    return
  fi
  echo "[db-seed] Updating registrant auth client_private_key for ${REGISTRANT_AUTH_PROVIDER_ID} ..."
  python3 /openg2p-data/scripts/update_registrant_auth_private_key.py
}

echo "============================================="
echo " OpenG2P Registry DB Seed"
echo " Extension : ${EXTENSION_FOLDER:-unknown}"
echo " Registry DB : ${PGDATABASE}@${PGHOST}:${PGPORT}"
echo " AWE DB seed : ${AWE_DB_SEED_ENABLED}"
echo " Sample data : ${LOAD_SAMPLE_DATA}"
echo " Templates   : ${LOAD_TEMPLATES}"
echo " E-Signet seed : ${LOAD_ESIGNET_IDENTITIES}"
echo " Registrant auth: ${REGISTRANT_AUTH_SEED_ENABLED}"
echo "============================================="

# 1. Registry meta_data (includes awe-integration mappings under meta_data/)
run_sql_files "$META_DATA_DIR" "meta-data"
run_create_esignet_oauth_client
run_registrant_auth_providers
run_registrant_auth_private_key

# 2. Optionally run sample data scripts
if [ "$LOAD_SAMPLE_DATA" = "true" ]; then
  run_sql_files "$SAMPLE_DATA_DIR" "sample data"
else
  echo "[db-seed] Skipping sample data (LOAD_SAMPLE_DATA=${LOAD_SAMPLE_DATA})."
fi

# 3. Optionally upload Jinja templates to MinIO (object key = filename)
if [ "$LOAD_TEMPLATES" = "true" ]; then
  echo "[db-seed] Uploading templates to MinIO ..."
  python3 /seed/upload_templates.py
else
  echo "[db-seed] Skipping template upload (LOAD_TEMPLATES=${LOAD_TEMPLATES})."
fi

# 4. Optionally seed mock eSignet identities from common demographics
if [ "$LOAD_ESIGNET_IDENTITIES" = "true" ]; then
  DEMO_DIR="${OPENG2P_DATA_DIR:-/openg2p-data}/demography"
  case "${ESIGNET_SEED_PROFILE:-individuals}" in
    farmers) ESIGNET_CSV="${DEMO_DIR}/esignet_farmers.csv" ;;
    *)       ESIGNET_CSV="${DEMO_DIR}/esignet_individuals.csv" ;;
  esac
  if [ ! -f "$ESIGNET_CSV" ]; then
    echo "[db-seed] Missing eSignet CSV at ${ESIGNET_CSV}, skipping."
  else
    echo "[db-seed] Seeding mock eSignet identities from ${ESIGNET_CSV} ..."
    python3 /openg2p-data/scripts/upload_data_to_mock_esignet.py "$ESIGNET_CSV"
  fi
else
  echo "[db-seed] Skipping eSignet identity seed (LOAD_ESIGNET_IDENTITIES=${LOAD_ESIGNET_IDENTITIES})."
fi

# 5. Optionally seed AWE database (policies, stages, callback_secret)
if [ "$AWE_DB_SEED_ENABLED" = "true" ]; then
  if [ -z "$AWE_PGDATABASE" ] || [ -z "$AWE_PGHOST" ]; then
    echo "[db-seed] AWE_DB_SEED_ENABLED but AWE DB env incomplete — skipping AWE seed."
  else
    echo "---------------------------------------------"
    echo " AWE DB : ${AWE_PGDATABASE}@${AWE_PGHOST}:${AWE_PGPORT:-5432}"
    echo "---------------------------------------------"
    run_sql_files "$AWE_META_DATA_DIR" "AWE meta_data" \
      "$AWE_PGHOST" "${AWE_PGPORT:-5432}" "$AWE_PGDATABASE" "$AWE_PGUSER" "$AWE_PGPASSWORD"
    run_callback_secret
  fi
fi

echo "[db-seed] Done."

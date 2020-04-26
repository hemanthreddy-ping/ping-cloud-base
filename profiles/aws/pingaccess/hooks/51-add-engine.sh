#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  echo "add-engine: this server is not an engine"
  exit
fi

echo "add-engine: starting add engine script"

IS_MULTI_CLUSTER=false
if test -z "${PA_ADMIN_PUBLIC_HOSTNAME}" || test -z "${PA_ENGINE_PUBLIC_HOSTNAME}"; then
  IS_MULTI_CLUSTER=false
else
  IS_MULTI_CLUSTER=true
fi

echo "add-engine: multi-cluster: ${IS_MULTI_CLUSTER}"

SHORT_HOST_NAME=$(hostname)
ORDINAL=${SHORT_HOST_NAME##*-}

if test "${IS_MULTI_CLUSTER}" = 'true'; then
  ADMIN_HOST_PORT="${PA_ADMIN_PUBLIC_HOSTNAME}"
  ENGINE_NAME="${PA_ENGINE_PUBLIC_HOSTNAME}:300${ORDINAL}"
else
  ADMIN_HOST_PORT="${K8S_SERVICE_NAME_PINGACCESS_ADMIN}:9000"
  ENGINE_NAME="${SHORT_HOST_NAME}"
fi

pingaccess_admin_wait "${ADMIN_HOST_PORT}"

# Retrieving CONFIG QUERY id
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/httpsListeners)
CONFIG_QUERY_LISTENER_KEYPAIR_ID=$(jq -n "$OUT" | jq '.items[] | select(.name=="CONFIG QUERY") | .keyPairId')
echo "add-engine: CONFIG_QUERY_LISTENER_KEYPAIR_ID: ${CONFIG_QUERY_LISTENER_KEYPAIR_ID}"

echo "add-engine: retrieving the Key Pair alias"
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/keyPairs)
KEYPAIR_ALIAS_NAME=$(jq -n "$OUT" | jq -r '.items[] | select(.id=='${CONFIG_QUERY_LISTENER_KEYPAIR_ID}') | .alias')
echo "add-engine: KEYPAIR_ALIAS_NAME: ${KEYPAIR_ALIAS_NAME}"

# Retrieve Engine Cert ID
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/certificates)
ENGINE_CERT_ID=$(jq -n "$OUT" |
    jq --arg KEYPAIR_ALIAS_NAME "${KEYPAIR_ALIAS_NAME}" \
        '.items[] | select(.alias==$KEYPAIR_ALIAS_NAME and .keyPair==true) | .id')
echo "add-engine: ENGINE_CERT_ID: ${ENGINE_CERT_ID}"

# Retrieve Engine ID
OUT=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
ENGINE_ID=$(jq -n "${OUT}" | jq --arg ENGINE_NAME "${ENGINE_NAME}" '.items[] | select(.name==$ENGINE_NAME) | .id')

# If engine doesn't exist, then create new engine
if test -z "${ENGINE_ID}" || test "${ENGINE_ID}" = 'null'; then
  if test "${IS_MULTI_CLUSTER}" = 'true'; then
    PROXY_PORT="300${ORDINAL}"
    PROXY_NAME="${PA_ENGINE_PUBLIC_HOSTNAME}:${PROXY_PORT}"

    echo "add-engine: adding engine proxy ${PROXY_NAME}"
    OUT=$(make_api_request -X POST -d "{
        \"name\": \"${PROXY_NAME}\",
        \"host\": \"${PA_ENGINE_PUBLIC_HOSTNAME}\",
        \"port\": ${PROXY_PORT},
        \"requiresAuthentication\": false
    }" https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/proxies)
    PROXY_ID=$(jq -n "$OUT" | jq '.id')

    OUT=$(make_api_request -X POST -d "{
        \"name\": \"${ENGINE_NAME}\",
        \"selectedCertificateId\": ${ENGINE_CERT_ID},
        \"httpsProxyId\": ${PROXY_ID},
        \"configReplicationEnabled\": true
    }" https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
  else
    OUT=$(make_api_request -X POST -d "{
        \"name\":\"${ENGINE_NAME}\",
        \"selectedCertificateId\": ${ENGINE_CERT_ID},
        \"configReplicationEnabled\": true
    }" https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines)
  fi

  ENGINE_ID=$(jq -n "$OUT" | jq '.id')
fi

# Download Engine Configuration.
echo "add-engine: retrieving the engine config for engine ${ENGINE_ID}"
make_api_request_download -X POST \
    https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/engines/"${ENGINE_ID}"/config -o engine-config.zip

# Validate zip.
echo "add-engine: validating downloaded config archive"
if test $(unzip -t engine-config.zip &> /dev/null; echo $?) != 0; then
  echo "add-engine: failure retrieving config admin zip for engine"
  exit 1
fi

echo "add-engine: extracting config files to conf folder"
unzip -o engine-config.zip -d "${OUT_DIR}"/instance
chmod 400 "${OUT_DIR}"/instance/conf/pa.jwk

echo "add-engine: cleanup zip"
rm engine-config.zip

echo "add-engine: finished add engine script"
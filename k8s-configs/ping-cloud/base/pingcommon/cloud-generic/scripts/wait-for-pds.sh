#!/bin/sh

. "./utils.lib.sh"

SLEEP_SECONDS=${INITIAL_DELAY_SECONDS:-0}

beluga_log "Initial delay: ${SLEEP_SECONDS}"
sleep "${SLEEP_SECONDS}"

PORT="${P1AS_PD_LDAPS_PORT}" # default wait on PingDirectory LDAPS port

# If DISABLE_CERT_AUTOMATION is set then force PingDirectory to wait for insecure LDAAP port
if [ "${DISABLE_CERT_AUTOMATION}" = "true" ]; then
  PORT="${P1AS_PD_LDAP_PORT}"
fi

SYNC_SERVERS="${P1AS_PD_POD_NAME}.${P1AS_PD_CLUSTER_PRIVATE_HOSTNAME}:${PORT}"

# Append external PingDirectory host ldap and https if IS_P1AS_TEST_MODE is true.
if [ "${IS_P1AS_TEST_MODE}" = "true" ]; then
  SYNC_SERVERS="${EXT_PD_HOST}:${EXT_PD_LDAPS_PORT} \
  ${SYNC_SERVERS} ${EXT_PD_HOST}:${EXT_PD_HTTPS_PORT}"
fi

beluga_log "Checking sync servers: ${SYNC_SERVERS}"

for SERVER in ${SYNC_SERVERS}; do
  while true; do
    if nc -z -v -w 2 "${SERVER}"; then
      break
    fi

    beluga_log "'${SERVER}' unreachable. Will try again in 2 seconds."
    sleep 2s
  done # end of while-true loop
done #end of for-SERVER loop
beluga_log "Execution completed successfully"

exit 0
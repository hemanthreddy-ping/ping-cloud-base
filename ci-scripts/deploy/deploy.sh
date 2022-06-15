#!/bin/bash
set -e

test "${VERBOSE}" && set -x

# Source common environment variables
SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

configure_aws
configure_kube

pushd "${PROJECT_DIR}"

NEW_RELIC_LICENSE_KEY=${NEW_RELIC_LICENSE_KEY:-unused}

export NEW_RELIC_LICENSE_KEY_BASE64=$(base64_no_newlines "${NEW_RELIC_LICENSE_KEY}")
export DATASYNC_P1AS_SYNC_SERVER="pingdirectory-0"

# Deploy the configuration to Kubernetes
if [[ -n ${PINGONE} ]]; then
  set_pingone_api_env_vars
  pip3 install -r ${PROJECT_DIR}/ci-scripts/deploy/ping-one/requirements.txt
  log "Deleting P1 Environment if it already exists"
  python3 ${PROJECT_DIR}/ci-scripts/deploy/ping-one/p1_env_setup_and_teardown.py Teardown 2>/dev/null || true
  log "Creating P1 Environment"
  python3 ${PROJECT_DIR}/ci-scripts/deploy/ping-one/p1_env_setup_and_teardown.py Setup
fi

DEPLOY_FILE=/tmp/deploy.yaml

build_dev_deploy_file "${DEPLOY_FILE}"

kubectl apply -f "${DEPLOY_FILE}"

check_if_ready ${NAMESPACE}

popd  > /dev/null 2>&1

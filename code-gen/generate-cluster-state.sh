#!/bin/bash

# If VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x

# Ensure that this script works from any working directory.
SCRIPT_HOME=$(cd $(dirname ${0}) 2>/dev/null; pwd)
pushd "${SCRIPT_HOME}" >/dev/null 2>&1

# Quiet mode where instructional messages are omitted.
QUIET="${QUIET:-false}"

# Source some utility methods.
. ../utils.sh

# Source aws specific utility methods.
. ./aws/utils.sh

# Source utils specific to this script
. ./generate-cluster-state-utils.sh

########################################################################################################################
# Substitute variables in all template files in the provided directory.
#
# Arguments
#   ${1} -> The directory that contains the template files.
########################################################################################################################


# Variables to replace within the generated cluster state code
REPO_VARS="${REPO_VARS:-${DEFAULT_VARS}}"

# Checking required tools and environment variables.
check_binaries "openssl" "ssh-keygen" "ssh-keyscan" "base64" "envsubst" "git" "aws" "rsync"
HAS_REQUIRED_TOOLS=${?}

if test ${HAS_REQUIRED_TOOLS} -ne 0; then
  # Go back to previous working directory, if different, before exiting.
  popd >/dev/null 2>&1
  exit 1
fi

if test -z "${IS_MULTI_CLUSTER}"; then
  IS_MULTI_CLUSTER=false
fi

# Use defaults for other variables, if not present.
export IS_BELUGA_ENV="${IS_BELUGA_ENV:-false}"

TENANT_DOMAIN="${TENANT_DOMAIN:-ci-cd.ping-oasis.com}"
export TENANT_NAME="${TENANT_NAME:-${TENANT_DOMAIN%%.*}}"
export SIZE="${SIZE:-x-small}"

### Region-specific environment variables ###
export REGION="${REGION:-us-west-2}"
export REGION_NICK_NAME="${REGION_NICK_NAME:-${REGION}}"

TENANT_DOMAIN_NO_DOT_SUFFIX="${TENANT_DOMAIN%.}"
export TENANT_DOMAIN="${TENANT_DOMAIN_NO_DOT_SUFFIX}"

export ARTIFACT_REPO_URL="${ARTIFACT_REPO_URL:-unused}"

export PLATFORM_EVENT_QUEUE_NAME=${PLATFORM_EVENT_QUEUE_NAME:-v2_platform_event_queue.fifo}
export ORCH_API_SSM_PATH_PREFIX=${ORCH_API_SSM_PATH_PREFIX:-/pcpt/orch-api}
export SERVICE_SSM_PATH_PREFIX=${SERVICE_SSM_PATH_PREFIX:-/pcpt/service}

export LAST_UPDATE_REASON="${LAST_UPDATE_REASON:-NA}"

### Base environment variables ###
export IS_MULTI_CLUSTER="${IS_MULTI_CLUSTER}"

export PRIMARY_REGION="${PRIMARY_REGION:-${REGION}}"
PRIMARY_TENANT_DOMAIN_NO_DOT_SUFFIX="${PRIMARY_TENANT_DOMAIN%.}"
export PRIMARY_TENANT_DOMAIN="${PRIMARY_TENANT_DOMAIN_NO_DOT_SUFFIX:-${TENANT_DOMAIN_NO_DOT_SUFFIX}}"
export SECONDARY_TENANT_DOMAINS="${SECONDARY_TENANT_DOMAINS}"

if "${IS_BELUGA_ENV}"; then
  DERIVED_GLOBAL_TENANT_DOMAIN="global.${TENANT_DOMAIN_NO_DOT_SUFFIX}"
else
  DERIVED_GLOBAL_TENANT_DOMAIN="$(echo "${TENANT_DOMAIN_NO_DOT_SUFFIX}" | sed -e "s/\([^.]*\).[^.]*.\(.*\)/global.\1.\2/")"
fi
GLOBAL_TENANT_DOMAIN_NO_DOT_SUFFIX="${GLOBAL_TENANT_DOMAIN%.}"
export GLOBAL_TENANT_DOMAIN="${GLOBAL_TENANT_DOMAIN_NO_DOT_SUFFIX:-${DERIVED_GLOBAL_TENANT_DOMAIN}}"

export PING_ARTIFACT_REPO_URL="${PING_ARTIFACT_REPO_URL:-https://ping-artifacts.s3-us-west-2.amazonaws.com}"

export LOG_ARCHIVE_URL="${LOG_ARCHIVE_URL:-unused}"
export BACKUP_URL="${BACKUP_URL:-unused}"

export MYSQL_SERVICE_HOST="${MYSQL_SERVICE_HOST:-"pingcentraldb.\${PRIMARY_TENANT_DOMAIN}"}"
export MYSQL_USER="${MYSQL_USER:-ssm://aws/reference/secretsmanager//pcpt/ping-central/dbserver#username}"
export MYSQL_PASSWORD="${MYSQL_PASSWORD:-ssm://aws/reference/secretsmanager//pcpt/ping-central/dbserver#password}"

export PING_IDENTITY_DEVOPS_USER="${PING_IDENTITY_DEVOPS_USER:-ssm://pcpt/devops-license/user}"
export PING_IDENTITY_DEVOPS_KEY="${PING_IDENTITY_DEVOPS_KEY:-ssm://pcpt/devops-license/key}"

export LEGACY_LOGGING=${LEGACY_LOGGING:-True}

PING_CLOUD_BASE_COMMIT_SHA=$(git rev-parse HEAD)
CURRENT_GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if test "${CURRENT_GIT_BRANCH}" = 'HEAD'; then
  CURRENT_GIT_BRANCH=$(git describe --tags --always)
fi

export CLUSTER_STATE_REPO_URL=${CLUSTER_STATE_REPO_URL:-https://github.com/pingidentity/ping-cloud-base}
CLUSTER_STATE_REPO_NAME="${CLUSTER_STATE_REPO_URL##*/}"

SERVER_PROFILE_URL_DERIVED="$(echo "${CLUSTER_STATE_REPO_URL}" | sed -e "s/${CLUSTER_STATE_REPO_NAME}/profile-repo/")"
export SERVER_PROFILE_URL="${SERVER_PROFILE_URL:-${SERVER_PROFILE_URL_DERIVED}}"

export K8S_GIT_URL="${K8S_GIT_URL:-https://github.com/pingidentity/ping-cloud-base}"
export K8S_GIT_BRANCH="${K8S_GIT_BRANCH:-${CURRENT_GIT_BRANCH}}"

export SSH_ID_PUB_FILE="${SSH_ID_PUB_FILE}"
export SSH_ID_KEY_FILE="${SSH_ID_KEY_FILE}"

export TARGET_DIR="${TARGET_DIR:-/tmp/sandbox}"

### Default environment variables ###
export ECR_REGISTRY_NAME='public.ecr.aws/r2h3l6e4'
export PING_CLOUD_NAMESPACE='ping-cloud'
export MYSQL_DATABASE='pingcentral'

# None of these are actually used?? - need to actually set the auto-generated str?
# AUTO_GENERATED_STR='<auto-generated>'
# echo "Using SSH_ID_PUB_FILE: ${SSH_ID_PUB_FILE:-${AUTO_GENERATED_STR}}"
# echo "Using SSH_ID_KEY_FILE: ${SSH_ID_KEY_FILE:-${AUTO_GENERATED_STR}}"
###

NEW_RELIC_LICENSE_KEY="${NEW_RELIC_LICENSE_KEY:-ssm://pcpt/sre/new-relic/java-agent-license-key}"
if [[ ${NEW_RELIC_LICENSE_KEY} == "ssm://"* ]]; then
  if ! ssm_value=$(get_ssm_value "${NEW_RELIC_LICENSE_KEY#ssm:/}"); then
    echo "Warn: ${ssm_value}"
    echo "Setting NEW_RELIC_LICENSE_KEY to unused"
    NEW_RELIC_LICENSE_KEY="unused"
  else
    NEW_RELIC_LICENSE_KEY="${ssm_value}"
  fi
fi

export NEW_RELIC_LICENSE_KEY_BASE64=$(base64_no_newlines "${NEW_RELIC_LICENSE_KEY}")

TEMPLATES_HOME="${SCRIPT_HOME}/templates"
BASE_TOOLS_REL_DIR="base/cluster-tools"
BASE_PING_CLOUD_REL_DIR="base/ping-cloud"
REGION_DIR="${TEMPLATES_HOME}/region"

COMMON_TEMPLATES_DIR="${TEMPLATES_HOME}/common"
CHUB_TEMPLATES_DIR="${TEMPLATES_HOME}/customer-hub"
CDE_TEMPLATES_DIR="${TEMPLATES_HOME}/cde"

# Generate an SSH key pair for the CD tool.
if test -z "${SSH_ID_PUB_FILE}" && test -z "${SSH_ID_KEY_FILE}"; then
  echo 'Generating key-pair for SSH access'
  generate_ssh_key_pair
elif test -z "${SSH_ID_PUB_FILE}" || test -z "${SSH_ID_KEY_FILE}"; then
  echo 'Provide SSH key-pair files via SSH_ID_PUB_FILE/SSH_ID_KEY_FILE env vars, or omit both for key-pair to be generated'
  exit 1
else
  echo 'Using provided key-pair for SSH access'
  export SSH_ID_PUB=$(cat "${SSH_ID_PUB_FILE}")
  export SSH_ID_KEY_BASE64=$(base64_no_newlines "${SSH_ID_KEY_FILE}")
fi

# Get the known hosts contents for the cluster state repo host to pass it into the CD container.
parse_url "${CLUSTER_STATE_REPO_URL}"
echo "Obtaining known_hosts contents for cluster state repo host: ${URL_HOST}"

if test ! "${KNOWN_HOSTS_CLUSTER_STATE_REPO}"; then
  # For GitHub, use the 'ecdsa' SSH host key type. The CD tool doesn't work with RSA keys. For all others, use 'rsa'.
  # FIXME: make SSH_HOST_KEY_TYPE overridable in the future. Ref: "man ssh-keyscan".
  if echo "${URL_HOST}" | grep -q 'github.com'; then
    SSH_HOST_KEY_TYPE='ecdsa'
  else
    SSH_HOST_KEY_TYPE='rsa'
  fi
  KNOWN_HOSTS_CLUSTER_STATE_REPO="$(ssh-keyscan -t "${SSH_HOST_KEY_TYPE}" -H "${URL_HOST}" 2>/dev/null)"
fi
export KNOWN_HOSTS_CLUSTER_STATE_REPO

# Delete existing target directory and re-create it
rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"

# Next build up the directory structure of the cluster-state repo
BOOTSTRAP_SHORT_DIR='fluxcd'
BOOTSTRAP_DIR="${TARGET_DIR}/${BOOTSTRAP_SHORT_DIR}"

CLUSTER_STATE_REPO_DIR="${TARGET_DIR}/cluster-state"
K8S_CONFIGS_DIR="${CLUSTER_STATE_REPO_DIR}/k8s-configs"

PROFILE_REPO_DIR="${TARGET_DIR}/profile-repo"
PROFILES_DIR="${PROFILE_REPO_DIR}/profiles"

CUSTOMER_HUB='customer-hub'
PING_CENTRAL='pingcentral'

# Make initial directories
mkdir -p "${BOOTSTRAP_DIR}"
mkdir -p "${K8S_CONFIGS_DIR}"
mkdir -p "${PROFILE_REPO_DIR}"

# Copy some update scripts
cp ./update-cluster-state-wrapper.sh "${CLUSTER_STATE_REPO_DIR}"
cp ./update-profile-wrapper.sh "${PROFILE_REPO_DIR}"

# Copy gitignore
cp ../.gitignore "${CLUSTER_STATE_REPO_DIR}"
cp ../.gitignore "${PROFILE_REPO_DIR}"

# Copy git-ops-command
cp ../k8s-configs/cluster-tools/base/git-ops/git-ops-command.sh "${K8S_CONFIGS_DIR}"

# Copy (all??) templates to k8s_configs_dir??
find "${TEMPLATES_HOME}" -type f -maxdepth 1 | xargs -I {} cp {} "${K8S_CONFIGS_DIR}"

echo "${PING_CLOUD_BASE_COMMIT_SHA}" > "${TARGET_DIR}/pcb-commit-sha.txt"

# Now generate the yaml files for each environment
ALL_ENVIRONMENTS='dev test stage prod customer-hub'
ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"

export CLUSTER_STATE_REPO_URL="${CLUSTER_STATE_REPO_URL}"

get_is_ga_variable '/pcpt/stage/is-ga'
get_is_myping_variable '/pcpt/orch-api/is-myping'

# The ENVIRONMENTS variable can either be the CDE names (e.g. dev, test, stage, prod) or the CHUB name "customer-hub",
# or the corresponding branch names (e.g. v1.8.0-dev, v1.8.0-test, v1.8.0-stage, v1.8.0-master, v1.8.0-customer-hub).
# We must handle both cases. Note that the 'prod' environment will have a branch name suffix of 'master'.
for ENV_OR_BRANCH in ${ENVIRONMENTS}; do
# Run in a sub-shell so the current shell is not polluted with environment variables.
(
  if echo "${ENV_OR_BRANCH}" | grep -q "${CUSTOMER_HUB}"; then
    GIT_BRANCH="${CUSTOMER_HUB}"

    ENV_OR_BRANCH_SUFFIX="${CUSTOMER_HUB}"
    ENV="${CUSTOMER_HUB}"

    export CLUSTER_STATE_REPO_BRANCH="${CUSTOMER_HUB}"
  else
    test "${ENV_OR_BRANCH}" = 'prod' &&
        GIT_BRANCH='master' ||
        GIT_BRANCH="${ENV_OR_BRANCH}"

    ENV_OR_BRANCH_SUFFIX="${ENV_OR_BRANCH##*-}"

    # If the branch is master, set ENV to prod
    if test "${ENV_OR_BRANCH_SUFFIX}" = 'master'; then
      ENV='prod'
    else
      ENV="${ENV_OR_BRANCH_SUFFIX}"
    fi

    # Set the cluster state repo branch to the default CDE branch, i.e. dev, test, stage or master.
    export CLUSTER_STATE_REPO_BRANCH="${GIT_BRANCH##*-}"
  fi

  # Export all the environment variables required for envsubst
  export ENV="${ENV}"
  export ENVIRONMENT_TYPE="\${ENV}"

  # The base URL for kustomization files and environment will be different for each CDE.
  # On migrated customers, we must preserve the size of the customers.
  case "${ENV}" in
    dev | test)
      export KUSTOMIZE_BASE="${KUSTOMIZE_BASE:-test}"
      ;;
    stage | prod | customer-hub)
      export KUSTOMIZE_BASE="${KUSTOMIZE_BASE:-prod/${SIZE}}"
      ;;
  esac

  # Update the Let's encrypt server to use staging/production based on GA/MyPing customers or the environment type.
  PROD_LETS_ENCRYPT_SERVER='https://acme-v02.api.letsencrypt.org/directory'
  STAGE_LETS_ENCRYPT_SERVER='https://acme-staging-v02.api.letsencrypt.org/directory'

  if test ! "${LETS_ENCRYPT_SERVER}"; then
    if "${IS_GA}" || "${IS_MY_PING}"; then
      LETS_ENCRYPT_SERVER="${PROD_LETS_ENCRYPT_SERVER}"
    else
      case "${ENV}" in
        dev | test | stage)
          LETS_ENCRYPT_SERVER="${STAGE_LETS_ENCRYPT_SERVER}"
          ;;
        prod | customer-hub)
          LETS_ENCRYPT_SERVER="${PROD_LETS_ENCRYPT_SERVER}"
          ;;
      esac
    fi
  fi
  export LETS_ENCRYPT_SERVER="${LETS_ENCRYPT_SERVER}"

  export USER_BASE_DN="${USER_BASE_DN:-dc=example,dc=com}"

  # Set PF variables based on ENV
  if echo "${LETS_ENCRYPT_SERVER}" | grep -q 'staging'; then
    export PF_PD_BIND_PORT=1389
    export PF_PD_BIND_PROTOCOL=ldap
    export PF_PD_BIND_USESSL=false
  else
    export PF_PD_BIND_PORT=1636
    export PF_PD_BIND_PROTOCOL=ldaps
    export PF_PD_BIND_USESSL=true
  fi

  # Update the PF JVM limits based on environment.
  case "${ENV}" in
    dev | test)
      export PF_MIN_HEAP=1536m
      export PF_MAX_HEAP=1536m
      export PF_MIN_YGEN=768m
      export PF_MAX_YGEN=768m
      ;;
    stage | prod | customer-hub)
      export PF_MIN_HEAP=3072m
      export PF_MAX_HEAP=3072m
      export PF_MIN_YGEN=1536m
      export PF_MAX_YGEN=1536m
      ;;
  esac

  # Set PA variables
  case "${ENV}" in
    dev | test)
      export PA_WAS_MIN_HEAP=1024m
      export PA_WAS_MAX_HEAP=1024m
      export PA_WAS_MIN_YGEN=512m
      export PA_WAS_MAX_YGEN=512m
      ;;
    stage | prod | customer-hub)
      export PA_WAS_MIN_HEAP=2048m
      export PA_WAS_MAX_HEAP=2048m
      export PA_WAS_MIN_YGEN=1024m
      export PA_WAS_MAX_YGEN=1024m
      ;;
  esac
  export PA_WAS_GCOPTION='-XX:+UseParallelGC'

  export PA_MIN_HEAP=1024m
  export PA_MAX_HEAP=1024m
  export PA_MIN_YGEN=512m
  export PA_MAX_YGEN=512m
  export PA_GCOPTION='-XX:+UseParallelGC'

  "${IS_BELUGA_ENV}" &&
      export CLUSTER_NAME="${TENANT_NAME}" ||
      export CLUSTER_NAME="${ENV}"

  CLUSTER_NAME_LC="$(echo "${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')"
  export CLUSTER_NAME_LC="${CLUSTER_NAME_LC}"

  add_derived_variables
  add_irsa_variables "${ACCOUNT_ID_PATH_PREFIX:-unused}" "${ENV}"
  add_nlb_variables "${NLB_EIP_PATH_PREFIX:-unused}" "${ENV}"

  echo ---
  echo "For environment ${ENV}, using variable values:"
  echo "CLUSTER_STATE_REPO_BRANCH: ${CLUSTER_STATE_REPO_BRANCH}"
  echo "ENVIRONMENT_TYPE: ${ENVIRONMENT_TYPE}"
  echo "KUSTOMIZE_BASE: ${KUSTOMIZE_BASE}"
  echo "LETS_ENCRYPT_SERVER: ${LETS_ENCRYPT_SERVER}"
  echo "USER_BASE_DN: ${USER_BASE_DN}"
  echo "CLUSTER_NAME: ${CLUSTER_NAME}"
  echo "PING_CLOUD_NAMESPACE: ${PING_CLOUD_NAMESPACE}"
  echo "DNS_ZONE: ${DNS_ZONE}"
  echo "PRIMARY_DNS_ZONE: ${PRIMARY_DNS_ZONE}"
  echo "LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"
  echo "BACKUP_URL: ${BACKUP_URL}"

  # Build the kustomization file for the bootstrap tools for each environment
  echo "Generating bootstrap yaml for ${ENV}"

  # The code for an environment is generated under a directory of the same name as what's provided in ENVIRONMENTS.
  ENV_BOOTSTRAP_DIR="${BOOTSTRAP_DIR}/${ENV_OR_BRANCH}"
  mkdir -p "${ENV_BOOTSTRAP_DIR}"

  cp "${TEMPLATES_HOME}/${BOOTSTRAP_SHORT_DIR}"/* "${ENV_BOOTSTRAP_DIR}"

  # Create a list of variables to substitute for the bootstrap tools
  substitute_vars "${ENV_BOOTSTRAP_DIR}" "${BOOTSTRAP_VARS}"

  # Copy the shared cluster tools and Ping yaml templates into their target directories
  echo "Generating tools and ping yaml for ${ENV}"

  ENV_DIR="${K8S_CONFIGS_DIR}/${ENV_OR_BRANCH}"
  mkdir -p "${ENV_DIR}"

  #$$$$ Copy the common templates first.
  cd "${COMMON_TEMPLATES_DIR}"
  rsync -rR * "${ENV_DIR}"
  #$$$$

  cd - >/dev/null 2>&1

  #---- Overlay the CHUB or CDE specific templates next.
  if test "${ENV}" = "${CUSTOMER_HUB}"; then
    cd "${CHUB_TEMPLATES_DIR}"
  else
    cd "${CDE_TEMPLATES_DIR}"
  fi
  rsync -rR * "${ENV_DIR}"
  #----

  cd - >/dev/null 2>&1

  # Rename to the actual region nick name.
  mv "${ENV_DIR}/region" "${ENV_DIR}/${REGION_NICK_NAME}"

  substitute_vars "${ENV_DIR}" "${REPO_VARS}" secrets.yaml env_vars

  # Regional enablement - add admins, backups, etc. to primary.
  if test "${TENANT_DOMAIN}" = "${PRIMARY_TENANT_DOMAIN}"; then
    PRIMARY_PING_KUST_FILE="${ENV_DIR}/${REGION_NICK_NAME}/kustomization.yaml"
    sed -i.bak 's/^\(.*remove-from-secondary-patch.yaml\)$/# \1/g' "${PRIMARY_PING_KUST_FILE}"
    rm -f "${PRIMARY_PING_KUST_FILE}.bak"
  fi

  if "${IS_BELUGA_ENV}"; then
    BASE_ENV_VARS="${ENV_DIR}/base/env_vars"
    echo >> "${BASE_ENV_VARS}"
    echo "IS_BELUGA_ENV=true" >> "${BASE_ENV_VARS}"
  fi

  echo "Copying server profiles for environment ${ENV}"
  ENV_PROFILES_DIR="${PROFILES_DIR}/${ENV_OR_BRANCH}"
  mkdir -p "${ENV_PROFILES_DIR}"

  ###### ---- ALL FEATURE FLAGS GO HERE ----- #######
  pgo_feature_flag "${K8S_CONFIGS_DIR}/common/base/cluster-tools/kustomization.yaml"
  ###################################################

  # Copy all env-specific profiles
  cp -pr ../profiles/aws/. "${ENV_PROFILES_DIR}"

  if test "${ENV}" = "${CUSTOMER_HUB}"; then
    # Retain only the pingcentral profiles
    find "${ENV_PROFILES_DIR}" -type d -mindepth 1 -maxdepth 1 -not -name "${PING_CENTRAL}" -exec rm -rf {} +
  else
    # Remove the pingcentral profiles
    rm -rf "${ENV_PROFILES_DIR}/${PING_CENTRAL}"
  fi
)
done

cp -p push-cluster-state.sh "${TARGET_DIR}"

# Go back to previous working directory, if different
popd >/dev/null 2>&1

if ! "${QUIET}"; then
  echo
  echo '------------------------'
  echo '|  Next steps to take  |'
  echo '------------------------'
  echo "1) Run ${TARGET_DIR}/push-cluster-state.sh to push the generated code into the tenant cluster-state repo:"
  echo "${CLUSTER_STATE_REPO_URL}"
  echo
  echo "2) Add the following identity as the deploy key on the cluster-state (rw), if not already added:"
  echo "${SSH_ID_PUB}"
  echo
  echo "3) Deploy bootstrap files onto each CDE by navigating to ${BOOTSTRAP_DIR} and running:"
  echo 'kustomize build | kubectl apply -f -'
fi

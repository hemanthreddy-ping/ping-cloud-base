#!/usr/bin/env sh

########################################################################################################################
# Function sets required environment variables for skbn
#
########################################################################################################################
function initializeSkbnConfiguration() {
  unset SKBN_CLOUD_PREFIX
  unset SKBN_K8S_PREFIX

  # Allow overriding the backup URL with an arg
  test ! -z "${1}" && BACKUP_URL="${1}"

  # Check if endpoint is AWS cloud stroage service (S3 bucket)
  case "$BACKUP_URL" in "s3://"*)
    
    #Set AWS specific variable for skbn
    export AWS_REGION=${REGION}
    
    DIRECTORY_NAME=$(echo "${PING_PRODUCT}" | tr '[:upper:]' '[:lower:]')

    if test "${BACKUP_URL}" != */"${DIRECTORY_NAME}"; then
      BACKUP_URL="${BACKUP_URL}/${DIRECTORY_NAME}"
    fi

  esac

  echo "Getting cluster metadata"
  METADATA=$(kubectl get "$(kubectl get pod -o name | grep "${HOSTNAME}")" \
    -o=jsonpath='{.metadata.namespace},{.metadata.name},{.metadata.labels.role}')
    
  METADATA_NS=$(echo "${METADATA}"| cut -d',' -f1)
  METADATA_PN=$(echo "${METADATA}"| cut -d',' -f2)
  METADATA_CN=$(echo "${METADATA}"| cut -d',' -f3)

  export SKBN_CLOUD_PREFIX="${BACKUP_URL}"
  export SKBN_K8S_PREFIX="k8s://${METADATA_NS}/${METADATA_PN}/${METADATA_CN}"
}

########################################################################################################################
# Function to copy file between cloud storage and k8s
#
########################################################################################################################
function skbnCopy() {
  SOURCE_FILE="${1}"
  DESTINATION_FILE="${2}"

  if ! skbn cp --src "$SOURCE_FILE" --dst "${DESTINATION_FILE}"; then
    return 1
  fi
}
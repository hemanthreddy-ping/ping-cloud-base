# Validate descriptor.json has proper JSON syntax. Return with status code 1 if the JSON cannot be parsed.
function validateDescriptorJsonSyntax() {
  local descriptor_json=${1}
  beluga_log "Validate the descriptor.json syntax"

  # Verify file isn't empty
  ! test -s "${descriptor_json}" && beluga_error "descriptor.json is empty" && return 1

  # Verify JSON is parsable
  local json_str=$(cat "${descriptor_json}")
  test $(
    jq -n "${json_str}" >/dev/null 2>&1
    echo $?
  ) != "0" && beluga_error "Invalid JSON descriptor file" && return 1
  return 0
}

# Get the region(s) from JSON descriptor, and write it to regions.txt.
# Verify that each region has a region name without spaces and is unique.
# Also, verify hostname and replica count are included per region. Return with status code 1 if fail.
function verifyDescriptorJsonSchema() {
  local descriptor_json=${1}
  local regions_file=${2}

  beluga_log "Verifying descriptor.json content"
  cat "${descriptor_json}"
  echo

  # Verify no duplicate keys. Use jq to filter out duplicate keys and compare against descriptor.json.
  jq -r . "${descriptor_json}" | tr -d '[:space:]' | sort >"${regions_file}"
  cat "${regions_file}"
  tr -d '[:space:]' <"${descriptor_json}" | sort | diff -waB "${regions_file}" - >/dev/null
  test $? -ne 0 && beluga_error "descriptor.json contains duplicate keys" && return 1

  # Verify there is at least 1 region name within descriptor.json file
  test $(jq -r '(keys_unsorted|length)' "${descriptor_json}") -lt 1 && beluga_error "No regions found within \
    descriptor file: ${descriptor_json}" && return 1

  jq -r 'keys_unsorted | .[]' "${descriptor_json}" >"${regions_file}"

  # Verify spaces are not included in region names
  test $(grep -q ' ' "${regions_file}") && beluga_error "There is at least 1 region name that contains \
    a space within descriptor file: ${descriptor_json}" && return 1

  for region in $(cat "${regions_file}"); do

    # Verify hostname is included
    local hostname=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")
    (test $? -ne 0 || test -z "${hostname}") && beluga_error "Empty hostname within descriptor file: ${descriptor_json}" && return 1

    # Verify replica count is included and is a number
    local count=$(jq -r ".[\"${region}\"].replicas" "${descriptor_json}")
    (test $? -ne 0 || test -z "${count}") && beluga_error "Empty replica count within descriptor file: ${descriptor_json}" && return 1

    echo "${count}" | egrep -iq '^[0-9]'
    test $? -ne 0 &&
      beluga_error "Invalid replica count within descriptor file: ${descriptor_json}. Replica count, ${count}, must \
        match the regex: /^[0-9]/" && return 1
  done

  return 0
}

########################################################################################################################
# Logs the provided message at the provided log level. Default log level is INFO, if not provided.
#
# Arguments
#   $1 -> The log message.
#   $2 -> Optional log level. Default is INFO.
########################################################################################################################
beluga_log() {
  file_name="$(basename "$0")"
  message="$1"
  test -z "$2" && log_level='INFO' || log_level="$2"
  format='+%Y-%m-%d %H:%M:%S'
  timestamp="$(TZ=UTC date "${format}")"
  echo "${file_name}: ${timestamp} ${log_level} ${message}"
}

########################################################################################################################
# Logs the provided message and set the log level to ERROR.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
beluga_error() {
  beluga_log "$1" 'ERROR'
}

########################################################################################################################
# Determines if the environment is running in the context of multiple clusters.
#
# Returns
#   true if multi-cluster; false if not.
########################################################################################################################
function is_multi_cluster() {
  test ! -z "${IS_MULTI_CLUSTER}" && "${IS_MULTI_CLUSTER}"
}

if "${is_multi_cluster}"; then
  # point it to descriptor.json file in the same dir
  JSON_FILE=${1}

  # create temp regions.txt file
  regions_file=$(mktemp "regions.txt")

  validateDescriptorJsonSyntax "${JSON_FILE}"
  verifyDescriptorJsonSchema "${JSON_FILE}" "${regions_file}"

  # Read and delete temp regions.txt file
  cat "${regions_file}"
  rm -f "${regions_file}"
fi

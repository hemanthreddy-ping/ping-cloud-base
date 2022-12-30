#!/bin/bash

### One of hopefully very few duplicated functions to enable sourcing of methods
pcb_common::source_utils() {
    if [[ "${LOCAL_TEST}" == "true" ]]; then
        # NOTE: You must set LOCAL_TEST and the location for PCC_REPO to enable local testing
        source "${PCC_REPO}/pingcloud-scripts/utils/utils.sh"
        return
    fi

    # TODO: change
    local version="${1:-PDO-4690-shared-shell}"
    local aws_profile="${2:-${AWS_PROFILE}}"
    local tmp_dir="/tmp/pcb_common"

    mkdir -p "${tmp_dir}"

    if ! aws --no-cli-pager --profile "${aws_profile}" sts get-caller-identity; then
    echo "Make sure you are logged into a current AWS session!"
    fi

    aws --profile "${aws_profile}" s3 cp \
        "s3://pingcloud-scripts-dev/utils/${version}/utils.tar.gz" "${tmp_dir}/utils.tar.gz"

    tar -xzvf "${tmp_dir}/utils.tar.gz" -C "${tmp_dir}"
    source "${tmp_dir}/utils.sh"
}
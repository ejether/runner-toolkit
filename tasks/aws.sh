#!/usr/bin/env bash

### SETTINGS ###
# Configuring aws-vault
export AWS_REGIONS=("us-west-2" "us-west-1" "us-east-1" "us-east-2")
export AWS_SESSION_TOKEN_TTL=12h
export AWS_ASSUME_ROLE_TTL=12h
export AWS_MIN_TTL=12h

### HELPERS ###
function ensure_awscli() {
    # Ensure awscli is available
    aws sts get-caller-identity >/dev/null || {
        runner_log_error "Error with aws access"
        return 1
    }
}

function ensure_aws_login() {
    # Check for exiting session, if fails, create one, else return
    aws_set_profile
    ensure_awscli || { runner aws_sso_login || return 1; }
}

function aws_account() {
    # returns account number
    ensure_aws_login
    aws sts get-caller-identity | jq -r '.Account'
}

function aws_set_profile() {
    # lists and sets menu of local profiles if AWS_PROFILE is not set
    if [ -z "${AWS_PROFILE}" ]; then
        runner_colorize purple "Choose a profile to use:"
        select profile in $(aws configure list-profiles); do
            export AWS_PROFILE="${profile}"
            break
        done
    fi
}

function ensure_aws_vault() {
    # tests presense of aws-vault
    command aws-vault 2>/dev/null || {
        runner_log_error "aws-vault is not installed"
        return 1
    }
}

function eks_clusters() {
    # returns a list of clusters in a limited set of regions
    EKS_CLUSTERS=()
    for region in "${AWS_REGIONS[@]}"; do
        for cluster in $(aws eks list-clusters --region "${region}" | jq -r '.clusters[]'); do
            EKS_CLUSTERS+=("${cluster}@${region}")
        done
    done
}

### TASKS ###

function task_aws_key_find_owner() {
    DOC="Finds the IAM username of the owner of the AWS IAM KeyId entered as --keyid=<awsiamkeyid>"
    required_vars=('KEYID')
    parse_args "$@"
    check_required_vars || return 1
    ensure_aws_login || return 1

    for username in $(aws iam list-users | jq '.Users[].UserName' -r); do
        for key in $(aws iam list-access-keys --user "$username" | jq '.AccessKeyMetadata[].AccessKeyId' -r); do
            if [ "${key}" == "${KEYID}" ]; then
                echo "This key id belongs to: ${username}"
                return 0
            fi
        done
    done

    runner_log_warning "The key, '${KEYID}', was not found."
    set +u
    return 1
}

function task_aws_parameter_store_list_parameters() {
    DOC="Lists Parameters in the specified region. Uses all region unless specified as --aws_region=<region>"
    parse_args "$@"
    required_vars=()
    check_required_vars
    ensure_aws_login || return 1
    if [ -z "${AWS_REGION}" ]; then
        for region in "${AWS_REGIONS[@]}"; do
            runner_colorize green "REGION: ${region}"
            aws --region="${region}" ssm describe-parameters | jq -r '.Parameters[].Name'
        done
    else
        aws ssm describe-parameters | jq -r '.Parameters[].Name'
    fi
}

function task_aws_parameter_store_get_value() {
    DOC="Retreives the value of the parameter specified. Decrypts if necessary. Uses Default region unless specified as --aws_region=<region> "
    required_vars=('PARAMETER')
    parse_args "$@"
    check_required_vars
    ensure_aws_login || return 1
    aws ssm get-parameter --name="${PARAMETER}" --with-decryption | jq -r '.Parameter.Value'
}

function task_aws_vault_login() {
    DOC="Creats a console login for the specified profile. If you do not specify a profile, you will be asked to choose one. Option --aws_profile=<profile to set>"
    parse_args "$@"
    aws_set_profile
    ensure_aws_vault
    aws-vault login "${AWS_PROFILE}"
}

function task_aws_vault_exec() {
    DOC="Creates a console loin for the specified profile. If you do not specify a profile, you will be asked to choose one. Option --aws_profile=<profile to set>"
    parse_args "$@"
    aws_set_profile
    runner_log_notice "Entering aws_vault session. crtl^d to exit."
    ensure_aws_vault
    aws-vault exec "${AWS_PROFILE}"
}

function task_aws_sso_login() {
    DOC="Renews SSO session login for the specified profile. If you do not specify a profile, you will be asked to choose one. Option --aws_profile=<profile to set>"
    parse_args "$@"
    aws_set_profile
    aws sso login || return 1
}

function task_ecr_login() {
    DOC="Log docker into ECR. Requires --registry=<registry>"
    required_vars=('REGISTRY')
    parse_args "$@"
    AWS_REGION=$(echo "${REGISTRY}" | awk -F'.' '{ print $4 }')
    export AWS_REGION
    ensure_aws_login || return 1
    aws ecr get-login-password | docker login --username AWS --password-stdin "${REGISTRY}"
}

function task_aws_eks_cluster_auth() {
    DOC="Configure terminal session to connect to a cluster"

    parse_args "$@"
    ensure_aws_login || return 1
    runner_colorize purple "Collecting Possible Clusters:"
    spinner
    eks_clusters
    unspin

    select cluster_region in "${EKS_CLUSTERS[@]}"; do
        CLUSTER=$(echo "${cluster_region}" | awk -F'@' '{ print $1 }')
        REGION=$(echo "${cluster_region}" | awk -F'@' '{ print $2 }')
        export AWS_DEFAULT_REGION=${REGION}
        export AWS_REGION=${REGION}
        echo "Setting Context ${CLUSTER} in and Region ${REGION}"
        export KUBECONFIG=~/.kube/${CLUSTER}
        cmd="aws eks update-kubeconfig --name ${CLUSTER} --alias ${CLUSTER}"
        $cmd
        chmod 600 "${KUBECONFIG}"
        $SHELL #Drops into new shell here so it ensure the right kubeconfig is set
        break
    done
}

function task_aws_test() {
    DOC="Tests aws cli config"
    parse_args "$@"
    ensure_aws_login || return 1
    aws sts get-caller-identity
}

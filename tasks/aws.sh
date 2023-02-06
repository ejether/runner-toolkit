#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

export AWS_SESSION_TOKEN_TTL=12h
export AWS_ASSUME_ROLE_TTL=12h
export AWS_MIN_TTL=12h
export AWS_DEFAULT_REGION="us-west-2"

### HELPERS ###
ensure_awscli() {
  # Ensure awscli is available
  aws sts get-caller-identity >/dev/null || {
    runner_log_error "Error with aws access"
    return 1
  }
}

ensure_aws_login() {
  # Check for exiting session, if fails, create one, else return
  aws_set_profile
  ensure_awscli || { runner aws-sso-login || return 1; }
}

aws_account() {
  # returns account number
  ensure_aws_login
  aws sts get-caller-identity | jq -r '.Account'
}

aws_regions() {
  # returns account number
  ensure_aws_login
  AWS_REGIONS=()
  for region in $(aws ec3 describe-regions | jq -r '.Regions[].RegionName'); do
    AWS_REGIONS+=("${region}")
  done
}

_aws_set_profile() {
  # lists and sets menu of local profiles if AWS_PROFILE is not set
  if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
    runner_log_notice "AWS_ACCESS_KEY_ID set. Skipping Profile Choice."
    return
  fi

  if [[ -z "${AWS_PROFILE}" ]]; then
    runner_colorize purple "Choose a profile to use:"
    select profile in $(aws configure list-profiles | sort); do
      export AWS_PROFILE="${profile}"
      break
    done
  fi
}

aws_set_profile() {
  # lists and sets menu of local profiles if AWS_PROFILE is not set
  if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
    runner_log_notice "AWS_ACCESS_KEY_ID set. Skipping Profile Choice."
    return
  fi

  if [[ -z "${AWS_PROFILE}" ]]; then
    runner_colorize purple "Choose a profile to use:"
    select profile in $(aws configure list-profiles | grep -e AWSPower -e EKS-Adm | sort); do
      export AWS_PROFILE="${profile}"
      break
    done
  fi
}

ensure_aws_vault() {
  # tests presense of aws-vault
  command aws-vault 2>/dev/null || {
    runner_log_error "aws-vault is not installed"
    return 1
  }
}

eks_clusters() {
  # returns a list of clusters in a limited set of regions
  EKS_CLUSTERS=()
  AWS_REGIONS=("$AWS_DEFAULT_REGION")
  for region in "${AWS_REGIONS[@]}"; do
    for cluster in $(aws eks list-clusters --region "${region}" | jq -r '.clusters[]' | sort); do
      EKS_CLUSTERS+=("${cluster}@${region}")
    done
  done
}

eks_cluster_public_cidrs_holepunch() {

  MY_IP="$(curl -s ipinfo.io/ip)"
  CIDR_FILE=$(mktemp)
  aws eks describe-cluster --name "${CLUSTER}" | jq -r '.cluster.resourcesVpcConfig.publicAccessCidrs[]' >"${CIDR_FILE}"
  if [ "${1}" == "add" ]; then
    grep -q "${MY_IP}" "${CIDR_FILE}" && {
      runner_log_notice "${MY_IP} already present in publicAccessCidrs"
      return
    }
    grep -q "0.0.0.0/0" "${CIDR_FILE}" && {
      runner_log_notice "0.0.0.0/0 present in publicAccessCidrs"
      return
    }
    runner_log_notice "Adding ${MY_IP} to publicAccessCidrs."
    echo "${MY_IP}/32" >>"${CIDR_FILE}"

    NEW_CIDRS="$(comma_delimited_string_from_file "${CIDR_FILE}")"
    aws eks update-cluster-config --name "${CLUSTER}" --resources-vpc-config publicAccessCidrs="${NEW_CIDRS}"

  elif [ "${1}" == "remove" ]; then

    grep -q "${MY_IP}" "${CIDR_FILE}" || {
      runner_log_notice "${MY_IP} not present in publicAccessCidrs"
      return
    }
    runner_log_notice "Removing ${MY_IP} from publicAccessCidrs."
    # Remove the line from the file with my IP in it
    sed -i .bak "/${MY_IP}\/32/d" "${CIDR_FILE}"

    NEW_CIDRS="$(comma_delimited_string_from_file "${CIDR_FILE}")"
    aws eks update-cluster-config --name "${CLUSTER}" --resources-vpc-config publicAccessCidrs="${NEW_CIDRS}"
  fi

  # Best effort cleanup CIDR_FILE and the .back from the in place sed
  rm "${CIDR_FILE}" 2>/dev/null || true
  rm "${CIDR_FILE}.bak" 2>/dev/null || true
}

### TASKS ###

task_aws-vault-login() {
  DOC="Creats a console login for the specified profile. If you do not specify a profile, you will be asked to choose one. Option --aws_profile=<profile to set>"
  parse_args "$@"
  aws_set_profile
  ensure_aws_vault
  aws-vault login "${AWS_PROFILE}"
}

task_aws-vault-exec() {
  DOC="Creates a console loin for the specified profile. If you do not specify a profile, you will be asked to choose one. Option --aws_profile=<profile to set>"
  parse_args "$@"
  aws_set_profile
  runner_log_notice "Entering aws_vault session. crtl^d to exit."
  ensure_aws_vault
  aws-vault exec "${AWS_PROFILE}"
}

task_aws-sso-login() {
  DOC="Renews SSO session login for the specified profile. If you do not specify a profile, you will be asked to choose one. Option --aws_profile=<profile to set>"
  parse_args "$@"
  aws_set_profile
  aws sso login || return 1
}

task_ecr-login() {
  DOC="Log docker into ECR. Requires --registry=<registry>"
  required_vars=('REGISTRY')
  parse_args "$@"
  AWS_REGION=$(echo "${REGISTRY}" | awk -F'.' '{ print $4 }')
  export AWS_REGION
  ensure_aws_login || return 1
  aws ecr get-login-password | docker login --username AWS --password-stdin "${REGISTRY}"
}

task_aws-eks-cluster-auth() {
  DOC="Configure terminal session to connect to a cluster"

  parse_args "$@"
  ensure_aws_login || return 1
  runner_colorize purple "Collecting Possible Clusters:"
  #spinner
  eks_clusters
  #unspin

  select cluster_region in "${EKS_CLUSTERS[@]}"; do
    CLUSTER=$(echo "${cluster_region}" | awk -F'@' '{ print $1 }')
    REGION=$(echo "${cluster_region}" | awk -F'@' '{ print $2 }')
    export AWS_DEFAULT_REGION=${REGION}
    export AWS_REGION=${REGION}

    eks_cluster_public_cidrs_holepunch add

    echo "Setting Context ${CLUSTER} in and Region ${REGION}"
    export KUBECONFIG=~/.kube/${CLUSTER}
    cmd="aws eks update-kubeconfig --name ${CLUSTER} --alias ${CLUSTER}"
    $cmd
    chmod 600 "${KUBECONFIG}"
    $SHELL #Drops into new shell here so it ensure the right kubeconfig is set

    eks_cluster_public_cidrs_holepunch remove

    break
  done
}

task_aws-test() {
  DOC="Tests aws cli config"
  parse_args "$@"
  ensure_aws_login || return 1
  aws sts get-caller-identity
}

task_aws-list-unattached-volumes() {
  parse_args "$@"
  ensure_aws_login || return 1
  AWS_REGIONS=("$AWS_DEFAULT_REGION")
  for region in "${AWS_REGIONS[@]}"; do
    aws --region ec2 describe-volumes | jq -r '.Volumes[] | select(.Attachments==[]) | .VolumeId'
  done
  aws ec2 describe-volumes | jq -r '.Volumes[] | select(.Attachments==[]) | .VolumeId'
}

task_aws-remove-unattached-volumes() {
  DOC="Deletes Unnattached Volumes"
  parse_args "$@"
  ensure_aws_login || return 1
  for vol in $(aws ec2 describe-volumes | jq -r '.Volumes[] | select(.Attachments==[]) | .VolumeId'); do
    echo "${vol}"
    aws ec2 delete-volume --volume-id="${vol}"
  done
}

task_aws-s3-bucket-destroy() {
  DOC="Removes an AWS S3 bucket and all its version completely."
  required_vars=('BUCKET')
  parse_args "$@"
  runner_log_notice "Bucket: ${BUCKET}"
  confirm "${BUCKET} infrastructure bucket destroy: "
  ensure_aws_login || return 1

  aws s3 ls "s3://${BUCKET}" || exit 0 &&
    aws s3api list-object-versions --bucket "${BUCKET}" | jq -r '.Versions[] | .VersionId + " " + .Key' >|.tmp &&
    while read -r version; do
      echo "${version}"
      vid=$(echo "${version}" | awk '{ print $1 }')
      key=$(echo "${version}" | awk '{ print $2 }')
      aws s3api delete-object --bucket "${BUCKET}" --version-id "${vid}" --key "${key}"
    done <.tmp &&
    rm .tmp &&
    aws s3api list-object-versions --bucket "${BUCKET}" | jq -r '.DeleteMarkers[] | .VersionId + " " + .Key' >|.tmp &&
    while read -r version; do
      echo "${version}"
      vid=$(echo "${version}" | awk '{ print $1 }')
      key=$(echo "${version}" | awk '{ print $2 }')
      aws s3api delete-object --bucket "${BUCKET}" --version-id "${vid}" --key "${key}"
      echo $?
    done <.tmp &&
    rm .tmp &&
    aws s3api delete-bucket --bucket "${BUCKET}"
}

task_aws-instanceid-from-private-dns() {
  # shellcheck disable=SC2034 # not sure why these show as unused but others do not
  DOC="Retrieves the Instance ID from the Private DNS name of the host. Usefule for Kubectl get nodes. "
  DNSNAME=${DNSNAME:-${runner_extra_args[0]}}
  parse_args "$@"
  # shellcheck disable=SC2034
  required_vars=('DNSNAME')
  aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | select( .PrivateDnsName == "'"${DNSNAME}"'")'
}
